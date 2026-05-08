import Foundation
import Testing
@testable import AUCNativeCore

@MainActor
struct AppModelTests {
    @Test func submitLauncherPromptStartsNewTaskFromLauncherText() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)
        model.useReadyProvider()
        model.launcherQuery = "  search attention is all you need  "

        await model.submitLauncherPrompt()

        #expect(await executor.startedPrompts == ["search attention is all you need"])
        #expect(model.activeTask?.prompt == "search attention is all you need")
        #expect(model.launcherQuery.isEmpty)
        #expect(model.isLauncherPresented)
    }

    @Test func submitLauncherPromptResumesTerminalActiveTaskWhenSessionExists() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)
        model.useReadyProvider()
        model.tasks = [
            AUCTaskRecord(
                id: "done-1",
                prompt: "old task",
                summary: "Original task name",
                status: .cancelled,
                sessionID: "session-1",
                createdAt: Date()
            )
        ]
        model.activeTaskID = "done-1"
        model.launcherQuery = "new task"

        await model.submitLauncherPrompt()

        #expect(await executor.startedPrompts.isEmpty)
        #expect(await executor.resumedPrompts == ["new task"])
        #expect(model.activeTaskID == "done-1")
        #expect(model.activeTask?.prompt == "old task")
        #expect(model.activeTask?.summary == "Original task name")
    }

    @Test func slashNewTaskStartsFreshEvenWithActiveTask() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)
        model.useReadyProvider()
        model.tasks = [
            AUCTaskRecord(
                id: "active-1",
                prompt: "old task",
                status: .running,
                sessionID: "session-1",
                createdAt: Date()
            )
        ]
        model.activeTaskID = "active-1"
        model.launcherQuery = "/new-task write a status note"

        await model.submitLauncherPrompt()

        #expect(await executor.startedPrompts == ["write a status note"])
        #expect(await executor.resumedPrompts.isEmpty)
        #expect(model.activeTask?.prompt == "write a status note")
    }

    @Test func submitLauncherPromptStartsFreshWhenActiveTaskHasNoSession() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)
        model.useReadyProvider()
        model.tasks = [
            AUCTaskRecord(
                id: "local-1",
                prompt: "old task",
                status: .completed,
                createdAt: Date()
            )
        ]
        model.activeTaskID = "local-1"
        model.launcherQuery = "new task"

        await model.submitLauncherPrompt()

        #expect(await executor.startedPrompts == ["new task"])
        #expect(await executor.resumedPrompts.isEmpty)
        #expect(model.activeTask?.prompt == "new task")
    }

    @Test func cancelActiveTaskStopsImmediatelyAndCallsDaemonCancel() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)
        model.tasks = [
            AUCTaskRecord(
                id: "running-1",
                prompt: "Open downloads",
                status: .running,
                createdAt: Date(),
                currentAction: "Working"
            )
        ]
        model.activeTaskID = "running-1"

        await model.cancelActiveTask()

        #expect(await executor.cancelledIDs == ["running-1"])
        #expect(model.activeTask?.status == .cancelled)
        #expect(model.activeTask?.currentAction == "Stopped")
    }

    @Test func cancelActiveTaskFallsBackToInterruptWhenCancelFails() async throws {
        let executor = RecordingExecutor()
        await executor.setCancelShouldFail(true)
        let model = AUCAppModel(executor: executor)
        model.tasks = [
            AUCTaskRecord(
                id: "running-2",
                prompt: "Long task",
                status: .running,
                createdAt: Date(),
                currentAction: "Working"
            )
        ]
        model.activeTaskID = "running-2"

        await model.cancelActiveTask()

        #expect(await executor.cancelledIDs == ["running-2"])
        #expect(await executor.interruptedIDs == ["running-2"])
        #expect(model.activeTask?.status == .cancelled)
        #expect(model.activeTask?.currentAction == "Stopped")
    }

    @Test func launcherPromptAnswersPendingQuestionInsteadOfResuming() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)
        model.useReadyProvider()
        model.tasks = [
            AUCTaskRecord(
                id: "running-question",
                prompt: "Retrieve transactions",
                status: .waitingPermission,
                sessionID: "session-1",
                createdAt: Date()
            )
        ]
        model.activeTaskID = "running-question"
        model.permissionRequest = AUCPermissionRequest(
            id: "questionreq-1",
            taskID: "running-question",
            type: "question",
            title: "Data source",
            message: "Where should I look?"
        )
        model.launcherQuery = "Use the Northstar PDF in Downloads"

        await model.submitLauncherPrompt()

        #expect(await executor.permissionResponses == [
            RecordingExecutor.PermissionResponse(
                requestID: "questionreq-1",
                taskID: "running-question",
                allowed: true,
                selectedOptions: nil,
                customText: "Use the Northstar PDF in Downloads"
            )
        ])
        #expect(await executor.resumedPrompts.isEmpty)
        #expect(model.launcherQuery.isEmpty)
        #expect(model.activeTask?.currentAction == "Answer sent")
    }

    @Test func connectPromptsForOpenAIKeyOnceWhenProviderMissing() async throws {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor, userDefaults: defaults)

        await model.connect()

        #expect(model.isSettingsPresented)
        #expect(model.settingsMessage == AUCAppModel.openAISetupMessage)
        #expect(defaults.bool(forKey: AUCAppModel.openAISetupPromptSeenKey))

        model.isSettingsPresented = false
        model.settingsMessage = nil
        await model.connect()

        #expect(!model.isSettingsPresented)
        #expect(model.settingsMessage == nil)
    }

    @Test func connectDoesNotPromptWhenProviderReady() async throws {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let executor = RecordingExecutor(providerSettings: .readyOpenAI)
        let model = AUCAppModel(executor: executor, userDefaults: defaults)

        await model.connect()

        #expect(!model.isSettingsPresented)
        #expect(model.settingsMessage == nil)
        #expect(!defaults.bool(forKey: AUCAppModel.openAISetupPromptSeenKey))
    }

    @Test func openAIDemoModeShowsOnboardingInsteadOfSettings() async throws {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor, userDefaults: defaults)
        model.configureOpenAIDemoMode(seededKeyAvailable: false)

        await model.connect()

        #expect(model.isOnboardingPresented)
        #expect(!model.isSettingsPresented)
        #expect(model.settingsMessage == AUCAppModel.openAISetupMessage)
    }

    @Test func seededDemoKeySavesOpenAIAndMarksDemoActive() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)
        model.configureOpenAIDemoMode(seededKeyAvailable: true)

        await model.connect()
        await model.applySeededDemoKeyIfNeeded(" sk-demo-key ")

        #expect(await executor.savedOpenAIKeys == ["sk-demo-key"])
        #expect(await executor.savedBaseURLs == [AUCAppModel.defaultOpenAIBaseURL])
        #expect(model.providerSettings.hasReadyProvider)
        #expect(model.isDemoKeyActive)
        #expect(model.settingsMessage == "Demo key active · $5 budget")
    }

    @Test func submitComposerWithoutProviderOpensSettingsAndPreservesPrompt() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)
        model.composer.prompt = "download attention is all you need"

        await model.submitComposer()

        #expect(await executor.startedPrompts.isEmpty)
        #expect(model.composer.prompt == "download attention is all you need")
        #expect(model.isSettingsPresented)
        #expect(model.settingsMessage == AUCAppModel.openAISetupMessage)
        #expect(!model.isBusy)
    }

    @Test func saveOpenAIKeyDefaultsBaseURLAndMarksProviderReady() async throws {
        let executor = RecordingExecutor()
        let model = AUCAppModel(executor: executor)

        await model.saveOpenAIAPIKey(" sk-test-key ", baseURL: "   ")

        #expect(await executor.savedOpenAIKeys == ["sk-test-key"])
        #expect(await executor.savedBaseURLs == [AUCAppModel.defaultOpenAIBaseURL])
        #expect(model.providerSettings.hasReadyProvider)
        #expect(model.openAIBaseURL == AUCAppModel.defaultOpenAIBaseURL)
        #expect(model.settingsMessage == "OpenAI key saved. AUC is ready to run tasks.")
    }
}

private func makeIsolatedDefaults() -> (String, UserDefaults) {
    let suiteName = "AUCAppModelTests.\(UUID().uuidString)"
    return (suiteName, UserDefaults(suiteName: suiteName)!)
}

private extension AUCProviderSettings {
    static let readyOpenAI = AUCProviderSettings(
        hasReadyProvider: true,
        selectedModel: AUCModelSelection(provider: "openai", model: "openai/gpt-5.2")
    )
}

@MainActor
private extension AUCAppModel {
    func useReadyProvider() {
        providerSettings = .readyOpenAI
    }
}

private actor RecordingExecutor: ExecutorClientProtocol {
    struct PermissionResponse: Equatable {
        var requestID: String
        var taskID: String
        var allowed: Bool
        var selectedOptions: [String]?
        var customText: String?
    }

    private(set) var startedPrompts: [String] = []
    private(set) var resumedPrompts: [String] = []
    private(set) var cancelledIDs: [String] = []
    private(set) var interruptedIDs: [String] = []
    private(set) var permissionResponses: [PermissionResponse] = []
    private(set) var savedOpenAIKeys: [String] = []
    private(set) var savedBaseURLs: [String?] = []
    private var cancelShouldFail = false
    private var providerSettings: AUCProviderSettings
    private var openAIBaseURL = ""

    enum RecordingError: Error {
        case cancelFailed
    }

    init(providerSettings: AUCProviderSettings = AUCProviderSettings()) {
        self.providerSettings = providerSettings
    }

    func setCancelShouldFail(_ shouldFail: Bool) {
        cancelShouldFail = shouldFail
    }

    func connect() async throws {}

    func startTask(_ composer: AUCTaskComposerState) async throws -> AUCTaskRecord {
        startedPrompts.append(composer.trimmedPrompt)
        return AUCTaskRecord(
            id: "task-\(startedPrompts.count)",
            prompt: composer.trimmedPrompt,
            status: .running,
            sessionID: "session-\(startedPrompts.count)",
            createdAt: Date()
        )
    }

    func cancelTask(id: String) async throws {
        cancelledIDs.append(id)
        if cancelShouldFail {
            throw RecordingError.cancelFailed
        }
    }

    func interruptTask(id: String) async throws {
        interruptedIDs.append(id)
    }

    func resumeSession(sessionID: String, prompt: String, taskID: String?) async throws -> AUCTaskRecord {
        resumedPrompts.append(prompt)
        return AUCTaskRecord(
            id: taskID ?? "task-resumed",
            prompt: prompt,
            status: .running,
            sessionID: sessionID,
            createdAt: Date()
        )
    }

    func getTask(id: String) async throws -> AUCTaskRecord? { nil }
    func listTasks() async throws -> [AUCTaskRecord] { [] }
    func deleteTask(id: String) async throws {}
    func respondToPermission(
        requestID: String,
        taskID: String,
        allowed: Bool,
        selectedOptions: [String]?,
        customText: String?
    ) async throws {
        permissionResponses.append(
            PermissionResponse(
                requestID: requestID,
                taskID: taskID,
                allowed: allowed,
                selectedOptions: selectedOptions,
                customText: customText
            )
        )
    }
    func getProviderSettings() async throws -> AUCProviderSettings { providerSettings }
    func getOpenAIBaseURL() async throws -> String { openAIBaseURL }
    func saveOpenAIAPIKey(apiKey: String, baseURL: String?, modelID: String) async throws {
        savedOpenAIKeys.append(apiKey)
        savedBaseURLs.append(baseURL)
        openAIBaseURL = baseURL ?? ""
        providerSettings = AUCProviderSettings(
            hasReadyProvider: true,
            selectedModel: AUCModelSelection(provider: "openai", model: modelID),
            openAIKeyPrefix: String(apiKey.prefix(8))
        )
    }
    func setSelectedModel(_ model: AUCModelSelection) async throws {}
    func getTodos(taskID: String) async throws -> [String] { [] }

    func subscribeToTaskEvents(taskID: String) async throws -> AsyncThrowingStream<AUCTaskEvent, any Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
