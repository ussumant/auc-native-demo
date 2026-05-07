import Foundation

public protocol ExecutorClientProtocol: Sendable {
    func connect() async throws
    func startTask(_ composer: AUCTaskComposerState) async throws -> AUCTaskRecord
    func cancelTask(id: String) async throws
    func interruptTask(id: String) async throws
    func resumeSession(sessionID: String, prompt: String, taskID: String?) async throws -> AUCTaskRecord
    func getTask(id: String) async throws -> AUCTaskRecord?
    func listTasks() async throws -> [AUCTaskRecord]
    func deleteTask(id: String) async throws
    func respondToPermission(
        requestID: String,
        taskID: String,
        allowed: Bool,
        selectedOptions: [String]?,
        customText: String?
    ) async throws
    func getProviderSettings() async throws -> AUCProviderSettings
    func getOpenAIBaseURL() async throws -> String
    func saveOpenAIAPIKey(apiKey: String, baseURL: String?, modelID: String) async throws
    func setSelectedModel(_ model: AUCModelSelection) async throws
    func getTodos(taskID: String) async throws -> [String]
    func subscribeToTaskEvents(taskID: String) async throws -> AsyncThrowingStream<AUCTaskEvent, any Error>
}

public enum ExecutorClientError: LocalizedError, Equatable {
    case rpcError(code: Int, message: String)
    case missingResult
    case mismatchedResponse
    case tooManyUnmatchedResponses
    case requestTimedOut(method: String, seconds: Double)

    public var errorDescription: String? {
        switch self {
        case .rpcError(_, let message):
            return message
        case .missingResult:
            return "The daemon returned no result."
        case .mismatchedResponse:
            return "The daemon returned a response for a different request."
        case .tooManyUnmatchedResponses:
            return "The daemon returned too many unrelated messages."
        case .requestTimedOut(let method, let seconds):
            return "The daemon did not answer \(method) within \(Int(seconds)) seconds."
        }
    }
}

public actor ExecutorClient: ExecutorClientProtocol {
    private let transport: any ExecutorTransport
    private let requestTimeout: Duration
    private let requestTimeoutSeconds: Double
    private var nextID = 1
    private var pendingResponses: [Int: PendingResponse] = [:]
    private var earlyResponses: [Int: JSONRPCResponse] = [:]
    private var readLoopTask: _Concurrency.Task<Void, Never>?

    private struct PendingResponse: Sendable {
        var method: String
        var continuation: CheckedContinuation<JSONRPCResponse, any Error>
    }

    public init(
        transport: any ExecutorTransport,
        requestTimeout: Duration = .seconds(30),
        requestTimeoutSeconds: Double = 30
    ) {
        self.transport = transport
        self.requestTimeout = requestTimeout
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }

    public func connect() async throws {
        try await transport.connect()
        startReadLoopIfNeeded()
    }

    public func startTask(_ composer: AUCTaskComposerState) async throws -> AUCTaskRecord {
        var params: [String: JSONValue] = [
            "prompt": .string(composer.trimmedPrompt.isEmpty ? composer.attachments.map(\.displayName).joined(separator: ", ") : composer.trimmedPrompt),
            "taskId": .string(composer.clientTaskID ?? "native-\(UUID().uuidString)"),
            "source": .string("ui")
        ]
        if let selectedModel = composer.selectedModel {
            params["modelId"] = .string(selectedModel.model)
            params["provider"] = .string(selectedModel.provider)
        }
        if let workingDirectory = composer.workingDirectory {
            params["workingDirectory"] = .string(workingDirectory.path)
        }
        if !composer.attachments.isEmpty {
            params["attachments"] = .array(composer.attachments.map { attachment in
                .object([
                    "id": .string(attachment.id.uuidString),
                    "path": .string(attachment.url.path),
                    "name": .string(attachment.displayName),
                    "type": .string("other"),
                    "size": .number(Double(attachment.byteCount ?? 0))
                ])
            })
        }

        let dto: DaemonTaskDTO = try await call("task.start", params: .object(params), as: DaemonTaskDTO.self)
        return AUCTaskRecord(daemon: dto, fallbackPrompt: composer.prompt)
    }

    public func cancelTask(id: String) async throws {
        let _: JSONValue = try await call("task.cancel", params: .object(["taskId": .string(id)]), as: JSONValue.self)
    }

    public func interruptTask(id: String) async throws {
        let _: JSONValue = try await call("task.interrupt", params: .object(["taskId": .string(id)]), as: JSONValue.self)
    }

    public func resumeSession(sessionID: String, prompt: String, taskID: String?) async throws -> AUCTaskRecord {
        var params: [String: JSONValue] = [
            "sessionId": .string(sessionID),
            "prompt": .string(prompt)
        ]
        if let taskID {
            params["existingTaskId"] = .string(taskID)
        }
        let dto: DaemonTaskDTO = try await call("session.resume", params: .object(params), as: DaemonTaskDTO.self)
        return AUCTaskRecord(daemon: dto, fallbackPrompt: prompt)
    }

    public func getTask(id: String) async throws -> AUCTaskRecord? {
        let dto: DaemonTaskDTO? = try await call("task.get", params: .object(["taskId": .string(id)]), as: DaemonTaskDTO?.self)
        return dto.map { AUCTaskRecord(daemon: $0) }
    }

    public func listTasks() async throws -> [AUCTaskRecord] {
        let dto: [DaemonTaskDTO] = try await call("task.list", params: .object([:]), as: [DaemonTaskDTO].self)
        return dto.map { AUCTaskRecord(daemon: $0) }
    }

    public func deleteTask(id: String) async throws {
        let _: JSONValue = try await call("task.delete", params: .object(["taskId": .string(id)]), as: JSONValue.self)
    }

    public func respondToPermission(
        requestID: String,
        taskID: String,
        allowed: Bool,
        selectedOptions: [String]? = nil,
        customText: String? = nil
    ) async throws {
        var params: [String: JSONValue] = [
            "requestId": .string(requestID),
            "taskId": .string(taskID),
            "decision": .string(allowed ? "allow" : "deny")
        ]
        if let selectedOptions, !selectedOptions.isEmpty {
            params["selectedOptions"] = .array(selectedOptions.map { .string($0) })
        }
        if let customText, !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            params["customText"] = .string(customText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let _: JSONValue = try await call("permission.respond", params: .object(params), as: JSONValue.self)
    }

    public func getProviderSettings() async throws -> AUCProviderSettings {
        let dto: DaemonProviderSettingsDTO = try await call("provider.getSettings", params: nil, as: DaemonProviderSettingsDTO.self)
        return AUCProviderSettings(daemon: dto)
    }

    public func getOpenAIBaseURL() async throws -> String {
        try await call("settings.getOpenAiBaseUrl", params: nil, as: String.self)
    }

    public func saveOpenAIAPIKey(apiKey: String, baseURL: String?, modelID: String = "openai/gpt-5.2") async throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = (baseURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let keyPrefix = trimmedKey.count > 20 ? String(trimmedKey.prefix(20)) + "..." : trimmedKey
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let _: JSONValue = try await call(
            "settings.setOpenAiBaseUrl",
            params: .object(["baseUrl": .string(trimmedBaseURL)]),
            as: JSONValue.self
        )
        let _: JSONValue = try await call(
            "secrets.storeApiKey",
            params: .object([
                "provider": .string("openai"),
                "apiKey": .string(trimmedKey)
            ]),
            as: JSONValue.self
        )
        let _: JSONValue = try await call(
            "provider.setConnected",
            params: .object([
                "providerId": .string("openai"),
                "provider": .object([
                    "providerId": .string("openai"),
                    "connectionStatus": .string("connected"),
                    "selectedModelId": .string(modelID),
                    "credentials": .object([
                        "type": .string("api_key"),
                        "keyPrefix": .string(keyPrefix)
                    ]),
                    "lastConnectedAt": .string(timestamp)
                ])
            ]),
            as: JSONValue.self
        )
        let _: JSONValue = try await call(
            "provider.setActive",
            params: .object(["providerId": .string("openai")]),
            as: JSONValue.self
        )
        try await setSelectedModel(AUCModelSelection(provider: "openai", model: modelID))
    }

    public func setSelectedModel(_ model: AUCModelSelection) async throws {
        let _: JSONValue = try await call(
            "settings.setSelectedModel",
            params: .object([
                "model": .object([
                    "provider": .string(model.provider),
                    "model": .string(model.model)
                ])
            ]),
            as: JSONValue.self
        )
    }

    public func getTodos(taskID: String) async throws -> [String] {
        struct TodoDTO: Decodable { var title: String?; var content: String? }
        let todos: [TodoDTO] = try await call("task.getTodos", params: .object(["taskId": .string(taskID)]), as: [TodoDTO].self)
        return todos.map { $0.title ?? $0.content ?? "Task step" }
    }

    public func subscribeToTaskEvents(taskID: String) async throws -> AsyncThrowingStream<AUCTaskEvent, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let task = try await getTask(id: taskID)
                    continuation.yield(AUCTaskEvent(taskID: taskID, type: "snapshot", message: task?.currentAction, task: task))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func call<T: Decodable>(_ method: String, params: JSONValue?, as type: T.Type) async throws -> T {
        let id = nextID
        nextID += 1
        let request = JSONRPCRequest(id: id, method: method, params: params)
        let line = try JSONRPCLineCodec.encode(request)
        startReadLoopIfNeeded()
        let response = try await awaitResponse(id: id, method: method, afterSending: line)
        if let error = response.error {
            throw ExecutorClientError.rpcError(code: error.code, message: error.message)
        }
        return try JSONRPCLineCodec.decodeValue(response.result, as: T.self)
    }

    private func awaitResponse(id: Int, method: String, afterSending line: String) async throws -> JSONRPCResponse {
        if let early = earlyResponses.removeValue(forKey: id) {
            try await transport.sendLine(line)
            return early
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingResponses[id] = PendingResponse(method: method, continuation: continuation)
                _Concurrency.Task { [transport] in
                    do {
                        try await transport.sendLine(line)
                    } catch {
                        await self.failPendingResponse(id: id, error: error)
                    }
                }
                _Concurrency.Task {
                    do {
                        try await _Concurrency.Task.sleep(for: requestTimeout)
                        await self.failPendingResponse(
                            id: id,
                            error: ExecutorClientError.requestTimedOut(
                                method: method,
                                seconds: requestTimeoutSeconds
                            )
                        )
                    } catch {}
                }
            }
        } onCancel: {
            _Concurrency.Task {
                await self.failPendingResponse(id: id, error: CancellationError())
            }
        }
    }

    private func startReadLoopIfNeeded() {
        guard readLoopTask == nil else { return }
        readLoopTask = _Concurrency.Task { [transport] in
            while !_Concurrency.Task.isCancelled {
                do {
                    let line = try await transport.readLine()
                    await self.handleInboundLine(line)
                } catch {
                    await self.failAllPendingResponses(error)
                    await self.clearReadLoopTask()
                    return
                }
            }
        }
    }

    private func clearReadLoopTask() {
        readLoopTask = nil
    }

    private func handleInboundLine(_ line: String) {
        if let response = try? JSONRPCLineCodec.decodeResponse(line), let id = response.id {
            if let pending = pendingResponses.removeValue(forKey: id) {
                pending.continuation.resume(returning: response)
            } else {
                earlyResponses[id] = response
            }
            return
        }

        if (try? JSONRPCLineCodec.decodeNotification(line)) != nil {
            return
        }
    }

    private func failPendingResponse(id: Int, error: any Error) {
        guard let pending = pendingResponses.removeValue(forKey: id) else { return }
        pending.continuation.resume(throwing: error)
    }

    private func failAllPendingResponses(_ error: any Error) {
        let pending = pendingResponses
        pendingResponses.removeAll()
        for response in pending.values {
            response.continuation.resume(throwing: error)
        }
    }
}
