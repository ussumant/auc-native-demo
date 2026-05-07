import SwiftUI

#if canImport(AppKit)
import AppKit

enum AUCWindowPresenter {
    @MainActor
    static func openDashboard() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window = NSApp.windows.first(where: { window in
            !(window is NSPanel) && window.canBecomeMain
        }) else {
            return
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
#endif
