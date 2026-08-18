import AppKit
import Observation
import SwiftUI

/// The twelve app-wide primary colors. Values are explicit sRGB so a future Windows client can reproduce them exactly.
enum PrimaryColor: String, CaseIterable, Identifiable {
    case indigo, violet, blue, cyan, teal, emerald, green, lime, amber, orange, coral, rose

    static let storageKey = "primaryColorID"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .indigo: return "Indigo"
        case .violet: return "Violet"
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .teal: return "Teal"
        case .emerald: return "Emerald"
        case .green: return "Green"
        case .lime: return "Lime"
        case .amber: return "Amber"
        case .orange: return "Orange"
        case .coral: return "Coral"
        case .rose: return "Rose"
        }
    }

    var color: Color {
        switch self {
        case .indigo: return Color(red: 0.420, green: 0.380, blue: 0.980)
        case .violet: return Color(red: 0.600, green: 0.400, blue: 0.980)
        case .blue: return Color(red: 0.090, green: 0.395, blue: 0.945)
        case .cyan: return Color(red: 0.015, green: 0.520, blue: 0.680)
        case .teal: return Color(red: 0.015, green: 0.480, blue: 0.470)
        case .emerald: return Color(red: 0.040, green: 0.500, blue: 0.290)
        case .green: return Color(red: 0.160, green: 0.540, blue: 0.140)
        case .lime: return Color(red: 0.340, green: 0.520, blue: 0.070)
        case .amber: return Color(red: 0.700, green: 0.400, blue: 0.020)
        case .orange: return Color(red: 0.780, green: 0.260, blue: 0.050)
        case .coral: return Color(red: 0.780, green: 0.200, blue: 0.180)
        case .rose: return Color(red: 0.865, green: 0.145, blue: 0.415)
        }
    }

    /// Active controls always use white glyphs and labels. Every shipped accent is intentionally dark enough for this pairing, avoiding appearance-transition-dependent black text.
    var selectedForeground: Color { .white }

    var nsColor: NSColor { NSColor(color) }

    static var selected: PrimaryColor {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        return stored.flatMap(PrimaryColor.init(rawValue:)) ?? .indigo
    }
}

/// Shared visual tokens. Accent is computed from the selected primary color so
/// every existing SwiftUI and AppKit surface updates from the same setting.
enum BrandColors {
    static var accent: NSColor { PrimaryColor.selected.nsColor }
    @MainActor
    static var accentColor: Color {
        PrimaryColor(rawValue: SettingsStore.shared.primaryColorID)?.color ?? PrimaryColor.indigo.color
    }
    static var accentDeep: NSColor {
        accent.blended(withFraction: 0.25, of: .black) ?? accent
    }
    static var accentDeepColor: Color { Color(nsColor: accentDeep) }

    static let lightCanvas = Color(red: 0.982, green: 0.983, blue: 0.990)
    static let lightSurface = Color.white
    static let lightBorder = Color(red: 0.900, green: 0.902, blue: 0.920)
    static let darkCanvas = Color(red: 0.075, green: 0.078, blue: 0.098)
    static let darkSurface = Color(red: 0.125, green: 0.130, blue: 0.160)
    static let darkBorder = Color.white.opacity(0.14)
    static let softShadow = Color.black.opacity(0.075)

    /// Frozen product fills. Do not map these to `windowBackgroundColor` or
    /// `controlBackgroundColor` — those resolve grey (and greyer on inactive
    /// floating panels) and regress across macOS versions.
    static let canvasNSColor = NSColor(name: "BeruCanvas") { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(srgbRed: 0.075, green: 0.078, blue: 0.098, alpha: 1)
            : NSColor(srgbRed: 0.982, green: 0.983, blue: 0.990, alpha: 1)
    }
    static let surfaceNSColor = NSColor(name: "BeruSurface") { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(srgbRed: 0.125, green: 0.130, blue: 0.160, alpha: 1)
            : NSColor.white
    }

    static var canvas: Color { Color(nsColor: canvasNSColor) }
    static var surface: Color { Color(nsColor: surfaceNSColor) }
    static var input: Color { Color(nsColor: surfaceNSColor) }
    static var border: Color { Color(nsColor: .separatorColor) }
    static var strongBorder: Color { Color(nsColor: .gridColor) }
}

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
