import AUCNativeCore
import SwiftUI

#if canImport(AppKit)
import AppKit

@MainActor
final class LauncherPanelController {
    private var panel: AUCLauncherPanel?
    private var hostingController: NSHostingController<MacLauncherPanelView>?
    private var keyDownMonitor: Any?

    func toggle(model: AUCAppModel) {
        if panel?.isVisible == true {
            model.isLauncherPresented = false
            hide()
        } else {
            model.isLauncherPresented = true
            show(model: model)
        }
    }

    func show(model: AUCAppModel) {
        let panel = ensurePanel(model: model)
        updateRootView(model: model)
        model.isLauncherCollapsed = false
        resize(for: model, collapsed: false)
        installKeyDownMonitor(model: model)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        removeKeyDownMonitor()
    }

    private func ensurePanel(model: AUCAppModel) -> AUCLauncherPanel {
        if let panel {
            return panel
        }

        let panel = AUCLauncherPanel(
            contentRect: NSRect(
                origin: .zero,
                size: CGSize(width: AUCDesign.Space.launcherIdleWidth, height: AUCDesign.Space.launcherIdleHeight)
            ),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let hostingController = NSHostingController(rootView: makeRootView(model: model))
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hostingController

        self.panel = panel
        self.hostingController = hostingController
        return panel
    }

    private func updateRootView(model: AUCAppModel) {
        hostingController?.rootView = makeRootView(model: model)
    }

    private func makeRootView(model: AUCAppModel) -> MacLauncherPanelView {
        MacLauncherPanelView(
            model: model,
            close: { [weak self, weak model] in
                model?.isLauncherPresented = false
                self?.hide()
            },
            openDashboard: { [weak self, weak model] task in
                if let task {
                    model?.selectTask(task)
                }
                model?.isLauncherPresented = false
                self?.hide()
                AUCWindowPresenter.openDashboard()
            },
            resize: { [weak self, weak model] collapsed in
                guard let model else { return }
                self?.resize(for: model, collapsed: collapsed)
            }
        )
    }

    private func resize(for model: AUCAppModel, collapsed: Bool) {
        guard let panel else { return }
        let size = size(for: model, collapsed: collapsed)
        let frame = positionedFrame(size: size)
        panel.setFrame(frame, display: true, animate: panel.isVisible)
    }

    private func size(for model: AUCAppModel, collapsed: Bool) -> CGSize {
        if collapsed, model.isBusy, model.activeTask == nil {
            return CGSize(width: AUCDesign.Space.launcherMiniWidth, height: AUCDesign.Space.launcherMiniHeight)
        }
        if collapsed, model.activeTask != nil {
            return CGSize(width: AUCDesign.Space.launcherMiniWidth, height: AUCDesign.Space.launcherMiniHeight)
        }
        guard let task = model.activeTask else {
            return CGSize(width: AUCDesign.Space.launcherIdleWidth, height: AUCDesign.Space.launcherIdleHeight)
        }
        if model.permissionRequest?.taskID == task.id {
            return CGSize(width: AUCDesign.Space.launcherExpandedWidth, height: AUCDesign.Space.launcherPermissionHeight)
        }
        if task.status == .completed {
            return CGSize(width: AUCDesign.Space.launcherExpandedWidth, height: AUCDesign.Space.launcherDoneHeight)
        }
        return CGSize(width: AUCDesign.Space.launcherExpandedWidth, height: AUCDesign.Space.launcherExpandedHeight)
    }

    private func positionedFrame(size: CGSize) -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = screen.midX - size.width / 2
        let y = screen.midY - size.height / 2 - 18
        return NSRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private func installKeyDownMonitor(model: AUCAppModel) {
        removeKeyDownMonitor()
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak model] event in
            guard
                let self,
                let model,
                self.panel?.isKeyWindow == true,
                event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            else {
                return event
            }

            let isReturn = event.keyCode == 36 || event.keyCode == 76
            guard isReturn else { return event }

            Task { @MainActor [weak self, weak model] in
                guard let self, let model else { return }
                let prompt = model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !prompt.isEmpty, !model.isBusy else { return }
                model.isLauncherPresented = true
                model.isLauncherCollapsed = true
                self.resize(for: model, collapsed: true)
                await model.submitLauncherPrompt(keepLauncherOpen: true)
                model.isLauncherCollapsed = model.activeTask != nil
                self.resize(for: model, collapsed: model.isLauncherCollapsed)
            }
            return nil
        }
    }

    private func removeKeyDownMonitor() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
    }
}

private final class AUCLauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
#endif
