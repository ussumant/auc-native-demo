import AUCNativeCore
import SwiftUI

struct MainWindowView: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        ZStack {
            AUCDesign.ColorToken.appBackground.ignoresSafeArea()

            if model.executorPhase == .installBlocked {
                InstallLocationBlockedView(model: model)
            } else {
                HStack(spacing: 0) {
                    SidebarView(model: model)
                        .frame(width: AUCDesign.Space.sidebarWidth)

                    CommandCenterView(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ActiveTaskView(model: model)
                        .frame(width: AUCDesign.Space.activePanelWidth)
                }

                VStack {
                    Spacer()
                    LauncherPill(model: model)
                        .padding(.bottom, AUCDesign.Space.lg)
                }
                .padding(.leading, AUCDesign.Space.sidebarWidth)
                .padding(.trailing, AUCDesign.Space.activePanelWidth)
            }
        }
        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
        .font(AUCDesign.FontToken.sans(size: 14))
        .sheet(isPresented: $model.isSettingsPresented) {
            SettingsSheetView(model: model)
                .frame(width: AUCDesign.Space.settingsSheetWidth, height: AUCDesign.Space.settingsSheetHeight)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $model.isOnboardingPresented) {
            AUCOnboardingView(model: model)
                .frame(width: 430, height: 620)
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

private struct InstallLocationBlockedView: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        VStack(spacing: AUCDesign.Space.lg) {
            Image(systemName: "arrow.down.app.fill")
                .font(AUCDesign.FontToken.sans(size: 48, weight: .semibold))
                .foregroundStyle(AUCDesign.ColorToken.violetLight)

            VStack(spacing: AUCDesign.Space.sm) {
                Text("Move AUC Native to Applications")
                    .font(AUCDesign.FontToken.sans(size: 30, weight: .semibold))
                Text("For the demo build, AUC starts its executor only after the app is copied into Applications.")
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                installStep(number: "1", text: "Drag AUC Native from the DMG into Applications.")
                installStep(number: "2", text: "Eject the DMG.")
                installStep(number: "3", text: "Open AUC Native from Applications, then press Option+B.")
            }
            .padding(AUCDesign.Space.lg)
            .aucPanel(cornerRadius: AUCDesign.Radius.lg)
            .frame(maxWidth: 560)

            HStack(spacing: AUCDesign.Space.sm) {
                Button {
                    #if canImport(AppKit)
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
                    #endif
                } label: {
                    Label("Open Applications", systemImage: "folder")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    #if canImport(AppKit)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.executorDiagnostics.copyText, forType: .string)
                    #endif
                } label: {
                    Label("Copy diagnostics", systemImage: "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AUCDesign.Space.xl)
        .background(AUCDesign.ColorToken.background)
    }

    private func installStep(number: String, text: String) -> some View {
        HStack(spacing: AUCDesign.Space.sm) {
            Text(number)
                .font(AUCDesign.FontToken.sans(size: 12, weight: .bold))
                .frame(width: 24, height: 24)
                .background(AUCDesign.ColorToken.violet.opacity(0.22))
                .foregroundStyle(AUCDesign.ColorToken.violetLight)
                .clipShape(Circle())
            Text(text)
                .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textPrimary)
        }
    }
}

private struct LauncherPill: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        Button {
            model.isLauncherPresented = true
        } label: {
            HStack(spacing: AUCDesign.Space.sm) {
                if let task = model.activeTask {
                    StatusDot(status: task.status)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.displayTitle)
                            .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(task.currentAction ?? "Open task pill")
                            .font(AUCDesign.FontToken.sans(size: 11, weight: .medium))
                            .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launcher")
                            .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                            .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                        Text("Search tasks or start a new one")
                            .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                            .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    }
                    Spacer()
                    Text("⌘K")
                        .font(AUCDesign.FontToken.sans(size: 11, weight: .bold))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AUCDesign.ColorToken.panelStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("⌥B")
                        .font(AUCDesign.FontToken.sans(size: 11, weight: .bold))
                        .foregroundStyle(AUCDesign.ColorToken.violetLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AUCDesign.ColorToken.violet.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Image(systemName: "plus")
                        .font(AUCDesign.FontToken.sans(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(AUCDesign.ColorToken.violet)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }
            .frame(width: model.activeTask == nil ? AUCDesign.Space.launcherPillWidth : AUCDesign.Space.launcherPillActiveWidth)
            .padding(.leading, AUCDesign.Space.md)
            .padding(.trailing, model.activeTask == nil ? AUCDesign.Space.xs : AUCDesign.Space.md)
            .padding(.vertical, model.activeTask == nil ? 9 : 12)
            .background(AUCDesign.ColorToken.void.opacity(0.98))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AUCDesign.ColorToken.strokeStrong, lineWidth: 1)
            }
            .aucShadow(AUCDesign.Shadow.aucGlow)
        }
        .buttonStyle(.plain)
    }
}
