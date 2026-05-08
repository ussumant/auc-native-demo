import Darwin
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
    case runtimePreflightFailed(String)
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .daemonEntryMissing:
            return "Could not find the bundled AUC daemon entrypoint."
        case .nodeBinaryMissing:
            return "Could not find a Node runtime for the bundled executor."
        case .runtimePreflightFailed(let message):
            return "The bundled Node runtime crashed before the executor could start: \(message)"
        case .launchFailed(let message):
            return "Could not launch the AUC executor: \(message)"
        }
    }
}

public struct AUCManagedRuntimeProcess: Equatable, Sendable {
    public var pid: Int32
    public var command: String

    public init(pid: Int32, command: String) {
        self.pid = pid
        self.command = command
    }
}

public actor ExecutorProcessManager {
    public private(set) var process: Process?
    private let fileManager: FileManager
    private var logFileHandle: FileHandle?

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

        let executableResources = Self.resourcesURLFromExecutablePath(environment["AUC_EXECUTABLE_PATH"])
        let resourceCandidates = [bundle.resourceURL, executableResources]
        let resources = resourceCandidates.compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("Executor/daemon/index.js").path)
        } ?? bundle.resourceURL ?? executableResources
        let bundledNode = [
            resources?.appendingPathComponent("nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin/node"),
            resources?.appendingPathComponent("Executor/nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin/node")
        ].compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
        let bundledEntry = resources?.appendingPathComponent("Executor/daemon/index.js")
        if let bundledNode, let bundledEntry,
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

        let node = [
            resources?.appendingPathComponent("nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin/node"),
            resources?.appendingPathComponent("Executor/nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin/node")
        ].compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
        let entry = resources?.appendingPathComponent("Executor/daemon/index.js")
        return ExecutorPaths(
            repoRoot: nil,
            nodeBinary: node,
            daemonEntry: entry,
            dataDir: dataDir
        )
    }

    private static func resourcesURLFromExecutablePath(_ environmentExecutablePath: String?) -> URL? {
        let executablePath = environmentExecutablePath ?? ProcessInfo.processInfo.arguments.first
        guard let executablePath else { return nil }
        let executableURL = URL(fileURLWithPath: executablePath)
        let macOSDirectory = executableURL.deletingLastPathComponent()
        guard macOSDirectory.lastPathComponent == "MacOS" else { return nil }
        return macOSDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
    }

    public func ensureRunning(paths: ExecutorPaths) async throws {
        try fileManager.createDirectory(at: paths.dataDir, withIntermediateDirectories: true)
        guard let daemonEntry = paths.daemonEntry, fileManager.fileExists(atPath: daemonEntry.path) else {
            throw ExecutorProcessError.daemonEntryMissing
        }
        guard let nodeBinary = paths.nodeBinary else {
            throw ExecutorProcessError.nodeBinaryMissing
        }
        let socketPath = Self.socketPath(for: paths.dataDir)
        if fileManager.fileExists(atPath: socketPath) {
            if Self.canConnect(toSocketPath: socketPath) {
                return
            }
            try? fileManager.removeItem(atPath: socketPath)
            try? fileManager.removeItem(at: paths.dataDir.appendingPathComponent("daemon.pid"))
        }
        if let process, process.isRunning {
            return
        }
        appendToDaemonLog("Preparing packaged daemon launch.\n", dataDir: paths.dataDir)
        terminateStaleRuntimeProcesses(paths: paths, includeCurrentResourceDaemons: true)
        appendToDaemonLog("Stale runtime cleanup finished.\n", dataDir: paths.dataDir)
        if paths.repoRoot == nil {
            try preflightPackagedRuntime(nodeBinary: nodeBinary, paths: paths)
        }
        appendToDaemonLog("Node preflight finished.\n", dataDir: paths.dataDir)

        let process = Process()
        var arguments = [daemonEntry.path, "--data-dir", paths.dataDir.path, "--socket-path", socketPath]
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
        if let handle = try? Self.openDaemonLog(in: paths.dataDir, fileManager: fileManager) {
            logFileHandle = handle
            process.standardOutput = handle
            process.standardError = handle
        } else {
            process.standardOutput = Pipe()
            process.standardError = Pipe()
        }

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
        try? logFileHandle?.close()
        logFileHandle = nil
    }

    public static func socketPath(for dataDir: URL) -> String {
        dataDir.appendingPathComponent("daemon.sock").path
    }

    public static func daemonLogPath(for dataDir: URL) -> URL {
        dataDir
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("daemon.log")
    }

    public static func diagnostics(
        paths: ExecutorPaths,
        appPath: String,
        installStatus: AUCInstallLocationStatus?,
        isConnected: Bool,
        executorPhase: AUCExecutorPhase,
        providerReady: Bool,
        lastError: String?
    ) -> AUCExecutorDiagnostics {
        let socketPath = socketPath(for: paths.dataDir)
        let expectedResourcesPath = expectedResourcesPath(for: paths)
        let daemonProcess = runningManagedDaemonProcesses(socketPath: socketPath).first
        let staleDescription = daemonProcess
            .flatMap { process -> String? in
                guard isStaleManagedProcess(process.command, expectedResourcesPath: expectedResourcesPath) else {
                    return nil
                }
                return "pid \(process.pid) from a different app bundle"
            }
        let pid = daemonProcess?.pid ?? readDaemonPID(from: paths.dataDir)
        let status = installStatus ?? AUCInstallLocationGuard.evaluate(appPath: appPath, isOpenAIDemoMode: false)
        let logError = latestDaemonLogError(in: paths.dataDir)
        return AUCExecutorDiagnostics(
            appPath: appPath,
            isRunningFromDMG: status.isRunningFromDMG,
            isTranslocated: status.isTranslocated,
            dataDir: paths.dataDir.path,
            socketPath: socketPath,
            daemonPid: pid,
            nodeBinaryPath: paths.nodeBinary?.path,
            daemonEntryPath: paths.daemonEntry?.path,
            logPath: daemonLogPath(for: paths.dataDir).path,
            isConnected: isConnected,
            executorPhase: executorPhase,
            providerReady: providerReady,
            lastError: lastError ?? staleDescription ?? logError,
            daemonCommand: daemonProcess?.command,
            staleDaemonDescription: staleDescription,
            lastLogError: logError
        )
    }

    public func cleanupStaleRuntimeFiles(paths: ExecutorPaths) {
        stop()
        terminateStaleRuntimeProcesses(paths: paths, includeCurrentResourceDaemons: true)
        try? fileManager.removeItem(atPath: Self.socketPath(for: paths.dataDir))
        try? fileManager.removeItem(at: paths.dataDir.appendingPathComponent("daemon.pid"))
    }

    public static func parseProcessList(_ text: String) -> [AUCManagedRuntimeProcess] {
        text.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let firstSpace = line.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            let pidText = line[..<firstSpace].trimmingCharacters(in: .whitespaces)
            let command = line[firstSpace...].trimmingCharacters(in: .whitespaces)
            guard let pid = Int32(pidText), !command.isEmpty else { return nil }
            return AUCManagedRuntimeProcess(pid: pid, command: command)
        }
    }

    public static func isManagedDaemonProcess(_ command: String, socketPath: String) -> Bool {
        command.contains("daemon/index.js") &&
            command.contains("--socket-path \(socketPath)") &&
            (command.contains("/AUCNative.app/Contents/Resources/") ||
             command.contains("/AUC Native.app/Contents/Resources/"))
    }

    public static func isStaleManagedProcess(_ command: String, expectedResourcesPath: String?) -> Bool {
        guard command.contains("/AUCNative.app/Contents/Resources/") ||
              command.contains("/AUC Native.app/Contents/Resources/") ||
              command.contains("/AppTranslocation/") else {
            return false
        }
        guard let expectedResourcesPath, !expectedResourcesPath.isEmpty else { return true }
        return !command.contains(expectedResourcesPath)
    }

    public static func expectedResourcesPath(for paths: ExecutorPaths) -> String? {
        guard paths.repoRoot == nil, let daemonEntry = paths.daemonEntry else { return nil }
        return daemonEntry
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
    }

    private func preflightPackagedRuntime(nodeBinary: URL, paths: ExecutorPaths) throws {
        appendToDaemonLog("Starting Node preflight with packaged runtime.\n", dataDir: paths.dataDir)
        let process = Process()
        process.executableURL = nodeBinary
        process.arguments = ["-e", "process.stdout.write('ok')"]
        let environment = ProcessInfo.processInfo.environment
        process.environment = environment

        let logHandle = try? Self.openDaemonLog(in: paths.dataDir, fileManager: fileManager)
        if let logHandle {
            process.standardOutput = logHandle
            process.standardError = logHandle
        } else {
            process.standardOutput = Pipe()
            process.standardError = Pipe()
        }
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            try? logHandle?.close()
            appendToDaemonLog("Node preflight launch failed: \(error.localizedDescription)\n", dataDir: paths.dataDir)
            throw ExecutorProcessError.runtimePreflightFailed(error.localizedDescription)
        }

        try? logHandle?.close()
        guard process.terminationStatus == 0 else {
            let message = Self.latestDaemonLogError(in: paths.dataDir) ?? "Bundled Node exited with status \(process.terminationStatus)."
            appendToDaemonLog("Node preflight failed: \(message)\n", dataDir: paths.dataDir)
            throw ExecutorProcessError.runtimePreflightFailed(Self.compactRuntimeError(message))
        }
    }

    private func terminateStaleRuntimeProcesses(paths: ExecutorPaths, includeCurrentResourceDaemons: Bool) {
        let socketPath = Self.socketPath(for: paths.dataDir)
        let expectedResourcesPath = Self.expectedResourcesPath(for: paths)
        for process in Self.runningManagedProcesses(socketPath: socketPath) {
            let isDaemon = Self.isManagedDaemonProcess(process.command, socketPath: socketPath)
            let isStale = Self.isStaleManagedProcess(process.command, expectedResourcesPath: expectedResourcesPath)
            guard isStale || (includeCurrentResourceDaemons && isDaemon) else { continue }
            Darwin.kill(process.pid, SIGTERM)
        }
        Thread.sleep(forTimeInterval: 0.15)
        for process in Self.runningManagedProcesses(socketPath: socketPath) {
            let isDaemon = Self.isManagedDaemonProcess(process.command, socketPath: socketPath)
            let isStale = Self.isStaleManagedProcess(process.command, expectedResourcesPath: expectedResourcesPath)
            guard isStale || (includeCurrentResourceDaemons && isDaemon) else { continue }
            Darwin.kill(process.pid, SIGKILL)
        }
    }

    private static func runningManagedDaemonProcesses(socketPath: String) -> [AUCManagedRuntimeProcess] {
        runningManagedProcesses(socketPath: socketPath).filter {
            isManagedDaemonProcess($0.command, socketPath: socketPath)
        }
    }

    private static func runningManagedProcesses(socketPath: String) -> [AUCManagedRuntimeProcess] {
        runningProcesses().filter { process in
            isManagedDaemonProcess(process.command, socketPath: socketPath) ||
                (process.command.contains("/AUCNative.app/Contents/Resources/") ||
                 process.command.contains("/AUC Native.app/Contents/Resources/") ||
                 process.command.contains("/AppTranslocation/")) &&
                (process.command.contains("mcp-tools") ||
                 process.command.contains("opencode") ||
                 process.command.contains("nodejs/darwin-arm64"))
        }
    }

    private static func runningProcesses() -> [AUCManagedRuntimeProcess] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,command="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return parseProcessList(text).filter { $0.pid != currentPID }
    }

    private func appendToDaemonLog(_ text: String, dataDir: URL) {
        guard let data = text.data(using: .utf8),
              let handle = try? Self.openDaemonLog(in: dataDir, fileManager: fileManager) else {
            return
        }
        try? handle.write(contentsOf: data)
        try? handle.close()
    }

    public static func latestDaemonLogError(in dataDir: URL) -> String? {
        let url = daemonLogPath(for: dataDir)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data.suffix(32_768), encoding: .utf8) else {
            return nil
        }
        let markers = [
            "Fatal process out of memory: Failed to reserve virtual memory for CodeRange",
            "Node preflight failed",
            "OpenCode server exited",
            "Task startup failed"
        ]
        for line in text.components(separatedBy: .newlines).reversed() {
            for marker in markers where line.contains(marker) {
                return marker
            }
        }
        return nil
    }

    private static func compactRuntimeError(_ message: String) -> String {
        if message.contains("Failed to reserve virtual memory for CodeRange") {
            return "Node/V8 could not reserve CodeRange memory after stale runtime cleanup. Quit old AUC copies or restart the Mac, then try Repair executor."
        }
        if message.isEmpty {
            return "No output from bundled Node preflight."
        }
        return message.count > 240 ? String(message.prefix(240)) + "..." : message
    }

    private static func openDaemonLog(in dataDir: URL, fileManager: FileManager) throws -> FileHandle {
        let logURL = daemonLogPath(for: dataDir)
        try fileManager.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        if let header = "\n--- AUC daemon launch \(ISO8601DateFormatter().string(from: Date())) ---\n".data(using: .utf8) {
            try handle.write(contentsOf: header)
        }
        return handle
    }

    private static func readDaemonPID(from dataDir: URL) -> Int32? {
        let pidURL = dataDir.appendingPathComponent("daemon.pid")
        guard let data = try? Data(contentsOf: pidURL),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pid = payload["pid"] as? Int else {
            return nil
        }
        return Int32(pid)
    }

    private static func canConnect(toSocketPath socketPath: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
        guard socketPath.utf8.count < maxPathLength else { return false }

        _ = withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { charPointer in
                socketPath.withCString { source in
                    strncpy(charPointer, source, maxPathLength)
                }
            }
        }

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
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
    public func ping() async throws {}

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
