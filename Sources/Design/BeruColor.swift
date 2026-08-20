import AppKit
import SwiftUI

/// Semantic color tokens for every Beru surface.
///
/// The app had three parallel color systems: `BrandColors` for the panel,
/// `SettingsTheme` for the dashboard, and `DashboardTheme` for a third opinion
/// on the accent. Same paint, three names, and no single place to change it.
/// This is that place, and the only file in the app allowed to hold a raw
/// color literal.
enum BeruColor {

    // MARK: - Surfaces

    /// The one window and card fill, frozen rather than mapped to
    /// `windowBackgroundColor`. The widget window, its cards, the settings
    /// window and its sidebar must all use this exact paint — a second grey is
    /// what made those surfaces look broken.
    static let canvasNSColor = NSColor(name: "BeruCanvas") { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(srgbRed: 0.125, green: 0.130, blue: 0.160, alpha: 1)
            : NSColor(srgbRed: 0.982, green: 0.983, blue: 0.990, alpha: 1)
    }

    static var canvas: Color { Color(nsColor: canvasNSColor) }
    static var surface: Color { canvas }
    static var input: Color { canvas }

    // MARK: - Lines

    static var border: Color { Color(nsColor: .separatorColor) }
    /// Only where a hairline must survive against a busy fill.
    static var strongBorder: Color { Color(nsColor: .gridColor) }

    // MARK: - Text

    static var textPrimary: Color { Color(nsColor: .labelColor) }
    static var textSecondary: Color { Color(nsColor: .secondaryLabelColor) }

    // MARK: - Accent

    @MainActor
    static var accent: Color {
        (PrimaryColor(rawValue: SettingsStore.shared.primaryColorID) ?? .indigo).color
    }
    /// AppKit surfaces that cannot read the store on the main actor, such as a
    /// window's own background.
    static var accentNSColor: NSColor { PrimaryColor.selected.nsColor }
    static var accentDeepNSColor: NSColor {
        accentNSColor.blended(withFraction: 0.25, of: .black) ?? accentNSColor
    }
    static var accentDeep: Color { Color(nsColor: accentDeepNSColor) }
    /// Label color on top of `accent`. Reads from the selected primary rather
    /// than assuming indigo, so a lighter accent can pair with dark glyphs.
    @MainActor
    static var onAccent: Color {
        (PrimaryColor(rawValue: SettingsStore.shared.primaryColorID) ?? .indigo).selectedForeground
    }

    // MARK: - States

    static var selectedRow: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor) }
    static var badge: Color { Color(nsColor: .unemphasizedSelectedContentBackgroundColor) }
    static var hoverFill: Color { Color(nsColor: .quaternaryLabelColor) }
    /// A filled control that is currently unavailable, such as the panel's send
    /// button before an instruction is typed.
    static let disabledFill = Color.primary.opacity(0.14)
    /// Barely-there fill that separates a control from the card behind it
    /// without reading as a button, used by the composer's picker pills.
    static let subtleFill = Color.primary.opacity(0.05)
    static var positive: Color { Color(nsColor: .systemGreen) }
    static var destructive: Color { Color(nsColor: .systemRed) }

    // MARK: - Fixed appearance pairs

    /// For surfaces that must pick a side explicitly rather than follow the
    /// dynamic canvas, such as the panel's glass chips.
    enum Light {
        static let canvas = Color(red: 0.982, green: 0.983, blue: 0.990)
        static let surface = Color.white
        static let border = Color(red: 0.900, green: 0.902, blue: 0.920)
    }

    enum Dark {
        static let canvas = Color(red: 0.125, green: 0.130, blue: 0.160)
        static let surface = Color(red: 0.125, green: 0.130, blue: 0.160)
        static let border = Color.white.opacity(0.14)
    }

    /// Contrast-tuned status colors for small text sitting on the panel's own
    /// surface. Hand-picked per appearance rather than using system green and
    /// orange, whose values are bright enough that 11pt text over a light card
    /// falls well short of a readable contrast ratio.
    enum Status {
        static let leanerLight = Color(red: 0.07, green: 0.42, blue: 0.18)
        static let leanerDark = Color(red: 0.44, green: 0.86, blue: 0.54)
        static let longerLight = Color(red: 0.56, green: 0.32, blue: 0.02)
        static let longerDark = Color(red: 1.00, green: 0.74, blue: 0.38)
    }

    /// The panel's close disc, drawn in AppKit. Fixed rather than dynamic: this
    /// is the traffic-light red users expect in a window corner, and it has to
    /// read the same over whatever the panel is floating above.
    enum CloseDisc {
        static let fill = NSColor(srgbRed: 1, green: 0.37, blue: 0.34, alpha: 1)
        static let pressedFill = NSColor(srgbRed: 0.78, green: 0.16, blue: 0.14, alpha: 1)
        static let glyph = NSColor(srgbRed: 0.30, green: 0.04, blue: 0.03, alpha: 0.88)
    }

    // MARK: - Elevation

    static let softShadow = Color.black.opacity(0.075)
}
