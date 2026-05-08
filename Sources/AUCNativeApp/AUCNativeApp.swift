import AUCNativeCore
import SwiftUI
import OSLog
#if canImport(AppKit)
import AppKit
#endif

@main
struct AUCNativeApp: App {
    private static let logger = Logger(subsystem: "ai.auc.native", category: "bootstrap")
    @State private var appModel = AUCAppModel()
    @State private var processManager = ExecutorProcessManager()
    @State private var launcherPanel = LauncherPanelController()
    @State private var launcherHotKey = LauncherHotKeyController()
    @State private var didBootstrap = false
    @State private var didInstallLauncherHotKey = false
    @State private var didApplyDemoConfig = false
    private let demoConfig = AUCDemoReleaseConfig.load()

    init() {
        AUCDesign.FontToken.registerBundleFonts()
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(model: appModel)
                .frame(minWidth: 1100, minHeight: 720)
                .onAppear {
                    Self.logger.info("Main window appeared; scheduling bootstrap")
                    #if canImport(AppKit)
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    #endif
                    applyDemoConfigOnce()
                    installLauncherHotKeyOnce()
                    installRepairHandlerOnce()
                    Task {
                        await bootstrapOnce()
                    }
                }
                .onChange(of: appModel.isLauncherPresented) { _, isPresented in
                    if isPresented {
                        launcherPanel.show(model: appModel)
                    } else {
                        launcherPanel.hide()
                    }
                }
                .task {
                    await bootstrapOnce()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Launcher") {
                    launcherPanel.toggle(model: appModel)
                }
                .keyboardShortcut("b", modifiers: [.option])

                Button("Open Full App") {
                    #if canImport(AppKit)
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first(where: { !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
                    #endif
                }

                Button("Settings") {
                    appModel.isSettingsPresented = true
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        MenuBarExtra("AUC", systemImage: "sparkle.magnifyingglass") {
            Button("Open Launcher") {
                launcherPanel.toggle(model: appModel)
            }
            Button("Open Full App") {
                #if canImport(AppKit)
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first(where: { !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
                #endif
            }
            Button("Settings") {
                appModel.isSettingsPresented = true
            }
            Button("Run Onboarding") {
                appModel.openOnboarding()
            }
            Divider()
            Button("Reconnect Executor") {
                Task { await bootstrap(force: true) }
            }
            Divider()
            Button("Quit AUC") {
                #if canImport(AppKit)
                NSApp.terminate(nil)
                #endif
            }
        }
    }

    @MainActor
    private func applyDemoConfigOnce() {
        guard !didApplyDemoConfig else { return }
        didApplyDemoConfig = true
        guard demoConfig.isOpenAIDemo else { return }
        appModel.configureOpenAIDemoMode(
            seededKeyAvailable: demoConfig.seededOpenAIAPIKey != nil,
            releaseVersion: demoConfig.releaseVersion ?? "openai-demo"
        )
    }

    @MainActor
    private func installRepairHandlerOnce() {
        appModel.executorRepairHandler = {
            await bootstrap(force: true)
        }
    }

    @MainActor
    private func installLauncherHotKeyOnce() {
        guard !didInstallLauncherHotKey else { return }
        didInstallLauncherHotKey = true
        launcherHotKey.install {
            launcherPanel.toggle(model: appModel)
        }
    }

    @MainActor
    private func bootstrapOnce() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        Self.logger.info("Bootstrap once started")
        applyDemoConfigOnce()
        _ = await bootstrap(force: false)
    }

    @MainActor
    @discardableResult
    private func bootstrap(force: Bool) async -> Bool {
        guard !activateExistingInstanceIfNeeded() else { return false }
        let paths = ExecutorProcessManager.defaultPaths()
        Self.logger.info("Bootstrap force=\(force) daemonEntry=\(paths.daemonEntry?.path ?? "nil", privacy: .public) node=\(paths.nodeBinary?.path ?? "nil", privacy: .public)")
        let installStatus = AUCInstallLocationGuard.evaluate(
            appPath: Bundle.main.bundlePath,
            isOpenAIDemoMode: demoConfig.isOpenAIDemo
        )
        if installStatus.isBlocked {
            appModel.blockInstallLocation(installStatus)
            updateDiagnostics(paths: paths, installStatus: installStatus)
            return false
        }
        appModel.executorPhase = force ? .repairing : .starting
        if force {
            await processManager.cleanupStaleRuntimeFiles(paths: paths)
        }
        do {
            try await processManager.ensureRunning(paths: paths)
            Self.logger.info("ensureRunning completed")
            let socketPath = ExecutorProcessManager.socketPath(for: paths.dataDir)
            let connected = await connectWithRetry(socketPath: socketPath)
            guard connected else {
                let logError = ExecutorProcessManager.latestDaemonLogError(in: paths.dataDir)
                appModel.executorPhase = logError != nil ? .crashed : .failed
                appModel.isExecutorConnected = false
                appModel.errorMessage = logError.map { "The bundled executor crashed before it became ready: \($0)." } ??
                    "The bundled executor did not become ready in time. Try Repair executor."
                updateDiagnostics(paths: paths, installStatus: installStatus)
                return false
            }
            await appModel.applySeededDemoKeyIfNeeded(demoConfig.seededOpenAIAPIKey)
            updateDiagnostics(paths: paths, installStatus: installStatus)
            Self.logger.info("Bootstrap finished connected=\(appModel.isExecutorConnected)")
            return appModel.isExecutorConnected
        } catch {
            Self.logger.error("Bootstrap failed: \(error.localizedDescription, privacy: .public)")
            appModel.isExecutorConnected = false
            if case ExecutorProcessError.runtimePreflightFailed = error {
                appModel.executorPhase = .crashed
            } else {
                appModel.executorPhase = .failed
            }
            appModel.errorMessage = error.localizedDescription
            updateDiagnostics(paths: paths, installStatus: installStatus)
            return false
        }
    }

    @MainActor
    private func connectWithRetry(socketPath: String) async -> Bool {
        for _ in 0..<60 {
            let transport = UnixSocketTransport(socketPath: socketPath)
            let eventTransport = UnixSocketTransport(socketPath: socketPath)
            appModel.configure(
                executor: ExecutorClient(transport: transport),
                eventSource: DaemonEventSource(transport: eventTransport)
            )
            await appModel.connect()
            if appModel.isExecutorConnected {
                await appModel.applySeededDemoKeyIfNeeded(demoConfig.seededOpenAIAPIKey)
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return false
    }

    @MainActor
    private func updateDiagnostics(paths: ExecutorPaths, installStatus: AUCInstallLocationStatus) {
        let diagnostics = ExecutorProcessManager.diagnostics(
            paths: paths,
            appPath: Bundle.main.bundlePath,
            installStatus: installStatus,
            isConnected: appModel.isExecutorConnected,
            executorPhase: appModel.executorPhase,
            providerReady: appModel.providerSettings.hasReadyProvider,
            lastError: appModel.errorMessage
        )
        appModel.updateExecutorDiagnostics(diagnostics)
    }

    @MainActor
    private func activateExistingInstanceIfNeeded() -> Bool {
        #if canImport(AppKit)
        guard demoConfig.isOpenAIDemo else { return false }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let existing = NSRunningApplication
            .runningApplications(withBundleIdentifier: "ai.auc.native")
            .first { $0.processIdentifier != currentPID }
        guard let existing else { return false }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.terminate(nil)
        return true
        #else
        return false
        #endif
    }
}
