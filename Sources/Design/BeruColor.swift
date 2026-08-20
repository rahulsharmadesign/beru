import AppKit
import SwiftUI

/// Semantic color tokens for every Beru surface.
///
/// The app had three parallel color systems: `BrandColors` for the panel,
/// `SettingsTheme` for the dashboard, and `DashboardTheme` for a third opinion
/// on the accent. Same paint, three names, and no single place to change it.
/// This is that place.
///
/// Values still resolve through `BrandColors` while call sites migrate; that
/// type collapses into this one once nothing references it directly.
enum BeruColor {

    // MARK: - Surfaces

    /// The one window and card fill. A second grey is what made the panel and
    /// the settings window look like different apps.
    static var canvas: Color { BrandColors.canvas }
    static var surface: Color { BrandColors.surface }
    static var input: Color { BrandColors.input }

    /// AppKit needs the dynamic `NSColor`, not a resolved SwiftUI `Color`.
    static var canvasNSColor: NSColor { BrandColors.canvasNSColor }

    // MARK: - Lines

    static var border: Color { BrandColors.border }
    /// Only where a hairline must survive against a busy fill.
    static var strongBorder: Color { BrandColors.strongBorder }

    // MARK: - Text

    static var textPrimary: Color { Color(nsColor: .labelColor) }
    static var textSecondary: Color { Color(nsColor: .secondaryLabelColor) }

    // MARK: - Accent

    @MainActor
    static var accent: Color { BrandColors.accentColor }
    @MainActor
    static var accentDeep: Color { BrandColors.accentDeepColor }
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
    static var positive: Color { Color(nsColor: .systemGreen) }
    static var destructive: Color { Color(nsColor: .systemRed) }

    // MARK: - Fixed appearance pairs

    /// For surfaces that must pick a side explicitly rather than follow the
    /// dynamic canvas, such as the panel's glass chips.
    enum Light {
        static let canvas = BrandColors.lightCanvas
        static let surface = BrandColors.lightSurface
        static let border = BrandColors.lightBorder
    }

    enum Dark {
        static let canvas = BrandColors.darkCanvas
        static let surface = BrandColors.darkSurface
        static let border = BrandColors.darkBorder
    }

    // MARK: - Elevation

    static let softShadow = BrandColors.softShadow
}
