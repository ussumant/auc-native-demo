import AUCNativeCore
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@main
struct AUCNativeApp: App {
    @State private var appModel = AUCAppModel()
    @State private var processManager = ExecutorProcessManager()
    @State private var launcherPanel = LauncherPanelController()
    @State private var launcherHotKey = LauncherHotKeyController()
    @State private var didBootstrap = false
    @State private var didInstallLauncherHotKey = false

    init() {
        AUCDesign.FontToken.registerBundleFonts()
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(model: appModel)
                .frame(minWidth: 1100, minHeight: 720)
                .onAppear {
                    #if canImport(AppKit)
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    #endif
                    installLauncherHotKeyOnce()
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
            Button("Settings") {
                appModel.isSettingsPresented = true
            }
            Divider()
            Button("Reconnect Executor") {
                Task { await bootstrap(force: true) }
            }
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
        await bootstrap(force: false)
    }

    @MainActor
    private func bootstrap(force: Bool) async {
        let paths = ExecutorProcessManager.defaultPaths()
        do {
            try await processManager.ensureRunning(paths: paths)
            let socketPath = ExecutorProcessManager.socketPath(for: paths.dataDir)
            await connectWithRetry(socketPath: socketPath)
        } catch {
            appModel.isExecutorConnected = false
            appModel.errorMessage = error.localizedDescription
            if force {
                await appModel.connect()
            } else if appModel.tasks.isEmpty {
                await appModel.connect()
            }
        }
    }

    @MainActor
    private func connectWithRetry(socketPath: String) async {
        for _ in 0..<20 {
            let transport = UnixSocketTransport(socketPath: socketPath)
            let eventTransport = UnixSocketTransport(socketPath: socketPath)
            appModel.configure(
                executor: ExecutorClient(transport: transport),
                eventSource: DaemonEventSource(transport: eventTransport)
            )
            await appModel.connect()
            if appModel.isExecutorConnected {
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}
