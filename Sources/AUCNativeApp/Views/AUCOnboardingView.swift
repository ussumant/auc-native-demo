import AUCNativeCore
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

struct AUCOnboardingView: View {
    @Bindable var model: AUCAppModel
    @State private var step: OnboardingStep = .welcome
    @State private var manualOpenAIKey = ""
    #if canImport(AVFoundation)
    @State private var audioPlayer: AVAudioPlayer?
    #endif

    var body: some View {
        ZStack {
            AUCOnboardingBackground()

            switch step {
            case .welcome:
                welcome
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .openAI:
                openAISetup
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .permissions:
                permissions
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .launcher:
                launcherIntro
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
        .font(AUCDesign.FontToken.sans(size: 14))
        .onAppear(perform: playWelcomeSound)
    }

    private var welcome: some View {
        VStack(spacing: AUCDesign.Space.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AUCDesign.ColorToken.violet.opacity(0.22))
                    .frame(width: 132, height: 132)
                    .blur(radius: 18)
                Image(systemName: "sparkles")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.violetLight)
                    .shadow(color: AUCDesign.ColorToken.violet.opacity(0.7), radius: 22)
            }

            VStack(spacing: AUCDesign.Space.sm) {
                Text("AUC Native")
                    .font(AUCDesign.FontToken.sans(size: 34, weight: .semibold))
                Text("Run tasks from anywhere on your Mac.")
                    .font(AUCDesign.FontToken.sans(size: 16, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                advance(to: .openAI)
            } label: {
                Label("Get started", systemImage: "arrow.right")
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
        }
        .padding(AUCDesign.Space.xl)
    }

    private var openAISetup: some View {
        OnboardingCard(
            systemImage: "key.horizontal",
            title: "Connect OpenAI",
            description: "AUC uses OpenAI to understand your request and decide which Mac actions to run.",
            privacyNote: "The key is saved through the local daemon provider flow. The full key is never shown in the UI."
        ) {
            VStack(spacing: AUCDesign.Space.md) {
                statusRow(
                    title: openAIStatusTitle,
                    detail: openAIStatusDetail,
                    systemImage: model.providerSettings.hasReadyProvider ? "checkmark.seal.fill" : "key.fill",
                    tint: model.providerSettings.hasReadyProvider ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber
                )

                if !model.providerSettings.hasReadyProvider && !model.hasSeededDemoKey {
                    SecureField("Paste OpenAI API key", text: $manualOpenAIKey)
                        .textFieldStyle(.plain)
                        .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                        .padding(.horizontal, AUCDesign.Space.md)
                        .padding(.vertical, 12)
                        .background(AUCDesign.ColorToken.panel)
                        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                                .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
                        }
                }

                if let message = model.settingsMessage {
                    Text(message)
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(message.contains("active") || message.contains("saved") ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: AUCDesign.Space.sm) {
                    Button("Skip for now") {
                        advance(to: .permissions)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        if model.providerSettings.hasReadyProvider {
                            advance(to: .permissions)
                        } else if model.hasSeededDemoKey {
                            Task {
                                await model.connect()
                                advance(to: .permissions)
                            }
                        } else {
                            Task {
                                await model.saveOpenAIAPIKey(
                                    manualOpenAIKey,
                                    baseURL: AUCAppModel.defaultOpenAIBaseURL,
                                    modelID: AUCAppModel.openAIDemoModelID
                                )
                                if model.providerSettings.hasReadyProvider {
                                    advance(to: .permissions)
                                }
                            }
                        }
                    } label: {
                        if model.isSavingProviderSettings {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(model.providerSettings.hasReadyProvider ? "Continue" : "Save key")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.isSavingProviderSettings || (!model.providerSettings.hasReadyProvider && !model.hasSeededDemoKey && manualOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
    }

    private var permissions: some View {
        OnboardingCard(
            systemImage: "hand.raised.fill",
            title: "Enable Mac control",
            description: "AUC may need Accessibility, Automation, and file access when a task controls your Mac or works with local files.",
            privacyNote: "macOS will still ask before sensitive actions. You can approve only the actions you trust."
        ) {
            VStack(spacing: AUCDesign.Space.sm) {
                permissionRow(
                    title: "Accessibility",
                    detail: "Required for reliable UI control.",
                    actionTitle: "Open settings",
                    action: openAccessibilitySettings
                )
                permissionRow(
                    title: "Automation",
                    detail: "Mail, Messages, Finder, and other apps ask when first controlled.",
                    actionTitle: "Later",
                    action: {}
                )
                permissionRow(
                    title: "Files & Folders",
                    detail: "Useful for Downloads, Desktop, and Documents tasks.",
                    actionTitle: "Open settings",
                    action: model.openFileAccessSettings
                )

                HStack(spacing: AUCDesign.Space.sm) {
                    Button("Back") {
                        advance(to: .openAI)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Continue") {
                        advance(to: .launcher)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.top, AUCDesign.Space.sm)
            }
        }
    }

    private var launcherIntro: some View {
        OnboardingCard(
            systemImage: "sparkle.magnifyingglass",
            title: "Start with the launcher",
            description: "Press Option+B from anywhere, type a task, and press Enter. The full app is just for history, settings, and details.",
            privacyNote: model.isDemoKeyActive ? "Demo key active · $5 budget" : "Use /new-task when you want a fresh task instead of a follow-up."
        ) {
            VStack(spacing: AUCDesign.Space.lg) {
                HStack(spacing: AUCDesign.Space.sm) {
                    KeyCap("⌥")
                    Text("+")
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    KeyCap("B")
                }

                Button {
                    model.completeOnboarding(showLauncher: true)
                } label: {
                    Label("Open launcher", systemImage: "arrow.up.right.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var openAIStatusTitle: String {
        if model.isDemoKeyActive {
            return "Demo key active · $5 budget"
        }
        if model.providerSettings.hasReadyProvider {
            return "OpenAI connected"
        }
        if model.hasSeededDemoKey {
            return "Seeded demo key ready"
        }
        return "OpenAI key needed"
    }

    private var openAIStatusDetail: String {
        if model.providerSettings.hasReadyProvider {
            return "Fixed model: \(AUCAppModel.openAIDemoModelID)"
        }
        if model.hasSeededDemoKey {
            return "AUC will save the throwaway demo key locally before tasks run."
        }
        return "Paste a key to run tasks in this demo build."
    }

    private func statusRow(title: String, detail: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: AUCDesign.Space.md) {
            Image(systemName: systemImage)
                .font(AUCDesign.FontToken.sans(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                Text(detail)
                    .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(AUCDesign.Space.md)
        .background(AUCDesign.ColorToken.panel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
    }

    private func permissionRow(title: String, detail: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: AUCDesign.Space.md) {
            Image(systemName: "checkmark.circle")
                .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
                .foregroundStyle(AUCDesign.ColorToken.violetLight)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                Text(detail)
                    .font(AUCDesign.FontToken.sans(size: 11, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(actionTitle, action: action)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(AUCDesign.Space.md)
        .background(AUCDesign.ColorToken.panel.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
    }

    private func advance(to nextStep: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.32)) {
            step = nextStep
        }
    }

    private func openAccessibilitySettings() {
        #if canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    private func playWelcomeSound() {
        #if canImport(AVFoundation)
        guard audioPlayer == nil,
              let url = Bundle.main.url(forResource: "BoringNotch-boring", withExtension: "m4a") else {
            return
        }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.volume = 0.35
        audioPlayer?.play()
        #endif
    }
}

private enum OnboardingStep {
    case welcome
    case openAI
    case permissions
    case launcher
}

private struct OnboardingCard<Content: View>: View {
    let systemImage: String
    let title: String
    let description: String
    let privacyNote: String
    let content: Content

    init(
        systemImage: String,
        title: String,
        description: String,
        privacyNote: String,
        @ViewBuilder content: () -> Content
    ) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
        self.privacyNote = privacyNote
        self.content = content()
    }

    var body: some View {
        VStack(spacing: AUCDesign.Space.lg) {
            Spacer(minLength: 0)

            Image(systemName: systemImage)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(AUCDesign.ColorToken.violetLight)
                .shadow(color: AUCDesign.ColorToken.violet.opacity(0.55), radius: 18)

            VStack(spacing: AUCDesign.Space.sm) {
                Text(title)
                    .font(AUCDesign.FontToken.sans(size: 27, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text(description)
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: AUCDesign.Space.sm) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                Text(privacyNote)
                    .font(AUCDesign.FontToken.sans(size: 11, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AUCDesign.Space.md)

            content

            Spacer(minLength: 0)
        }
        .padding(AUCDesign.Space.xl)
    }
}

private struct KeyCap: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(AUCDesign.FontToken.sans(size: 28, weight: .bold))
            .frame(width: 76, height: 58)
            .background(AUCDesign.ColorToken.panel)
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                    .stroke(AUCDesign.ColorToken.strokeStrong, lineWidth: 1)
            }
    }
}

private struct AUCOnboardingBackground: View {
    var body: some View {
        ZStack {
            AUCDesign.ColorToken.void
            RadialGradient(
                colors: [
                    AUCDesign.ColorToken.violet.opacity(0.32),
                    AUCDesign.ColorToken.void.opacity(0.0)
                ],
                center: .top,
                startRadius: 20,
                endRadius: 280
            )
            AUCOnboardingSparkles()
                .opacity(0.62)
        }
        .ignoresSafeArea()
    }
}

private struct AUCOnboardingSparkles: View {
    private let points: [CGPoint] = [
        CGPoint(x: 0.18, y: 0.18),
        CGPoint(x: 0.74, y: 0.14),
        CGPoint(x: 0.86, y: 0.34),
        CGPoint(x: 0.20, y: 0.72),
        CGPoint(x: 0.62, y: 0.82),
        CGPoint(x: 0.42, y: 0.28)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.violetLight.opacity(0.8))
                    .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
            }
        }
    }
}
