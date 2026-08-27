import AppKit
import Observation

/// Live view of the system accessibility switches the panel must honor.
/// `NSGlassEffectView` has no opacity control, so Reduce Transparency swaps
/// the panel to an opaque card. Custom overlays and springs still need this
/// live read — the user should not have to relaunch for a change to take effect.
@MainActor
@Observable
final class AccessibilityPreferences {
    static let shared = AccessibilityPreferences()

    private(set) var reduceTransparency = false
    private(set) var reduceMotion = false

    private init() {
        refresh()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let workspace = NSWorkspace.shared
        reduceTransparency = workspace.accessibilityDisplayShouldReduceTransparency
        reduceMotion = workspace.accessibilityDisplayShouldReduceMotion
    }
}
