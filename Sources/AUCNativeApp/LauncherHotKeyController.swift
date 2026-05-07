#if canImport(AppKit)
import AppKit
import Carbon.HIToolbox

@MainActor
final class LauncherHotKeyController {
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?

    nonisolated(unsafe) private static var action: (@MainActor () -> Void)?
    private static let signature: OSType = 0x41554342
    private static let hotKeyID = UInt32(1)

    func install(action: @escaping @MainActor () -> Void) {
        Self.action = action
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            nil,
            &handlerRef
        )

        let id = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_B),
            UInt32(optionKey),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    private static let eventHandler: EventHandlerUPP = { _, event, _ in
        guard let event else { return noErr }
        var id = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &id
        )
        guard status == noErr, id.signature == signature, id.id == hotKeyID else {
            return noErr
        }
        Task { @MainActor in
            action?()
        }
        return noErr
    }
}
#endif
