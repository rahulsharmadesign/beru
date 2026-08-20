import AppKit
import Observation
import SwiftUI

/// Menu-bar apps often miss SwiftUI's appearance invalidation. Reading
/// `signature` in a view body forces a redraw when macOS switches light/dark.
@MainActor
@Observable
final class AppearanceObserver {
    static let shared = AppearanceObserver()
    private(set) var signature: String
    private var distributed: NSObjectProtocol?

    private init() {
        signature = NSApp.effectiveAppearance.name.rawValue
        distributed = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        signature = NSApp.effectiveAppearance.name.rawValue
        let appearance = NSApp.effectiveAppearance
        for window in NSApp.windows {
            window.appearance = appearance
            (window as? FloatingPanel)?.syncAppearance(with: appearance)
        }
    }
}
