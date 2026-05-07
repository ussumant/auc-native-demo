import Foundation

public struct ExecutorPaths: Equatable, Sendable {
    public var repoRoot: URL?
    public var nodeBinary: URL?
    public var daemonEntry: URL?
    public var dataDir: URL

    public init(repoRoot: URL?, nodeBinary: URL?, daemonEntry: URL?, dataDir: URL) {
        self.repoRoot = repoRoot
        self.nodeBinary = nodeBinary
        self.daemonEntry = daemonEntry
        self.dataDir = dataDir
    }
}

public enum ExecutorProcessError: LocalizedError, Equatable {
    case daemonEntryMissing
    case nodeBinaryMissing
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .daemonEntryMissing:
            return "Could not find the bundled AUC daemon entrypoint."
        case .nodeBinaryMissing:
            return "Could not find a Node runtime for the bundled executor."
        case .launchFailed(let message):
            return "Could not launch the AUC executor: \(message)"
        }
    }
}

public actor ExecutorProcessManager {
    public private(set) var process: Process?
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public static func defaultPaths(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> ExecutorPaths {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let dataDir = home.appendingPathComponent("Library/Application Support/AUCNative", isDirectory: true)

        let envRepo = environment["AUC_EXECUTOR_REPO"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let envRepo {
            let bundledNode = envRepo
                .appendingPathComponent("apps/desktop/resources/nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin/node")
            let daemonEntry = envRepo.appendingPathComponent("apps/daemon/dist/index.js")
            return ExecutorPaths(
                repoRoot: envRepo,
                nodeBinary: FileManager.default.fileExists(atPath: bundledNode.path) ? bundledNode : URL(fileURLWithPath: "/usr/bin/env"),
                daemonEntry: FileManager.default.fileExists(atPath: daemonEntry.path) ? daemonEntry : nil,
                dataDir: dataDir
            )
        }

        let resources = bundle.resourceURL
        let bundledNode = resources?.appendingPathComponent("Executor/nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin/node")
        let bundledEntry = resources?.appendingPathComponent("Executor/daemon/index.js")
        if let bundledNode, let bundledEntry,
           FileManager.default.fileExists(atPath: bundledNode.path),
           FileManager.default.fileExists(atPath: bundledEntry.path) {
            return ExecutorPaths(
                repoRoot: nil,
                nodeBinary: bundledNode,
                daemonEntry: bundledEntry,
                dataDir: dataDir
            )
        }

        let cwdSiblingRepo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .deletingLastPathComponent()
            .appendingPathComponent("agent-computer/accomplish", isDirectory: true)
        let homeSiblingRepo = home
            .appendingPathComponent("dev/personalos/Coding/agent-computer/accomplish", isDirectory: true)
        let repoRoot = [cwdSiblingRepo, homeSiblingRepo].compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("apps/daemon/dist/index.js").path)
        }

        if let repoRoot {
            let bundledNode = repoRoot
                .appendingPathComponent("apps/desktop/resources/nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin/node")
            let daemonEntry = repoRoot.appendingPathComponent("apps/daemon/dist/index.js")
            return ExecutorPaths(
                repoRoot: repoRoot,
                nodeBinary: FileManager.default.fileExists(atPath: bundledNode.path) ? bundledNode : URL(fileURLWithPath: "/usr/bin/env"),
                daemonEntry: FileManager.default.fileExists(atPath: daemonEntry.path) ? daemonEntry : nil,
                dataDir: dataDir
            )
        }

        let node = resources?.appendingPathComponent("Executor/nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin/node")
        let entry = resources?.appendingPathComponent("Executor/daemon/index.js")
        return ExecutorPaths(
            repoRoot: nil,
            nodeBinary: node,
            daemonEntry: entry,
            dataDir: dataDir
        )
    }

    public func ensureRunning(paths: ExecutorPaths) async throws {
        try fileManager.createDirectory(at: paths.dataDir, withIntermediateDirectories: true)
        guard let daemonEntry = paths.daemonEntry, fileManager.fileExists(atPath: daemonEntry.path) else {
            throw ExecutorProcessError.daemonEntryMissing
        }
        guard let nodeBinary = paths.nodeBinary else {
            throw ExecutorProcessError.nodeBinaryMissing
        }
        if fileManager.fileExists(atPath: Self.socketPath(for: paths.dataDir)) {
            return
        }
        if let process, process.isRunning {
            return
        }

        let process = Process()
        var arguments = [daemonEntry.path, "--data-dir", paths.dataDir.path, "--socket-path", Self.socketPath(for: paths.dataDir)]
        var environment = ProcessInfo.processInfo.environment
        if paths.repoRoot == nil {
            let resourcesPath = daemonEntry
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            arguments.append(contentsOf: ["--packaged", "--resources-path", resourcesPath.path])
            environment["ACCOMPLISH_IS_PACKAGED"] = "1"
            environment["ACCOMPLISH_RESOURCES_PATH"] = resourcesPath.path
        } else if let repoRoot = paths.repoRoot {
            arguments.append(contentsOf: ["--app-path", repoRoot.path])
            let desktopRoot = repoRoot.appendingPathComponent("apps/desktop", isDirectory: true)
            environment["APP_ROOT"] = desktopRoot.path
            environment["MCP_TOOLS_PATH"] = repoRoot.appendingPathComponent("packages/agent-core/mcp-tools").path
        }
        if nodeBinary.lastPathComponent == "env" {
            process.executableURL = nodeBinary
            process.arguments = ["node"] + arguments
        } else {
            process.executableURL = nodeBinary
            process.arguments = arguments
        }
        if let repoRoot = paths.repoRoot {
            process.currentDirectoryURL = repoRoot
        }
        process.environment = environment
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            self.process = process
        } catch {
            throw ExecutorProcessError.launchFailed(error.localizedDescription)
        }
    }

    public func stop() {
        process?.terminate()
        process = nil
    }

    public static func socketPath(for dataDir: URL) -> String {
        dataDir.appendingPathComponent("daemon.sock").path
    }
}

public actor DemoExecutorClient: ExecutorClientProtocol {
    private var tasks: [AUCTaskRecord] = [
        AUCTaskRecord(
            id: "demo-1",
            prompt: "Download PDF and email us...",
            summary: "Download PDF and email us...",
            status: .completed,
            createdAt: Date().addingTimeInterval(-1800),
            currentAction: "Verified artifact"
        ),
        AUCTaskRecord(
            id: "demo-2",
            prompt: "Open downloads folder",
            summary: "Open downloads folder",
            status: .running,
            createdAt: Date().addingTimeInterval(-90),
            currentAction: "Loading agent..."
        )
    ]

    public init() {}

    public func connect() async throws {}

    public func startTask(_ composer: AUCTaskComposerState) async throws -> AUCTaskRecord {
        let task = AUCTaskRecord(
            id: "demo-\(Int(Date().timeIntervalSince1970))",
            prompt: composer.trimmedPrompt,
            summary: composer.trimmedPrompt,
            status: .running,
            createdAt: Date(),
            currentAction: "Starting AUC task"
        )
        tasks.insert(task, at: 0)
        return task
    }

    public func cancelTask(id: String) async throws { update(id: id, status: .cancelled, action: "Cancelled") }
    public func interruptTask(id: String) async throws { update(id: id, status: .interrupted, action: "Interrupted") }
    public func resumeSession(sessionID: String, prompt: String, taskID: String?) async throws -> AUCTaskRecord {
        try await startTask(AUCTaskComposerState(prompt: prompt, mode: taskID.map { .followUp(taskID: $0) } ?? .newTask))
    }
    public func getTask(id: String) async throws -> AUCTaskRecord? { tasks.first { $0.id == id } }
    public func listTasks() async throws -> [AUCTaskRecord] { tasks }
    public func deleteTask(id: String) async throws { tasks.removeAll { $0.id == id } }
    public func respondToPermission(
        requestID: String,
        taskID: String,
        allowed: Bool,
        selectedOptions: [String]?,
        customText: String?
    ) async throws {}
    public func getProviderSettings() async throws -> AUCProviderSettings {
        AUCProviderSettings(hasReadyProvider: true, selectedModel: AUCModelSelection(provider: "openai", model: "GPT 5.2"))
    }
    public func getOpenAIBaseURL() async throws -> String { "" }
    public func saveOpenAIAPIKey(apiKey: String, baseURL: String?, modelID: String) async throws {}
    public func setSelectedModel(_ model: AUCModelSelection) async throws {}
    public func getTodos(taskID: String) async throws -> [String] { ["Plan", "Act", "Verify"] }
    public func subscribeToTaskEvents(taskID: String) async throws -> AsyncThrowingStream<AUCTaskEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = tasks.first { $0.id == taskID }
            continuation.yield(AUCTaskEvent(taskID: taskID, type: "snapshot", message: task?.currentAction, task: task))
            continuation.finish()
        }
    }

    private func update(id: String, status: AUCTaskStatus, action: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = status
        tasks[index].currentAction = action
        tasks[index].updatedAt = Date()
    }
}
