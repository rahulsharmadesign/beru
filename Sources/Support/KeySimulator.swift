import CoreGraphics

enum KeySimulator {
    private static let keyC: CGKeyCode = 0x08
    private static let keyV: CGKeyCode = 0x09

    /// Waits until the user has released the hotkey's physical modifiers.
    /// A simulated Cmd-C posted while Ctrl/Option are still held gets merged
    /// with the physical modifier state, so the host app receives
    /// Ctrl-Option-Cmd-C instead of Cmd-C and copies nothing.
    static func waitForModifierRelease(timeoutMS: Int = 500) async {
        let deadline = ContinuousClock.now + .milliseconds(timeoutMS)
        while ContinuousClock.now < deadline {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection([.maskControl, .maskAlternate, .maskShift]).isEmpty {
                return
            }
            try? await Task.sleep(for: .milliseconds(15))
        }
    }

    static func simulateCommandC() {
        simulate(keyCode: keyC)
    }

    static func simulateCommandV() {
        simulate(keyCode: keyV)
    }

    private static func simulate(keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
