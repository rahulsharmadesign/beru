import AppKit
import Observation

/// Live view of the system accessibility switches the panel must honor.
/// NSVisualEffectView adapts to reduce-transparency on its own, but the custom
/// glass, rim lighting, and spring animations do not — and the user should not
/// have to relaunch for a change to take effect.
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
