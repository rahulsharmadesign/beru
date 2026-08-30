import AppKit
import Observation

/// Live view of the system accessibility switches the panel must honor.
/// `NSGlassEffectView` has no opacity control, so Reduce Transparency swaps
/// the panel to an opaque card. Custom overlays and springs still need this
/// live read — the user should not have to relaunch for a change to take effect.
///
/// Also owns Accessibility (AX) trust, which the panel previously re-read on a
/// 1-second loop for as long as it was open. Polling keeps the process awake and
/// defeats App Nap; trust is observable instead:
///
/// - `com.apple.accessibility.api` posts on the distributed centre when the
///   system trust database changes. It carries no payload, so it is a hint to
///   re-read rather than a value.
/// - Granting trust happens in System Settings, so the user leaves and comes
///   back. `didBecomeActiveNotification` covers a missed or coalesced post.
///
/// Trust lives here rather than in its own observer so the process does not gain
/// another singleton for state that is already "system accessibility switches".
@MainActor
@Observable
final class AccessibilityPreferences {
    static let shared = AccessibilityPreferences()

    private(set) var reduceTransparency = false
    private(set) var reduceMotion = false
    private(set) var isAccessibilityTrusted = false

    /// Undocumented but long-standing notification name for AX trust changes.
    @ObservationIgnored
    private static let trustChangedName = Notification.Name("com.apple.accessibility.api")

    private init() {
        refresh()
        refreshTrust()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Self.trustChangedName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshTrust() }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshTrust() }
        }
    }

    private func refresh() {
        let workspace = NSWorkspace.shared
        reduceTransparency = workspace.accessibilityDisplayShouldReduceTransparency
        reduceMotion = workspace.accessibilityDisplayShouldReduceMotion
    }

    /// Re-reads AX trust. Publishes only on change so views do not invalidate on
    /// every app activation.
    func refreshTrust() {
        let current = Permissions.isAccessibilityTrusted()
        guard current != isAccessibilityTrusted else { return }
        isAccessibilityTrusted = current
    }
}
