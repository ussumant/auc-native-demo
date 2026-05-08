import Foundation
import Observation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
public final class AUCAppModel {
    public static let openAISetupPromptSeenKey = "auc.didShowOpenAISetupPrompt"
    public static let onboardingCompletedKey = "auc.didCompleteLauncherFirstOnboarding"
    public static let openAISetupMessage = "Add your OpenAI key to run tasks."
    public static let defaultOpenAIBaseURL = "https://api.openai.com/v1"
    public static let openAIDemoModelID = "openai/gpt-5.2"

    public var composer = AUCTaskComposerState()
    public var tasks: [AUCTaskRecord] = []
    public var activeTaskID: String?
    public var providerSettings = AUCProviderSettings()
    public var permissionRequest: AUCPermissionRequest?
    public var proof: AUCProof?
    public var isExecutorConnected = false
    public var isBusy = false
    public var isSavingProviderSettings = false
    public var errorMessage: String?
    public var settingsMessage: String?
    public var openAIBaseURL = ""
    public var isLauncherPresented = false
    public var isLauncherCollapsed = false
    public var launcherQuery = ""
    public var isSettingsPresented = false
    public var isOnboardingPresented = false
    public var isOpenAIDemoMode = false
    public var isDemoKeyActive = false
    public var hasSeededDemoKey = false
    public var authErrorMessage: String?

    private var executor: any ExecutorClientProtocol
    private var eventSource: (any DaemonEventSourceProtocol)?
    @ObservationIgnored private let userDefaults: UserDefaults
    private let demoExecutor = DemoExecutorClient()
    @ObservationIgnored private var taskMonitors: [String: _Concurrency.Task<Void, Never>] = [:]
    @ObservationIgnored private var eventListenerTask: _Concurrency.Task<Void, Never>?
    @ObservationIgnored private var taskListRefreshTask: _Concurrency.Task<Void, Never>?

    public init(executor: any ExecutorClientProtocol = DemoExecutorClient(), userDefaults: UserDefaults = .standard) {
        self.executor = executor
        self.userDefaults = userDefaults
    }

    public var activeTask: AUCTaskRecord? {
        guard let activeTaskID else { return nil }
        return tasks.first { $0.id == activeTaskID }
    }

    public var visibleLauncherTasks: [AUCTaskRecord] {
        let query = launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(tasks.prefix(8)) }
        return tasks.filter {
            $0.prompt.localizedCaseInsensitiveContains(query) ||
                ($0.summary ?? "").localizedCaseInsensitiveContains(query)
        }.prefix(8).map { $0 }
    }

    public func configure(executor: any ExecutorClientProtocol, eventSource: (any DaemonEventSourceProtocol)? = nil) {
        self.executor = executor
        self.eventSource = eventSource
        eventListenerTask?.cancel()
        eventListenerTask = nil
        taskListRefreshTask?.cancel()
        taskListRefreshTask = nil
    }

    public func connect() async {
        do {
            try await executor.connect()
            if let eventSource {
                try? await eventSource.connect()
                startEventListener(from: eventSource)
            }
            isExecutorConnected = true
            errorMessage = nil
            providerSettings = (try? await executor.getProviderSettings()) ?? AUCProviderSettings()
            openAIBaseURL = (try? await executor.getOpenAIBaseURL()) ?? ""
            tasks = (try? await executor.listTasks()) ?? []
            maybePromptForOpenAISetupOnFirstLaunch()
            startTaskListRefresh()
        } catch {
            isExecutorConnected = false
            errorMessage = error.localizedDescription
            if tasks.isEmpty {
                tasks = (try? await demoExecutor.listTasks()) ?? []
            }
        }
    }

    public func saveOpenAIAPIKey(_ apiKey: String, baseURL: String?, modelID: String = "openai/gpt-5.2") async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            settingsMessage = "Enter an OpenAI API key first."
            return
        }
        let normalizedBaseURL = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURLToSave = normalizedBaseURL?.isEmpty == false ? normalizedBaseURL! : Self.defaultOpenAIBaseURL
        if !baseURLToSave.isEmpty {
            guard let url = URL(string: baseURLToSave), ["http", "https"].contains(url.scheme?.lowercased()) else {
                settingsMessage = "Base URL must be a valid http or https URL."
                return
            }
        }

        isSavingProviderSettings = true
        settingsMessage = nil
        errorMessage = nil
        do {
            try await executor.saveOpenAIAPIKey(apiKey: trimmedKey, baseURL: baseURLToSave, modelID: modelID)
            providerSettings = try await executor.getProviderSettings()
            openAIBaseURL = (try? await executor.getOpenAIBaseURL()) ?? baseURLToSave
            settingsMessage = "OpenAI key saved. AUC is ready to run tasks."
            if isOpenAIDemoMode, hasSeededDemoKey, modelID == Self.openAIDemoModelID {
                isDemoKeyActive = true
            }
        } catch {
            errorMessage = error.localizedDescription
            settingsMessage = error.localizedDescription
        }
        isSavingProviderSettings = false
    }

    public func configureOpenAIDemoMode(seededKeyAvailable: Bool) {
        isOpenAIDemoMode = true
        hasSeededDemoKey = seededKeyAvailable
    }

    public func applySeededDemoKeyIfNeeded(_ apiKey: String?) async {
        guard isOpenAIDemoMode,
              let apiKey,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !providerSettings.hasReadyProvider else {
            return
        }
        await saveOpenAIAPIKey(
            apiKey,
            baseURL: Self.defaultOpenAIBaseURL,
            modelID: Self.openAIDemoModelID
        )
        if providerSettings.hasReadyProvider {
            isDemoKeyActive = true
            settingsMessage = "Demo key active · $5 budget"
        }
    }

    public func completeOnboarding(showLauncher: Bool = true) {
        userDefaults.set(true, forKey: Self.onboardingCompletedKey)
        isOnboardingPresented = false
        isSettingsPresented = false
        if showLauncher {
            isLauncherPresented = true
            isLauncherCollapsed = false
        }
    }

    public func openOnboarding() {
        isOnboardingPresented = true
        isSettingsPresented = false
    }

    public func submitComposer(keepLauncherOpen: Bool = false) async {
        guard composer.canSubmit, !isBusy else { return }
        guard providerSettings.hasReadyProvider else {
            presentOpenAISetup()
            return
        }
        isBusy = true
        errorMessage = nil
        settingsMessage = nil
        permissionRequest = nil
        let submittedMode = composer.mode
        do {
            var request = composer
            if request.selectedModel == nil {
                request.selectedModel = isOpenAIDemoMode
                    ? AUCModelSelection(provider: "openai", model: Self.openAIDemoModelID)
                    : providerSettings.selectedModel
            }

            let task: AUCTaskRecord
            let followUpTaskID: String?
            switch request.mode {
            case .newTask:
                let taskID = request.clientTaskID ?? "native-\(UUID().uuidString)"
                request.clientTaskID = taskID
                showOptimisticNewTask(id: taskID, prompt: request.trimmedPrompt)
                task = try await executor.startTask(request)
                followUpTaskID = nil
            case .followUp(let taskID):
                guard let sessionID = tasks.first(where: { $0.id == taskID })?.sessionID else {
                    throw AUCAppModelError.missingSessionForFollowUp
                }
                markFollowUpRunning(taskID: taskID, prompt: request.trimmedPrompt)
                composer.mode = .newTask
                task = try await executor.resumeSession(
                    sessionID: sessionID,
                    prompt: request.trimmedPrompt,
                    taskID: taskID
                )
                followUpTaskID = taskID
            }
            if let followUpTaskID {
                upsertFollowUp(task, into: followUpTaskID)
                activeTaskID = followUpTaskID
            } else {
                upsert(task)
                activeTaskID = task.id
            }
            proof = nil
            composer.prompt = ""
            composer.attachments = []
            composer.workingDirectory = nil
            composer.mode = .newTask
            launcherQuery = ""
            if !keepLauncherOpen {
                isLauncherPresented = false
            }
            monitorTask(id: followUpTaskID ?? task.id)
            await refreshTaskList(selectLatestRunning: false)
        } catch {
            errorMessage = error.localizedDescription
            if case .followUp(let taskID) = submittedMode {
                markFollowUpFailed(taskID: taskID, message: error.localizedDescription)
            } else if let activeTaskID {
                markFollowUpFailed(taskID: activeTaskID, message: error.localizedDescription)
            }
        }
        isBusy = false
    }

    private func maybePromptForOpenAISetupOnFirstLaunch() {
        if isOpenAIDemoMode {
            guard !userDefaults.bool(forKey: Self.onboardingCompletedKey) else { return }
            isOnboardingPresented = true
            if !providerSettings.hasReadyProvider {
                settingsMessage = hasSeededDemoKey ? "Preparing the seeded OpenAI demo key." : Self.openAISetupMessage
            }
            return
        }
        guard !providerSettings.hasReadyProvider else { return }
        guard !userDefaults.bool(forKey: Self.openAISetupPromptSeenKey) else { return }
        userDefaults.set(true, forKey: Self.openAISetupPromptSeenKey)
        presentOpenAISetup()
    }

    private func presentOpenAISetup() {
        settingsMessage = Self.openAISetupMessage
        errorMessage = nil
        isSettingsPresented = true
    }

    public func refreshTaskList(selectLatestRunning: Bool = true) async {
        do {
            let refreshed = try await executor.listTasks()
            for task in refreshed {
                upsert(task)
            }
            if selectLatestRunning,
               let latestRunning = tasks.first(where: { !$0.status.isTerminal }),
               activeTask == nil || activeTask?.status.isTerminal == true {
                activeTaskID = latestRunning.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func submitLauncherPrompt(keepLauncherOpen: Bool = true) async {
        var prompt = launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        if let request = permissionRequest,
           request.type == "question",
           request.taskID == activeTaskID {
            await respondToPermission(request, allowed: true, customText: prompt)
            launcherQuery = ""
            if keepLauncherOpen {
                isLauncherPresented = true
            }
            return
        }
        let forceNewTask = prompt.hasPrefix("/new-task")
        if forceNewTask {
            prompt = prompt
                .replacingOccurrences(of: "/new-task", with: "", options: [.anchored])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else {
                activeTaskID = nil
                composer.mode = .newTask
                launcherQuery = ""
                return
            }
        }

        composer.prompt = prompt
        if !forceNewTask,
           let activeTaskID,
           let activeTask,
           activeTask.sessionID != nil {
            composer.mode = .followUp(taskID: activeTaskID)
        } else {
            composer.mode = .newTask
            if forceNewTask {
                activeTaskID = nil
            }
        }

        if keepLauncherOpen {
            isLauncherPresented = true
        }
        await submitComposer(keepLauncherOpen: keepLauncherOpen)
    }

    public func cancelActiveTask() async {
        guard let activeTaskID else { return }
        if let index = tasks.firstIndex(where: { $0.id == activeTaskID }) {
            tasks[index].currentAction = "Stopping task"
        }

        do {
            try await executor.cancelTask(id: activeTaskID)
        } catch {
            do {
                try await executor.interruptTask(id: activeTaskID)
            } catch {
                errorMessage = "Stop requested, but the daemon did not confirm it: \(error.localizedDescription)"
            }
        }

        taskMonitors[activeTaskID]?.cancel()
        taskMonitors[activeTaskID] = nil
        if let index = tasks.firstIndex(where: { $0.id == activeTaskID }) {
            tasks[index].status = .cancelled
            tasks[index].currentAction = "Stopped"
        }
    }

    public func respondToPermission(
        _ request: AUCPermissionRequest,
        allowed: Bool,
        selectedOptions: [String]? = nil,
        customText: String? = nil
    ) async {
        do {
            try await executor.respondToPermission(
                requestID: request.id,
                taskID: request.taskID,
                allowed: allowed,
                selectedOptions: selectedOptions,
                customText: customText
            )
            if permissionRequest?.id == request.id {
                permissionRequest = nil
            }
            if let index = tasks.firstIndex(where: { $0.id == request.taskID }) {
                tasks[index].status = .running
                tasks[index].currentAction = request.type == "question"
                    ? (allowed ? "Answer sent" : "Question cancelled")
                    : (allowed ? "Permission approved" : "Permission denied")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func startFollowUp() {
        guard let activeTaskID else { return }
        composer.mode = .followUp(taskID: activeTaskID)
        isLauncherPresented = true
    }

    public func selectTask(_ task: AUCTaskRecord) {
        activeTaskID = task.id
        isLauncherPresented = false
    }

    public func toggleLauncher() {
        isLauncherPresented.toggle()
    }

    public func addAttachment(_ url: URL) {
        guard composer.attachments.count < 8 else {
            errorMessage = "AUC supports up to 8 attachments for now."
            return
        }
        composer.attachments.append(AUCFileAttachment(url: url))
    }

    public func setWorkingDirectory(_ url: URL) {
        composer.workingDirectory = url
    }

    public func reveal(_ url: URL) {
        NSWorkspaceBridge.shared.reveal(url)
    }

    public func openFileAccessSettings() {
        NSWorkspaceBridge.shared.openFileAccessSettings()
    }

    public func revealDownloadsFolder() {
        NSWorkspaceBridge.shared.reveal(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
    }

    private func upsert(_ task: AUCTaskRecord) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = tasks[index].merged(with: task)
            recoverCompletedFileWriteIfPossible(at: index)
        } else {
            tasks.insert(task, at: 0)
            recoverCompletedFileWriteIfPossible(at: 0)
        }
    }

    private func showOptimisticNewTask(id: String, prompt: String) {
        let seed = AUCTaskRecord(
            id: id,
            prompt: prompt.isEmpty ? "New task" : prompt,
            status: .running,
            createdAt: Date(),
            currentAction: "Starting task",
            messages: [
                AUCTaskMessage(
                    id: "native-user-\(UUID().uuidString)",
                    type: "user",
                    content: prompt,
                    timestamp: Date()
                )
            ]
        )
        upsert(seed)
        activeTaskID = id
    }

    private func upsertFollowUp(_ task: AUCTaskRecord, into taskID: String) {
        var followUpTask = task
        followUpTask.id = taskID
        if let existing = tasks.first(where: { $0.id == taskID }) {
            followUpTask.prompt = existing.prompt
            followUpTask.summary = existing.summary
        }
        upsert(followUpTask)
    }

    private func markFollowUpRunning(taskID: String, prompt: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].status = .running
        tasks[index].currentAction = "Continuing \(tasks[index].displayTitle)"
        tasks[index].messages.append(
            AUCTaskMessage(
                id: "native-user-\(UUID().uuidString)",
                type: "user",
                content: prompt,
                timestamp: Date()
            )
        )
    }

    private func markFollowUpFailed(taskID: String, message: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].status = .failed
        tasks[index].currentAction = message
    }

    private func startEventListener(from eventSource: any DaemonEventSourceProtocol) {
        guard eventListenerTask == nil else { return }
        eventListenerTask = _Concurrency.Task { [weak self] in
            let stream = await eventSource.events()
            for await event in stream {
                if _Concurrency.Task.isCancelled { return }
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: AUCTaskEvent) async {
        guard let index = ensureTaskExists(for: event) else { return }
        if event.type != "permission.request",
           permissionRequest?.taskID == event.taskID,
           event.status != .waitingPermission {
            permissionRequest = nil
        }
        if let task = event.task {
            tasks[index] = tasks[index].merged(with: task)
        }
        if let status = event.status {
            tasks[index].status = status
            if status != .waitingPermission, permissionRequest?.taskID == event.taskID {
                permissionRequest = nil
            }
        }
        if let summary = event.summary {
            tasks[index].summary = summary
        }
        if let result = event.result {
            tasks[index].result = result
            tasks[index].sessionID = result.sessionID ?? tasks[index].sessionID
        }
        if !event.taskMessages.isEmpty {
            tasks[index].mergeMessages(event.taskMessages)
            tasks[index].currentAction = event.taskMessages.lastMeaningfulAction ?? tasks[index].currentAction
            recoverCompletedFileWriteIfPossible(at: index)
        }
        if !event.todos.isEmpty || event.type == "todo.update" {
            tasks[index].todos = event.todos
        }
        if let browserFrame = event.browserFrame {
            tasks[index].browserFrame = browserFrame
        }
        if let permissionRequest = event.permissionRequest {
            permissionRequestForDisplay(permissionRequest)
            tasks[index].status = .waitingPermission
        }
        if let message = event.message, !message.isEmpty {
            switch event.type {
            case "task.progress":
                tasks[index].currentAction = message
            case "task.error":
                tasks[index].currentAction = message
                errorMessage = message
            case "auth.error":
                authErrorMessage = message
                errorMessage = message
            default:
                break
            }
        }
        if event.type == "task.complete" {
            if permissionRequest?.taskID == event.taskID {
                permissionRequest = nil
            }
            tasks[index].status = .completed
            proof = AUCProof(
                title: "Task completed",
                detail: tasks[index].summary ?? tasks[index].result?.status ?? "AUC finished this task.",
                artifactURLs: tasks[index].artifactURLs
            )
        }
        if activeTaskID == nil {
            activeTaskID = event.taskID
        }
    }

    private func permissionRequestForDisplay(_ request: AUCPermissionRequest) {
        permissionRequest = request
    }

    private func recoverCompletedFileWriteIfPossible(at index: Int) {
        guard tasks.indices.contains(index),
              !tasks[index].status.isTerminal,
              let operation = tasks[index].runningFileWriteOperation,
              Date().timeIntervalSince(operation.startedAt) >= 4 else {
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: operation.url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return
        }

        let modificationDate = ((try? FileManager.default.attributesOfItem(atPath: operation.url.path))?[.modificationDate] as? Date) ?? .distantPast
        guard modificationDate >= operation.startedAt.addingTimeInterval(-2) else {
            return
        }

        if !tasks[index].artifactURLs.contains(operation.url) {
            tasks[index].artifactURLs.append(operation.url)
        }
        tasks[index].status = .completed
        tasks[index].currentAction = "Saved \(operation.url.lastPathComponent)"
        tasks[index].result = tasks[index].result ?? AUCTaskResult(status: "success", sessionID: tasks[index].sessionID)
        proof = AUCProof(
            title: "File saved",
            detail: "Saved \(operation.url.lastPathComponent) in \(operation.url.deletingLastPathComponent().lastPathComponent).",
            artifactURLs: [operation.url]
        )
        if permissionRequest?.taskID == tasks[index].id {
            permissionRequest = nil
        }
    }

    private func ensureTaskExists(for event: AUCTaskEvent) -> Int? {
        if let index = tasks.firstIndex(where: { $0.id == event.taskID }) {
            return index
        }
        guard !event.taskID.isEmpty else { return nil }
        let seed = event.task ?? AUCTaskRecord(
            id: event.taskID,
            prompt: event.message ?? "Running task",
            status: event.status ?? .running,
            createdAt: Date(),
            currentAction: event.message
        )
        tasks.insert(seed, at: 0)
        return 0
    }

    private func monitorTask(id: String) {
        taskMonitors[id]?.cancel()
        taskMonitors[id] = _Concurrency.Task { [weak self] in
            guard let self else { return }
            for _ in 0..<180 {
                if _Concurrency.Task.isCancelled { return }
                do {
                    try await _Concurrency.Task.sleep(for: .seconds(2))
                    if let task = try await executor.getTask(id: id) {
                        upsert(task)
                        if let index = tasks.firstIndex(where: { $0.id == id }) {
                            recoverCompletedFileWriteIfPossible(at: index)
                        }
                        if task.status.isTerminal {
                            taskMonitors[id] = nil
                            return
                        }
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    taskMonitors[id] = nil
                    return
                }
            }
            taskMonitors[id] = nil
        }
    }

    private func startTaskListRefresh() {
        taskListRefreshTask?.cancel()
        taskListRefreshTask = _Concurrency.Task { [weak self] in
            while !_Concurrency.Task.isCancelled {
                try? await _Concurrency.Task.sleep(for: .seconds(3))
                guard let self else { return }
                let shouldRefresh = isBusy || tasks.contains { !$0.status.isTerminal }
                guard shouldRefresh else { continue }
                await refreshTaskList()
            }
        }
    }
}

public enum AUCAppModelError: LocalizedError, Equatable {
    case missingSessionForFollowUp

    public var errorDescription: String? {
        switch self {
        case .missingSessionForFollowUp:
            return "This task does not have a resumable session yet. Start a new task instead."
        }
    }
}

public final class NSWorkspaceBridge: @unchecked Sendable {
    public static let shared = NSWorkspaceBridge()
    private init() {}

    public func reveal(_ url: URL) {
        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    public func openFileAccessSettings() {
        #if canImport(AppKit)
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
        #endif
    }
}
