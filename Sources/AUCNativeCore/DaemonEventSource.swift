import Foundation

public protocol DaemonEventSourceProtocol: Sendable {
    func connect() async throws
    func events() async -> AsyncStream<AUCTaskEvent>
    func close() async
}

public actor DaemonEventSource: DaemonEventSourceProtocol {
    private let transport: any ExecutorTransport
    private var readerTask: _Concurrency.Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<AUCTaskEvent>.Continuation] = [:]
    private var bufferedEvents: [AUCTaskEvent] = []

    public init(transport: any ExecutorTransport) {
        self.transport = transport
    }

    public func connect() async throws {
        try await transport.connect()
        if readerTask == nil {
            readerTask = _Concurrency.Task { [weak self] in
                await self?.readLoop()
            }
        }
    }

    public func events() async -> AsyncStream<AUCTaskEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            for event in bufferedEvents {
                continuation.yield(event)
            }
            bufferedEvents.removeAll()
            continuation.onTermination = { [weak self] _ in
                _Concurrency.Task {
                    await self?.removeContinuation(id)
                }
            }
        }
    }

    public func close() async {
        readerTask?.cancel()
        readerTask = nil
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
        await transport.close()
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private func readLoop() async {
        while !_Concurrency.Task.isCancelled {
            do {
                let line = try await transport.readLine()
                guard let event = try? DaemonNotificationMapper.event(from: line) else {
                    continue
                }
                if continuations.isEmpty {
                    bufferedEvents.append(event)
                    if bufferedEvents.count > 200 {
                        bufferedEvents.removeFirst(bufferedEvents.count - 200)
                    }
                } else {
                    for continuation in continuations.values {
                        continuation.yield(event)
                    }
                }
            } catch {
                break
            }
        }
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
        readerTask = nil
    }
}

enum DaemonNotificationMapper {
    static func event(from line: String) throws -> AUCTaskEvent? {
        let notification = try JSONRPCLineCodec.decodeNotification(line)
        return try event(from: notification)
    }

    static func event(from notification: JSONRPCNotification) throws -> AUCTaskEvent? {
        switch notification.method {
        case "task.progress":
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: DaemonTaskProgressDTO.self)
            let message = dto.message ?? dto.toolName ?? dto.stage
            return AUCTaskEvent(
                taskID: dto.taskId,
                type: notification.method,
                message: message,
                status: dto.stage == "complete" ? .completed : .running
            )
        case "task.message":
            struct Payload: Decodable, Sendable {
                var taskId: String
                var messages: [DaemonTaskMessageDTO]
            }
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: Payload.self)
            let permissionRequest = dto.messages.compactMap {
                questionRequest(from: $0, taskID: dto.taskId)
            }.last
            return AUCTaskEvent(
                taskID: dto.taskId,
                type: notification.method,
                taskMessages: dto.messages.map(AUCTaskMessage.init(daemon:)),
                status: permissionRequest == nil ? nil : .waitingPermission,
                permissionRequest: permissionRequest
            )
        case "task.statusChange":
            struct Payload: Decodable, Sendable {
                var taskId: String
                var status: String
            }
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: Payload.self)
            return AUCTaskEvent(taskID: dto.taskId, type: notification.method, status: .fromDaemon(dto.status))
        case "task.summary":
            struct Payload: Decodable, Sendable {
                var taskId: String
                var summary: String
            }
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: Payload.self)
            return AUCTaskEvent(taskID: dto.taskId, type: notification.method, summary: dto.summary)
        case "task.complete":
            struct Payload: Decodable, Sendable {
                var taskId: String
                var result: DaemonTaskResultDTO
            }
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: Payload.self)
            return AUCTaskEvent(
                taskID: dto.taskId,
                type: notification.method,
                status: .completed,
                result: AUCTaskResult(daemon: dto.result)
            )
        case "task.error":
            struct Payload: Decodable, Sendable {
                var taskId: String
                var error: String?
            }
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: Payload.self)
            return AUCTaskEvent(taskID: dto.taskId, type: notification.method, message: dto.error, status: .failed)
        case "permission.request":
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: DaemonPermissionRequestDTO.self)
            let request = AUCPermissionRequest(daemon: dto)
            return AUCTaskEvent(
                taskID: dto.taskId,
                type: notification.method,
                message: request.message,
                status: .waitingPermission,
                permissionRequest: request
            )
        case "todo.update":
            struct Payload: Decodable, Sendable {
                var taskId: String
                var todos: [DaemonTodoItemDTO]
            }
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: Payload.self)
            return AUCTaskEvent(
                taskID: dto.taskId,
                type: notification.method,
                todos: dto.todos.map(AUCTodoItem.init(daemon:))
            )
        case "auth.error":
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: DaemonAuthErrorDTO.self)
            return AUCTaskEvent(
                taskID: dto.taskId,
                type: notification.method,
                message: dto.message,
                providerID: dto.providerId
            )
        case "browser.frame":
            let dto = try JSONRPCLineCodec.decodeValue(notification.params, as: DaemonBrowserFrameDTO.self)
            let frame = AUCBrowserFrame(daemon: dto)
            return AUCTaskEvent(taskID: dto.taskId, type: notification.method, browserFrame: frame)
        default:
            return nil
        }
    }

    private struct QuestionToolInput: Decodable, Sendable {
        var questions: [QuestionDTO]?
    }

    private struct QuestionDTO: Decodable, Sendable {
        var question: String?
        var header: String?
        var options: [DaemonPermissionOptionDTO]?
    }

    private static func questionRequest(from message: DaemonTaskMessageDTO, taskID: String) -> AUCPermissionRequest? {
        guard message.toolStatus == "running",
              let toolName = message.toolName?.lowercased(),
              toolName.contains("question"),
              let toolInput = message.toolInput,
              let input = try? JSONRPCLineCodec.decodeValue(toolInput, as: QuestionToolInput.self),
              let questions = input.questions,
              !questions.isEmpty else {
            return nil
        }

        let first = questions[0]
        let messageText = questions.map { question in
            let prefix = question.header.map { "\($0): " } ?? ""
            return prefix + (question.question ?? "The agent needs your answer.")
        }.joined(separator: "\n\n")
        let options = questions.flatMap { $0.options ?? [] }.compactMap(\.label)
        return AUCPermissionRequest(
            id: "native-question-\(taskID)-\(message.id ?? UUID().uuidString)",
            taskID: taskID,
            type: "question",
            title: first.header ?? "Question",
            message: messageText,
            toolName: message.toolName,
            options: options
        )
    }
}
