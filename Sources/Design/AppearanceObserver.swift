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
    private var accessibility: NSObjectProtocol?

    private init() {
        signature = Self.makeSignature()
        distributed = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        accessibility = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        signature = Self.makeSignature()
        let appearance = NSApp.effectiveAppearance
        for window in NSApp.windows {
            // Never pin the menu-bar windows: the bar keeps its own appearance
            // (wallpaper tint can disagree with the app), and stamping it here
            // froze the status-item label on the app's scheme — the "wrong
            // variant" the menu-bar icon used to show. Same class-name match
            // BeruApp uses to dismiss the extra.
            guard !window.className.contains("NSStatusBar") else { continue }
            window.appearance = appearance
            (window as? FloatingPanel)?.syncAppearance(with: appearance)
        }
    }

    /// Light/dark plus Increase Contrast / Reduce Transparency / Reduce Motion,
    /// so named `BeruColor` tokens re-resolve when Liquid Glass accessibility
    /// settings change without a relaunch.
    private static func makeSignature() -> String {
        let workspace = NSWorkspace.shared
        return [
            NSApp.effectiveAppearance.name.rawValue,
            workspace.accessibilityDisplayShouldIncreaseContrast ? "c" : "-",
            workspace.accessibilityDisplayShouldReduceTransparency ? "t" : "-",
            workspace.accessibilityDisplayShouldReduceMotion ? "m" : "-"
        ].joined(separator: "|")
    }
}
