import Foundation

public struct AUCFileAttachment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var url: URL
    public var displayName: String
    public var byteCount: Int64?

    public init(id: UUID = UUID(), url: URL, displayName: String? = nil, byteCount: Int64? = nil) {
        self.id = id
        self.url = url
        self.displayName = displayName ?? url.lastPathComponent
        self.byteCount = byteCount
    }
}

public struct AUCModelSelection: Codable, Equatable, Sendable {
    public var provider: String
    public var model: String

    public init(provider: String, model: String) {
        self.provider = provider
        self.model = model
    }
}

public enum ComposerMode: Codable, Equatable, Sendable {
    case newTask
    case followUp(taskID: String)
}

public struct AUCTaskComposerState: Codable, Equatable, Sendable {
    public var prompt: String
    public var attachments: [AUCFileAttachment]
    public var workingDirectory: URL?
    public var selectedModel: AUCModelSelection?
    public var mode: ComposerMode
    public var clientTaskID: String?

    public init(
        prompt: String = "",
        attachments: [AUCFileAttachment] = [],
        workingDirectory: URL? = nil,
        selectedModel: AUCModelSelection? = nil,
        mode: ComposerMode = .newTask,
        clientTaskID: String? = nil
    ) {
        self.prompt = prompt
        self.attachments = attachments
        self.workingDirectory = workingDirectory
        self.selectedModel = selectedModel
        self.mode = mode
        self.clientTaskID = clientTaskID
    }

    public var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var canSubmit: Bool {
        !trimmedPrompt.isEmpty || !attachments.isEmpty
    }
}

public enum AUCTaskStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case queued
    case running
    case waitingPermission = "waiting_permission"
    case completed
    case failed
    case cancelled
    case interrupted
    case unknown

    public static func fromDaemon(_ raw: String?) -> AUCTaskStatus {
        guard let raw else { return .unknown }
        if raw == "pending" { return .queued }
        return AUCTaskStatus(rawValue: raw) ?? .unknown
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .interrupted:
            return true
        case .queued, .running, .waitingPermission, .unknown:
            return false
        }
    }
}

public struct AUCTaskRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var prompt: String
    public var summary: String?
    public var status: AUCTaskStatus
    public var sessionID: String?
    public var createdAt: Date
    public var updatedAt: Date?
    public var artifactURLs: [URL]
    public var currentAction: String?
    public var messages: [AUCTaskMessage]
    public var todos: [AUCTodoItem]
    public var result: AUCTaskResult?
    public var browserFrame: AUCBrowserFrame?

    public init(
        id: String,
        prompt: String,
        summary: String? = nil,
        status: AUCTaskStatus,
        sessionID: String? = nil,
        createdAt: Date,
        updatedAt: Date? = nil,
        artifactURLs: [URL] = [],
        currentAction: String? = nil,
        messages: [AUCTaskMessage] = [],
        todos: [AUCTodoItem] = [],
        result: AUCTaskResult? = nil,
        browserFrame: AUCBrowserFrame? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.summary = summary
        self.status = status
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.artifactURLs = artifactURLs
        self.currentAction = currentAction
        self.messages = messages
        self.todos = todos
        self.result = result
        self.browserFrame = browserFrame
    }

    public var displayTitle: String {
        if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        return prompt
    }
}

public struct AUCTaskMessage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var type: String
    public var content: String
    public var toolName: String?
    public var toolStatus: String?
    public var toolInputDescription: String?
    public var timestamp: Date
    public var modelID: String?
    public var providerID: String?

    public init(
        id: String,
        type: String,
        content: String,
        toolName: String? = nil,
        toolStatus: String? = nil,
        toolInputDescription: String? = nil,
        timestamp: Date = Date(),
        modelID: String? = nil,
        providerID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.toolName = toolName
        self.toolStatus = toolStatus
        self.toolInputDescription = toolInputDescription
        self.timestamp = timestamp
        self.modelID = modelID
        self.providerID = providerID
    }
}

public struct AUCFileWriteOperation: Codable, Equatable, Sendable {
    public var url: URL
    public var startedAt: Date

    public init(url: URL, startedAt: Date) {
        self.url = url
        self.startedAt = startedAt
    }
}

public struct AUCTodoItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var content: String
    public var status: String
    public var priority: String

    public init(id: String, content: String, status: String = "pending", priority: String = "medium") {
        self.id = id
        self.content = content
        self.status = status
        self.priority = priority
    }

    public var isDone: Bool {
        status == "completed"
    }
}

public struct AUCTaskResult: Codable, Equatable, Sendable {
    public var status: String
    public var sessionID: String?
    public var durationMs: Double?
    public var error: String?
    public var pauseReason: String?
    public var pauseActionLabel: String?

    public init(
        status: String,
        sessionID: String? = nil,
        durationMs: Double? = nil,
        error: String? = nil,
        pauseReason: String? = nil,
        pauseActionLabel: String? = nil
    ) {
        self.status = status
        self.sessionID = sessionID
        self.durationMs = durationMs
        self.error = error
        self.pauseReason = pauseReason
        self.pauseActionLabel = pauseActionLabel
    }
}

public struct AUCBrowserFrame: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var taskID: String
    public var title: String?
    public var url: String?
    public var imageData: String?
    public var summary: String?

    public init(
        id: String = UUID().uuidString,
        taskID: String,
        title: String? = nil,
        url: String? = nil,
        imageData: String? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.url = url
        self.imageData = imageData
        self.summary = summary
    }
}

public struct AUCPermissionRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var taskID: String
    public var type: String
    public var title: String
    public var message: String
    public var toolName: String?
    public var filePath: String?
    public var filePaths: [String]
    public var options: [String]

    public init(
        id: String,
        taskID: String,
        type: String = "tool",
        title: String,
        message: String,
        toolName: String? = nil,
        filePath: String? = nil,
        filePaths: [String] = [],
        options: [String] = []
    ) {
        self.id = id
        self.taskID = taskID
        self.type = type
        self.title = title
        self.message = message
        self.toolName = toolName
        self.filePath = filePath
        self.filePaths = filePaths
        self.options = options
    }
}

public struct AUCProviderSettings: Codable, Equatable, Sendable {
    public var hasReadyProvider: Bool
    public var selectedModel: AUCModelSelection?
    public var activeProviderID: String?
    public var openAIKeyPrefix: String?

    public init(
        hasReadyProvider: Bool = false,
        selectedModel: AUCModelSelection? = nil,
        activeProviderID: String? = nil,
        openAIKeyPrefix: String? = nil
    ) {
        self.hasReadyProvider = hasReadyProvider
        self.selectedModel = selectedModel
        self.activeProviderID = activeProviderID
        self.openAIKeyPrefix = openAIKeyPrefix
    }
}

public enum AUCExecutorPhase: String, Codable, Equatable, Sendable {
    case installBlocked
    case starting
    case connected
    case repairing
    case crashed
    case failed

    public var isReadyForProviderSetup: Bool {
        self == .connected
    }
}

public struct AUCExecutorDiagnostics: Codable, Equatable, Sendable {
    public var appPath: String
    public var isRunningFromDMG: Bool
    public var isTranslocated: Bool
    public var dataDir: String
    public var socketPath: String
    public var daemonPid: Int32?
    public var nodeBinaryPath: String?
    public var daemonEntryPath: String?
    public var logPath: String
    public var isConnected: Bool
    public var executorPhase: AUCExecutorPhase
    public var providerReady: Bool
    public var lastError: String?
    public var daemonCommand: String?
    public var staleDaemonDescription: String?
    public var lastLogError: String?

    public init(
        appPath: String = "",
        isRunningFromDMG: Bool = false,
        isTranslocated: Bool = false,
        dataDir: String = "",
        socketPath: String = "",
        daemonPid: Int32? = nil,
        nodeBinaryPath: String? = nil,
        daemonEntryPath: String? = nil,
        logPath: String = "",
        isConnected: Bool = false,
        executorPhase: AUCExecutorPhase = .starting,
        providerReady: Bool = false,
        lastError: String? = nil,
        daemonCommand: String? = nil,
        staleDaemonDescription: String? = nil,
        lastLogError: String? = nil
    ) {
        self.appPath = appPath
        self.isRunningFromDMG = isRunningFromDMG
        self.isTranslocated = isTranslocated
        self.dataDir = dataDir
        self.socketPath = socketPath
        self.daemonPid = daemonPid
        self.nodeBinaryPath = nodeBinaryPath
        self.daemonEntryPath = daemonEntryPath
        self.logPath = logPath
        self.isConnected = isConnected
        self.executorPhase = executorPhase
        self.providerReady = providerReady
        self.lastError = lastError
        self.daemonCommand = daemonCommand
        self.staleDaemonDescription = staleDaemonDescription
        self.lastLogError = lastLogError
    }

    public var copyText: String {
        [
            "AUC Executor Diagnostics",
            "App path: \(appPath.isEmpty ? "unknown" : appPath)",
            "Running from DMG: \(isRunningFromDMG ? "yes" : "no")",
            "Translocated: \(isTranslocated ? "yes" : "no")",
            "Data dir: \(dataDir.isEmpty ? "unknown" : dataDir)",
            "Socket path: \(socketPath.isEmpty ? "unknown" : socketPath)",
            "Daemon pid: \(daemonPid.map(String.init) ?? "unknown")",
            "Node: \(nodeBinaryPath ?? "unknown")",
            "Daemon entry: \(daemonEntryPath ?? "unknown")",
            "Daemon log: \(logPath.isEmpty ? "unknown" : logPath)",
            "Executor phase: \(executorPhase.rawValue)",
            "Executor connected: \(isConnected ? "yes" : "no")",
            "Provider ready: \(providerReady ? "yes" : "no")",
            "Daemon command: \(daemonCommand ?? "unknown")",
            "Stale daemon: \(staleDaemonDescription ?? "none")",
            "Last daemon log error: \(lastLogError ?? "none")",
            "Last error: \(lastError ?? "none")"
        ].joined(separator: "\n")
    }
}

public struct AUCProof: Codable, Equatable, Sendable {
    public var title: String
    public var detail: String
    public var artifactURLs: [URL]

    public init(title: String, detail: String, artifactURLs: [URL] = []) {
        self.title = title
        self.detail = detail
        self.artifactURLs = artifactURLs
    }
}

public struct AUCTaskEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var taskID: String
    public var type: String
    public var message: String?
    public var task: AUCTaskRecord?
    public var taskMessages: [AUCTaskMessage]
    public var status: AUCTaskStatus?
    public var summary: String?
    public var permissionRequest: AUCPermissionRequest?
    public var todos: [AUCTodoItem]
    public var result: AUCTaskResult?
    public var browserFrame: AUCBrowserFrame?
    public var providerID: String?

    public init(
        id: String = UUID().uuidString,
        taskID: String,
        type: String,
        message: String? = nil,
        task: AUCTaskRecord? = nil,
        taskMessages: [AUCTaskMessage] = [],
        status: AUCTaskStatus? = nil,
        summary: String? = nil,
        permissionRequest: AUCPermissionRequest? = nil,
        todos: [AUCTodoItem] = [],
        result: AUCTaskResult? = nil,
        browserFrame: AUCBrowserFrame? = nil,
        providerID: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.type = type
        self.message = message
        self.task = task
        self.taskMessages = taskMessages
        self.status = status
        self.summary = summary
        self.permissionRequest = permissionRequest
        self.todos = todos
        self.result = result
        self.browserFrame = browserFrame
        self.providerID = providerID
    }
}

extension AUCTaskRecord {
    public var runningFileWriteOperation: AUCFileWriteOperation? {
        AUCFileWriteDetector.runningFileWriteOperation(in: messages)
    }

    public func merged(with newer: AUCTaskRecord) -> AUCTaskRecord {
        var copy = self
        copy.prompt = newer.prompt.isEmpty ? copy.prompt : newer.prompt
        copy.summary = newer.summary ?? copy.summary
        copy.status = newer.status == .unknown ? copy.status : newer.status
        copy.sessionID = newer.sessionID ?? copy.sessionID
        copy.updatedAt = newer.updatedAt ?? copy.updatedAt
        if !newer.artifactURLs.isEmpty {
            copy.artifactURLs = newer.artifactURLs
        }
        copy.currentAction = newer.currentAction ?? copy.currentAction
        if !newer.messages.isEmpty {
            copy.mergeMessages(newer.messages)
        }
        if !newer.todos.isEmpty {
            copy.todos = newer.todos
        }
        copy.result = newer.result ?? copy.result
        copy.browserFrame = newer.browserFrame ?? copy.browserFrame
        return copy
    }

    public mutating func mergeMessages(_ incoming: [AUCTaskMessage]) {
        for message in incoming {
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = message
            } else {
                messages.append(message)
            }
        }
        messages.sort { $0.timestamp < $1.timestamp }
    }
}

extension Array where Element == AUCTaskMessage {
    public var lastMeaningfulAction: String? {
        for message in reversed() {
            if let toolName = message.toolName, !toolName.isEmpty {
                if let status = message.toolStatus, !status.isEmpty {
                    return "\(toolName) \(status)"
                }
                return toolName
            }
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, message.type != "user" {
                return trimmed.count > 140 ? String(trimmed.prefix(140)) + "..." : trimmed
            }
        }
        return nil
    }
}

private enum AUCFileWriteDetector {
    static func runningFileWriteOperation(in messages: [AUCTaskMessage]) -> AUCFileWriteOperation? {
        for message in messages.reversed() {
            guard message.type == "tool",
                  message.toolStatus == "running",
                  message.toolName?.localizedCaseInsensitiveContains("bash") == true,
                  let command = bashCommand(from: message.toolInputDescription),
                  looksLikeFileWrite(command),
                  let url = firstLocalFileURL(in: command) else {
                continue
            }
            return AUCFileWriteOperation(url: url, startedAt: message.timestamp)
        }
        return nil
    }

    private static func bashCommand(from inputDescription: String?) -> String? {
        guard let inputDescription, !inputDescription.isEmpty else { return nil }
        if let data = inputDescription.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let command = object["command"] as? String {
            return command
        }
        return inputDescription
    }

    private static func looksLikeFileWrite(_ command: String) -> Bool {
        let lower = command.lowercased()
        return lower.contains(" > ") ||
            lower.contains(">>") ||
            lower.contains("| tee") ||
            lower.hasPrefix("tee ") ||
            lower.hasPrefix("touch ") ||
            lower.hasPrefix("cp ") ||
            lower.hasPrefix("mv ") ||
            lower.contains("writefile") ||
            lower.contains("write_file")
    }

    private static func firstLocalFileURL(in command: String) -> URL? {
        let pattern = #"(?:(?:\$HOME|~|/Users/[^\s"']+)/[^\s"']+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(command.startIndex..<command.endIndex, in: command)
        let matches = regex.matches(in: command, range: range)
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        for match in matches {
            guard let swiftRange = Range(match.range, in: command) else { continue }
            var path = String(command[swiftRange])
            path = path
                .replacingOccurrences(of: "$HOME", with: home)
                .replacingOccurrences(of: "~", with: home)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard path.contains("/Downloads/") || path.contains("/Desktop/") || path.contains("/Documents/") else {
                continue
            }
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
