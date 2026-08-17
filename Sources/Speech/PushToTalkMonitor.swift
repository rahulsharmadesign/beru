import AppKit
import KeyboardShortcuts

/// Escape while the panel is open: stop dictation if it is running, otherwise
/// dismiss. The dictate shortcut itself is a global hotkey in AppCoordinator
/// so it can open the panel from anywhere.
@MainActor
final class PushToTalkMonitor {
    private var isArmed = false
    private var monitor: Any?

    private let onRelease: () -> Void
    private let onEscape: () -> Void

    init(
        fieldHasText _: @escaping () -> Bool = { false },
        onPress _: @escaping () -> Void = {},
        onRelease: @escaping () -> Void,
        onEscape: @escaping () -> Void = {}
    ) {
        self.onRelease = onRelease
        self.onEscape = onEscape
    }

    func arm() {
        isArmed = true
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func disarm() {
        isArmed = false
        if DictationService.shared.isRecording {
            onRelease()
        }
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isArmed, event.type == .keyDown, event.keyCode == 53 else {
            return event
        }
        if DictationService.shared.isRecording {
            onRelease()
        } else {
            onEscape()
        }
        return nil
    }

    /// Whether a press of the dictate key should start listening rather than
    /// being typed into the field.
    ///
    /// A bare character (historically Space) is also an ordinary key in
    /// "Describe your change". Swallowing it unconditionally would make the
    /// instruction field unable to type that character — so an unmodified key
    /// only dictates while the field is empty. Any shortcut carrying a modifier
    /// is unambiguous and always dictates.
    nonisolated static func shouldStartDictation(
        hasText: Bool,
        shortcut: KeyboardShortcuts.Shortcut
    ) -> Bool {
        if !shortcut.modifiers.isEmpty { return true }
        return !hasText
    }
}
