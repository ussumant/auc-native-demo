import Foundation

struct DaemonTaskDTO: Decodable, Sendable {
    var id: String?
    var prompt: String?
    var description: String?
    var summary: String?
    var status: String?
    var sessionId: String?
    var createdAt: String?
    var updatedAt: String?
    var completedAt: String?
    var artifactPaths: [String]?
    var artifacts: [String]?
    var messages: [DaemonTaskMessageDTO]?
    var result: DaemonTaskResultDTO?
}

extension AUCTaskRecord {
    init(daemon dto: DaemonTaskDTO, fallbackPrompt: String = "") {
        let created = Self.parseDate(dto.createdAt) ?? Date()
        let updated = Self.parseDate(dto.updatedAt ?? dto.completedAt)
        let artifactStrings = dto.artifactPaths ?? dto.artifacts ?? []
        let messages = (dto.messages ?? []).map(AUCTaskMessage.init(daemon:))
        let result = dto.result.map(AUCTaskResult.init(daemon:))
        self.init(
            id: dto.id ?? UUID().uuidString,
            prompt: dto.prompt ?? dto.description ?? fallbackPrompt,
            summary: dto.summary,
            status: .fromDaemon(dto.status),
            sessionID: dto.sessionId,
            createdAt: created,
            updatedAt: updated,
            artifactURLs: artifactStrings.map(URL.init(fileURLWithPath:)),
            currentAction: messages.lastMeaningfulAction,
            messages: messages,
            result: result
        )
    }

    fileprivate static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }
        return nil
    }
}

struct DaemonTaskMessageDTO: Decodable, Sendable {
    var id: String?
    var type: String?
    var content: String?
    var toolName: String?
    var toolStatus: String?
    var toolInput: JSONValue?
    var timestamp: String?
    var modelId: String?
    var providerId: String?
}

struct DaemonTaskResultDTO: Decodable, Sendable {
    var status: String?
    var sessionId: String?
    var durationMs: Double?
    var error: String?
    var pauseReason: String?
    var pauseAction: DaemonPauseActionDTO?
}

struct DaemonPauseActionDTO: Decodable, Sendable {
    var type: String?
    var label: String?
    var pendingLabel: String?
    var successText: String?
}

struct DaemonTaskProgressDTO: Decodable, Sendable {
    var taskId: String
    var stage: String?
    var toolName: String?
    var toolInput: JSONValue?
    var percentage: Double?
    var message: String?
    var modelName: String?
    var isFirstTask: Bool?
}

struct DaemonPermissionRequestDTO: Decodable, Sendable {
    var id: String
    var taskId: String
    var type: String?
    var toolName: String?
    var toolInput: JSONValue?
    var question: String?
    var header: String?
    var options: [DaemonPermissionOptionDTO]?
    var fileOperation: String?
    var filePath: String?
    var filePaths: [String]?
    var targetPath: String?
    var contentPreview: String?
}

struct DaemonPermissionOptionDTO: Decodable, Sendable {
    var label: String?
    var description: String?
}

struct DaemonTodoItemDTO: Decodable, Sendable {
    var id: String?
    var content: String?
    var title: String?
    var status: String?
    var priority: String?
}

struct DaemonBrowserFrameDTO: Decodable, Sendable {
    var taskId: String
    var title: String?
    var url: String?
    var screenshot: String?
    var imageData: String?
    var data: String?
    var summary: String?
}

struct DaemonAuthErrorDTO: Decodable, Sendable {
    var taskId: String
    var providerId: String?
    var message: String
}

extension AUCTaskMessage {
    init(daemon dto: DaemonTaskMessageDTO) {
        self.init(
            id: dto.id ?? UUID().uuidString,
            type: dto.type ?? "system",
            content: dto.content ?? "",
            toolName: dto.toolName,
            toolStatus: dto.toolStatus,
            toolInputDescription: dto.toolInput?.compactDescription,
            timestamp: AUCTaskRecord.parseDaemonDate(dto.timestamp) ?? Date(),
            modelID: dto.modelId,
            providerID: dto.providerId
        )
    }
}

extension AUCTaskResult {
    init(daemon dto: DaemonTaskResultDTO) {
        self.init(
            status: dto.status ?? "unknown",
            sessionID: dto.sessionId,
            durationMs: dto.durationMs,
            error: dto.error,
            pauseReason: dto.pauseReason,
            pauseActionLabel: dto.pauseAction?.label
        )
    }
}

extension AUCPermissionRequest {
    init(daemon dto: DaemonPermissionRequestDTO) {
        let optionLabels = (dto.options ?? []).compactMap(\.label)
        let inferredTitle = dto.header ?? dto.question ?? dto.toolName ?? dto.fileOperation ?? "Permission needed"
        let fileTargets = dto.filePaths ?? []
        let fileTargetMessage = fileTargets.isEmpty ? nil : fileTargets.joined(separator: "\n")
        let message = dto.question
            ?? dto.contentPreview
            ?? dto.toolInput?.compactDescription
            ?? dto.filePath
            ?? fileTargetMessage
            ?? "AUC needs approval to continue."
        self.init(
            id: dto.id,
            taskID: dto.taskId,
            type: dto.type ?? "tool",
            title: inferredTitle,
            message: message,
            toolName: dto.toolName,
            filePath: dto.filePath,
            filePaths: fileTargets,
            options: optionLabels
        )
    }
}

extension AUCTodoItem {
    init(daemon dto: DaemonTodoItemDTO) {
        self.init(
            id: dto.id ?? UUID().uuidString,
            content: dto.content ?? dto.title ?? "Task step",
            status: dto.status ?? "pending",
            priority: dto.priority ?? "medium"
        )
    }
}

extension AUCBrowserFrame {
    init(daemon dto: DaemonBrowserFrameDTO) {
        self.init(
            taskID: dto.taskId,
            title: dto.title,
            url: dto.url,
            imageData: dto.imageData ?? dto.screenshot ?? dto.data,
            summary: dto.summary
        )
    }
}

extension AUCTaskRecord {
    static func parseDaemonDate(_ value: String?) -> Date? {
        parseDate(value)
    }
}

extension JSONValue {
    var compactDescription: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        case .array, .object:
            guard let data = try? JSONEncoder().encode(self) else { return "" }
            return String(decoding: data, as: UTF8.self)
        }
    }
}

struct DaemonProviderSettingsDTO: Decodable, Sendable {
    var activeProviderId: String?
    var selectedModel: SelectedModelDTO?
    var connectedProviders: [String: ConnectedProviderDTO]?

    struct SelectedModelDTO: Decodable, Sendable {
        var provider: String?
        var model: String?
        var id: String?
    }

    struct ConnectedProviderDTO: Decodable, Sendable {
        var providerId: String?
        var connectionStatus: String?
        var selectedModelId: String?
        var credentials: CredentialsDTO?
    }

    struct CredentialsDTO: Decodable, Sendable {
        var type: String?
        var keyPrefix: String?
    }
}

extension AUCProviderSettings {
    init(daemon dto: DaemonProviderSettingsDTO) {
        let hasReady = (dto.connectedProviders ?? [:]).values.contains { provider in
            provider.connectionStatus == "connected" && !(provider.selectedModelId ?? "").isEmpty
        }
        let activeProviderID = dto.activeProviderId
        let activeProvider = activeProviderID.flatMap { dto.connectedProviders?[$0] }
        let selected = dto.selectedModel.flatMap {
            AUCModelSelection(provider: $0.provider ?? activeProviderID ?? "provider", model: $0.model ?? $0.id ?? "model")
        } ?? activeProvider.flatMap {
            guard let model = $0.selectedModelId else { return nil }
            return AUCModelSelection(provider: activeProviderID ?? $0.providerId ?? "provider", model: model)
        }
        let openAIKeyPrefix = dto.connectedProviders?["openai"]?.credentials?.keyPrefix
        self.init(
            hasReadyProvider: hasReady,
            selectedModel: selected,
            activeProviderID: activeProviderID,
            openAIKeyPrefix: openAIKeyPrefix
        )
    }
}
