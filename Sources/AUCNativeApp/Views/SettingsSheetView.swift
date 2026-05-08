import AUCNativeCore
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct SettingsSheetView: View {
    @Bindable var model: AUCAppModel
    @State private var openAIKey = ""
    @State private var openAIBaseURL = ""
    @State private var selectedModelID = "openai/gpt-5.2"
    @State private var selectedTab: SettingsTab = .providers

    private let openAIModels = [
        "openai/gpt-5.2",
        "openai/gpt-5.2-codex",
        "openai/gpt-5.1-codex-max",
        "openai/gpt-5.1-codex-mini",
        "openai/gpt-5"
    ]

    var body: some View {
        Group {
            if model.isOpenAIDemoMode {
                openAIDemoBody
            } else {
                HStack(spacing: 0) {
                    sidebar

                    ScrollView {
                        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
                            tabContent
                        }
                        .padding(AUCDesign.Space.lg)
                    }
                    .background(AUCDesign.ColorToken.appBackground)
                }
            }
        }
        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
        .onAppear {
            openAIBaseURL = model.openAIBaseURL.isEmpty ? AUCAppModel.defaultOpenAIBaseURL : model.openAIBaseURL
            selectedModelID = model.isOpenAIDemoMode ? AUCAppModel.openAIDemoModelID : (model.providerSettings.selectedModel?.model ?? selectedModelID)
        }
    }

    private var openAIDemoBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
                HStack(alignment: .top, spacing: AUCDesign.Space.md) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(AUCDesign.FontToken.sans(size: 28, weight: .semibold))
                        .foregroundStyle(AUCDesign.ColorToken.violetLight)
                    VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                        Text("OpenAI Demo Setup")
                            .font(AUCDesign.FontToken.sans(size: 26, weight: .semibold))
                        Text("AUC starts from the launcher. Press Option+B after setup.")
                            .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                            .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    }
                    Spacer()
                    Chip(label: "Option+B", systemImage: "keyboard")
                }
                .padding(.bottom, AUCDesign.Space.sm)

                providerPanel
                generalPanel
                aboutPanel
            }
            .padding(AUCDesign.Space.lg)
        }
        .background(AUCDesign.ColorToken.appBackground)
    }

    private var standardBody: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
                    tabContent
                }
                .padding(AUCDesign.Space.lg)
            }
            .background(AUCDesign.ColorToken.appBackground)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            Text("Settings")
                .font(AUCDesign.FontToken.sans(size: 24, weight: .semibold))
            Text("Providers, daemon health, permissions, and diagnostics.")
                .font(AUCDesign.FontToken.sans(size: 13))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)

            Divider()
                .overlay(AUCDesign.ColorToken.stroke)

            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: AUCDesign.Space.sm) {
                        Image(systemName: tab.systemImage)
                            .frame(width: 18)
                        Text(tab.title)
                        Spacer()
                    }
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                    .padding(.horizontal, AUCDesign.Space.sm)
                    .padding(.vertical, 9)
                    .background(selectedTab == tab ? AUCDesign.ColorToken.violet.opacity(0.18) : Color.clear)
                    .foregroundStyle(selectedTab == tab ? AUCDesign.ColorToken.violetLight : AUCDesign.ColorToken.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(width: 220, alignment: .topLeading)
        .padding(AUCDesign.Space.lg)
        .background(AUCDesign.ColorToken.sidebar)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .providers:
            providerPanel
            settingsRow(
                title: "Selected model",
                value: model.providerSettings.selectedModel?.model ?? "Not configured",
                systemImage: "cpu",
                tint: AUCDesign.ColorToken.violet
            )
        case .skills:
            parityPanel(
                title: "Skills",
                subtitle: "Bundled and user-installed skills will appear here once the Swift client wires skills.list, skills.setEnabled, skills.addFromPath, and skills.resync.",
                systemImage: "wand.and.stars",
                rows: ["Bundled skills: staged in app bundle", "Enable/disable: daemon route available", "Add from folder: needs native folder picker wiring"]
            )
        case .browsers:
            parityPanel(
                title: "Browsers",
                subtitle: "Browser runtime state is now received through browser.frame notifications; browser selection and repair controls are the next daemon-backed slice.",
                systemImage: "safari",
                rows: ["Live preview events: connected", "Default browser: pending route", "Repair browser runtime: pending route"]
            )
        case .workspaces:
            parityPanel(
                title: "Workspaces",
                subtitle: "Workspace switching needs the same daemon workspace routes Electron uses, plus native folder picking.",
                systemImage: "folder",
                rows: ["Current folder chip: composer supported", "Workspace list: pending route", "Add workspace: native picker needed"]
            )
        case .integrations:
            parityPanel(
                title: "Integrations",
                subtitle: "Native macOS communication actions are now exposed to the executor. Connector login/logout controls still need the full Electron settings port.",
                systemImage: "point.3.connected.trianglepath.dotted",
                rows: [
                    "Apple Mail: draft/send actions available",
                    "iMessage: draft/send actions available",
                    "WhatsApp: daemon MCP available when connected",
                    "Google Gmail: available after Google account auth is ported"
                ]
            )
        case .scheduler:
            parityPanel(
                title: "Scheduler",
                subtitle: "Scheduled tasks stay daemon-owned. Native controls need the Electron scheduler route map before enabling edits.",
                systemImage: "calendar.badge.clock",
                rows: ["Scheduled task source: supported by daemon", "Schedule list: pending route", "Create/edit schedule: pending UI"]
            )
        case .voice:
            parityPanel(
                title: "Voice",
                subtitle: "The composer keeps the speech slot visible; native voice input/settings are not wired yet.",
                systemImage: "waveform",
                rows: ["Composer mic slot: visible", "Voice provider settings: pending route", "Transcription runtime: pending native wiring"]
            )
        case .general:
            generalPanel
        case .about:
            aboutPanel
        }
    }

    private var providerPanel: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(alignment: .top, spacing: AUCDesign.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                        .fill(AUCDesign.ColorToken.n900)
                        .frame(width: 42, height: 42)
                    Text("AI")
                        .font(AUCDesign.FontToken.sans(size: 14, weight: .bold))
                        .foregroundStyle(AUCDesign.ColorToken.void)
                }

                VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                    Text("OpenAI")
                        .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
                    Text(providerStatusText)
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(model.providerSettings.hasReadyProvider ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.textSecondary)
                }

                Spacer()

                Button {
                    openAPIKeysPage()
                } label: {
                    Label("Find API key", systemImage: "arrow.up.right")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                Text("API key")
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                SecureField(model.providerSettings.openAIKeyPrefix ?? "sk-...", text: $openAIKey)
                    .textFieldStyle(.plain)
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .padding(.horizontal, AUCDesign.Space.md)
                    .padding(.vertical, 11)
                    .background(AUCDesign.ColorToken.panel)
                    .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                            .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                Text("Model")
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                if model.isOpenAIDemoMode {
                    settingsInlineValue(
                        value: AUCAppModel.openAIDemoModelID,
                        systemImage: "lock.fill",
                        tint: AUCDesign.ColorToken.violetLight
                    )
                } else {
                    Picker("Model", selection: $selectedModelID) {
                        ForEach(openAIModels, id: \.self) { modelID in
                            Text(displayName(for: modelID)).tag(modelID)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if model.isOpenAIDemoMode {
                settingsInlineValue(
                    value: model.isDemoKeyActive ? "Demo key active · $5 budget" : "Manual or seeded demo key",
                    systemImage: model.isDemoKeyActive ? "checkmark.seal.fill" : "key.fill",
                    tint: model.isDemoKeyActive ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber
                )
            } else {
                VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                    Text("Base URL")
                        .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                    TextField("https://api.openai.com/v1", text: $openAIBaseURL)
                        .textFieldStyle(.plain)
                        .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                        .padding(.horizontal, AUCDesign.Space.md)
                        .padding(.vertical, 11)
                        .background(AUCDesign.ColorToken.panel)
                        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                                .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
                        }
                    }
            }

            if let message = model.settingsMessage {
                Text(message)
                    .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                    .foregroundStyle(message.contains("saved") ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber)
                    .textSelection(.enabled)
            }

            HStack(spacing: AUCDesign.Space.sm) {
                Button {
                    Task {
                        await model.saveOpenAIAPIKey(
                            openAIKey,
                            baseURL: model.isOpenAIDemoMode ? AUCAppModel.defaultOpenAIBaseURL : openAIBaseURL,
                            modelID: model.isOpenAIDemoMode ? AUCAppModel.openAIDemoModelID : selectedModelID
                        )
                        if model.settingsMessage?.contains("saved") == true {
                            openAIKey = ""
                        }
                    }
                } label: {
                    if model.isSavingProviderSettings {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Save OpenAI key", systemImage: "checkmark.seal.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.isSavingProviderSettings || openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    Task { await model.connect() }
                } label: {
                    Label("Refresh status", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(AUCDesign.Space.lg)
        .aucPanel(cornerRadius: AUCDesign.Radius.lg)
    }

    private var diagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
            Text("Diagnostics")
                .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
            Text(model.errorMessage ?? "No current daemon errors.")
                .font(AUCDesign.FontToken.sans(size: 12))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                .textSelection(.enabled)
        }
        .padding(AUCDesign.Space.lg)
        .aucPanel()
    }

    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            settingsRow(
                title: "Daemon",
                value: model.isExecutorConnected ? "Connected" : "Repair needed",
                systemImage: model.isExecutorConnected ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tint: model.isExecutorConnected ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber
            )
            settingsRow(
                title: "Launcher shortcut",
                value: "Option-B from native shell",
                systemImage: "keyboard",
                tint: AUCDesign.ColorToken.violetLight
            )
            diagnosticsPanel
        }
    }

    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(spacing: AUCDesign.Space.md) {
                Image(systemName: "sparkles")
                    .font(AUCDesign.FontToken.sans(size: 26, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.violetLight)
                VStack(alignment: .leading, spacing: 4) {
                    Text("auc native")
                        .font(AUCDesign.FontToken.sans(size: 24, weight: .semibold))
                    Text("Native SwiftUI shell over the proven AUC daemon.")
                        .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                }
                Spacer()
            }
            settingsRow(title: "Runtime", value: "Bundled Node daemon", systemImage: "terminal", tint: AUCDesign.ColorToken.cyan)
            settingsRow(title: "UI", value: "SwiftUI/AppKit", systemImage: "macwindow", tint: AUCDesign.ColorToken.violet)
            diagnosticsPanel
        }
    }

    private func parityPanel(title: String, subtitle: String, systemImage: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(spacing: AUCDesign.Space.md) {
                Image(systemName: systemImage)
                    .font(AUCDesign.FontToken.sans(size: 22, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.violetLight)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AUCDesign.FontToken.sans(size: 22, weight: .semibold))
                    Text(subtitle)
                        .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            ForEach(rows, id: \.self) { row in
                HStack(spacing: AUCDesign.Space.sm) {
                    Image(systemName: row.localizedCaseInsensitiveContains("pending") ? "clock" : "checkmark.circle.fill")
                        .foregroundStyle(row.localizedCaseInsensitiveContains("pending") ? AUCDesign.ColorToken.amber : AUCDesign.ColorToken.green)
                    Text(row)
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(AUCDesign.Space.sm)
                .background(AUCDesign.ColorToken.panel)
                .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
            }
        }
        .padding(AUCDesign.Space.lg)
        .aucPanel(cornerRadius: AUCDesign.Radius.lg)
    }

    private var providerStatusText: String {
        if model.isDemoKeyActive {
            return "Demo key active · $5 budget"
        }
        if model.providerSettings.activeProviderID == "openai", let prefix = model.providerSettings.openAIKeyPrefix {
            return "Connected with \(prefix)"
        }
        if model.providerSettings.hasReadyProvider {
            return "Provider ready"
        }
        return "Add an OpenAI API key to run tasks"
    }

    private func settingsInlineValue(value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: AUCDesign.Space.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(value)
                .font(AUCDesign.FontToken.sans(size: 12, weight: .semibold))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(AUCDesign.Space.sm)
        .background(AUCDesign.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
    }

    private func settingsRow(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: AUCDesign.Space.md) {
            Image(systemName: systemImage)
                .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                Text(title)
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                Text(value)
                    .font(AUCDesign.FontToken.sans(size: 12))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
            }
            Spacer()
        }
        .padding(AUCDesign.Space.lg)
        .aucPanel()
    }

    private func displayName(for modelID: String) -> String {
        modelID
            .replacingOccurrences(of: "openai/", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func openAPIKeysPage() {
        #if canImport(AppKit)
        NSWorkspace.shared.open(URL(string: "https://platform.openai.com/api-keys")!)
        #endif
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case providers
    case skills
    case browsers
    case workspaces
    case integrations
    case scheduler
    case voice
    case general
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .providers: "Providers"
        case .skills: "Skills"
        case .browsers: "Browsers"
        case .workspaces: "Workspaces"
        case .integrations: "Integrations"
        case .scheduler: "Scheduler"
        case .voice: "Voice"
        case .general: "General"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .providers: "key.horizontal"
        case .skills: "wand.and.stars"
        case .browsers: "safari"
        case .workspaces: "folder"
        case .integrations: "point.3.connected.trianglepath.dotted"
        case .scheduler: "calendar.badge.clock"
        case .voice: "waveform"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}
