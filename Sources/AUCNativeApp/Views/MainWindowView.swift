import AUCNativeCore
import SwiftUI

struct MainWindowView: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = Self.sidebarWidth(for: geometry.size.width)
            let activePanelWidth = Self.activePanelWidth(for: geometry.size.width)

            ZStack {
                AUCDesign.ColorToken.appBackground.ignoresSafeArea()

                HStack(spacing: 0) {
                    SidebarView(model: model)
                        .frame(width: sidebarWidth)

                    CommandCenterView(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if activePanelWidth > 0 {
                        ActiveTaskView(model: model)
                            .frame(width: activePanelWidth)
                    }
                }
            }
        }
        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
        .font(AUCDesign.FontToken.sans(size: 14))
        .sheet(isPresented: $model.isSettingsPresented) {
            SettingsSheetView(model: model)
                .frame(width: AUCDesign.Space.settingsSheetWidth, height: AUCDesign.Space.settingsSheetHeight)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private static func sidebarWidth(for windowWidth: CGFloat) -> CGFloat {
        windowWidth < 980 ? 220 : AUCDesign.Space.sidebarWidth
    }

    private static func activePanelWidth(for windowWidth: CGFloat) -> CGFloat {
        windowWidth >= 1360 ? AUCDesign.Space.activePanelWidth : 0
    }
}
