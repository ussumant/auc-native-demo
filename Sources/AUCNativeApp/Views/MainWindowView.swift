import AUCNativeCore
import SwiftUI

struct MainWindowView: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        ZStack {
            AUCDesign.ColorToken.appBackground.ignoresSafeArea()

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
