import AUCNativeCore
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AUCAppModel
    @State private var openAIKey = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: AUCDesign.Space.lg) {
                header
                providerPanel
                daemonStatus
                Spacer(minLength: 0)
            }
            .padding(.top, AUCDesign.Space.md)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconCircleButtonStyle())
            .help("Close")
        }
        .padding(AUCDesign.Space.xl)
        .background(AUCDesign.ColorToken.appBackground)
        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
            Text("Settings")
                .font(AUCDesign.FontToken.sans(size: 28, weight: .semibold))
            Text("Add your OpenAI API key to run tasks.")
                .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
        }
    }

    private var providerPanel: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.lg) {
            HStack(alignment: .top, spacing: AUCDesign.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                        .fill(AUCDesign.ColorToken.n900)
                        .frame(width: 48, height: 48)
                    Text("AI")
                        .font(AUCDesign.FontToken.sans(size: 16, weight: .bold))
                        .foregroundStyle(AUCDesign.ColorToken.void)
                }

                VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                    Text("OpenAI")
                        .font(AUCDesign.FontToken.sans(size: 22, weight: .semibold))
                    Text(providerStatusText)
                        .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
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
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                SecureField(model.providerSettings.openAIKeyPrefix ?? "sk-...", text: $openAIKey)
                    .textFieldStyle(.plain)
                    .font(AUCDesign.FontToken.sans(size: 15, weight: .medium))
                    .padding(.horizontal, AUCDesign.Space.md)
                    .padding(.vertical, 13)
                    .background(AUCDesign.ColorToken.panel)
                    .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                            .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
                    }
            }

            if let message = model.settingsMessage {
                Text(message)
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                    .foregroundStyle(message.localizedCaseInsensitiveContains("saved") ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber)
                    .textSelection(.enabled)
            }

            HStack(spacing: AUCDesign.Space.sm) {
                Button {
                    Task {
                        await model.saveOpenAIAPIKey(openAIKey, baseURL: model.openAIBaseURL)
                        if model.settingsMessage?.localizedCaseInsensitiveContains("saved") == true {
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
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(AUCDesign.Space.lg)
        .aucPanel(cornerRadius: AUCDesign.Radius.lg)
    }

    private var daemonStatus: some View {
        HStack(spacing: AUCDesign.Space.md) {
            Image(systemName: model.isExecutorConnected ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
                .foregroundStyle(model.isExecutorConnected ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                Text("Executor")
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                Text(model.isExecutorConnected ? "Ready" : (model.errorMessage ?? "Needs repair"))
                    .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(AUCDesign.Space.lg)
        .aucPanel()
    }

    private var providerStatusText: String {
        if model.providerSettings.activeProviderID == "openai", let prefix = model.providerSettings.openAIKeyPrefix {
            return "Connected with \(prefix)"
        }
        if model.providerSettings.hasReadyProvider {
            return "OpenAI is ready"
        }
        return "Not configured"
    }

    private func openAPIKeysPage() {
        #if canImport(AppKit)
        NSWorkspace.shared.open(URL(string: "https://platform.openai.com/api-keys")!)
        #endif
    }
}
