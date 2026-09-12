import AppKit
import SwiftUI

/// Semantic color tokens for every Beru surface.
///
/// Haze paint: canvas, translucent panel/surface, surface-2 pills/wells,
/// surface-3 pressed, hairline strokes, 3-level text, accent + soft washes,
/// ok/warn/bad, 170° panel and accent gradients, 3px focus glow.
/// This is the only file in the app allowed to hold a raw color literal.
enum BeruColor {

    // MARK: - Surfaces

    /// Page fill. Haze `--canvas`: #F2F3F6 light, #141517 dark.
    static let canvasNSColor = NSColor(name: "BeruCanvas") { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(srgbRed: 20 / 255, green: 21 / 255, blue: 23 / 255, alpha: 1)
            : NSColor(srgbRed: 242 / 255, green: 243 / 255, blue: 246 / 255, alpha: 1)
    }

    /// Composer field fill on the glass slab. Dark: 14% white hint. Light:
    /// 72% white so the caret sits on a well, not the page.
    /// Reduce Transparency uses `panelSolid` instead (see `GlassModule`).
    static var composerWell: Color {
        Color(nsColor: NSColor(name: "BeruComposerWell") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.14)
                : NSColor.white.withAlphaComponent(0.72)
        })
    }
    /// Opaque plate for Reduce Transparency. Haze `--panel-solid`:
    /// #FFFFFF light, #202124 dark.
    static let panelSolidNSColor = NSColor(name: "BeruPanelSolid") { appearance in
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return dark
            ? NSColor(srgbRed: 32 / 255, green: 33 / 255, blue: 36 / 255, alpha: 1)
            : .white
    }

    static var canvas: Color { Color(nsColor: canvasNSColor) }
    static var panelSolid: Color { Color(nsColor: panelSolidNSColor) }
    /// Translucent card fill. Haze `--surface`: white 72% light,
    /// white 5% dark.
    static var surface: Color {
        Color(nsColor: NSColor(name: "BeruSurface") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.05)
                : NSColor.white.withAlphaComponent(0.72)
        })
    }
    /// Pill / well fill. Haze `--surface-2`: #F3F4F7 light, white 7% dark.
    static var surface2: Color {
        Color(nsColor: NSColor(name: "BeruSurface2") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.07)
                : NSColor(srgbRed: 243 / 255, green: 244 / 255, blue: 247 / 255, alpha: 1)
        })
    }
    /// Pressed fill. Haze `--surface-3`: #E9EBF0 light, white 11% dark.
    static var surface3: Color {
        Color(nsColor: NSColor(name: "BeruSurface3") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.11)
                : NSColor(srgbRed: 233 / 255, green: 235 / 255, blue: 240 / 255, alpha: 1)
        })
    }
    /// System text-field well. Settings sits on window material; filling
    /// editors with `canvas` painted a navy patch next to native Name/Icon fields.
    static var input: Color { Color(nsColor: .textBackgroundColor) }

    // MARK: - Lines

    /// Hairline stroke. Haze `--hair`: ink 7% light, white 8% dark.
    static var border: Color {
        Color(nsColor: NSColor(name: "BeruHair") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.08)
                : NSColor(srgbRed: 17 / 255, green: 20 / 255, blue: 24 / 255, alpha: 0.07)
        })
    }
    /// Only where a hairline must survive against a busy fill.
    /// Haze `--hair-strong`: ink 12% light, white 14% dark.
    static var strongBorder: Color {
        Color(nsColor: NSColor(name: "BeruHairStrong") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.14)
                : NSColor(srgbRed: 17 / 255, green: 20 / 255, blue: 24 / 255, alpha: 0.12)
        })
    }
    /// Lit 1pt along the top edge. Haze `--edge`.
    static var edge: Color {
        Color(nsColor: NSColor(name: "BeruEdge") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor.white.withAlphaComponent(0.06)
                : NSColor.white.withAlphaComponent(0.90)
        })
    }

    // MARK: - Text

    /// Haze `--text`: #14171C light, #ECEDEF dark.
    static var textPrimary: Color {
        Color(nsColor: NSColor(name: "BeruText") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 236 / 255, green: 237 / 255, blue: 239 / 255, alpha: 1)
                : NSColor(srgbRed: 20 / 255, green: 23 / 255, blue: 28 / 255, alpha: 1)
        })
    }
    /// Haze `--text-2`: #6B7280 light, #A3A7AF dark.
    static var textSecondary: Color {
        Color(nsColor: NSColor(name: "BeruText2") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 163 / 255, green: 167 / 255, blue: 175 / 255, alpha: 1)
                : NSColor(srgbRed: 107 / 255, green: 114 / 255, blue: 128 / 255, alpha: 1)
        })
    }
    /// Haze `--text-3`: #A0A6B1 light, #6E737C dark.
    static var textTertiary: Color {
        Color(nsColor: NSColor(name: "BeruText3") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 110 / 255, green: 115 / 255, blue: 124 / 255, alpha: 1)
                : NSColor(srgbRed: 160 / 255, green: 166 / 255, blue: 177 / 255, alpha: 1)
        })
    }
    /// Status-item bee. Always white: Light appearance still paints a dark
    /// menu bar over a dark wallpaper, and a template black glyph disappears
    /// against Control Center / Wi-Fi which stay white in that slot.
    static var menuBarGlyphNSColor: NSColor { .white }
    static var menuBarGlyph: Color { Color(nsColor: menuBarGlyphNSColor) }

    /// Glyph on a colored sidebar tile. Always white so it reads on every
    /// System Settings–style squircle, independent of the selected accent.
    static var onTile: Color { .white }

    /// Markdown links in search answers and vault preview. System link color so
    /// it stays a distinct hue from `textPrimary` in both appearances.
    static var link: Color { Color(nsColor: .linkColor) }

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

    static var selectedRow: Color {
        Color(nsColor: accentNSColor.withAlphaComponent(0.10))
    }
    static var badge: Color { surface2 }
    static var hoverFill: Color { surface3 }
    /// A filled control that is currently unavailable, such as the panel's send
    /// button before an instruction is typed.
    static var disabledFill: Color { surface3 }
    /// Barely-there fill that separates a control from the card behind it
    /// without reading as a button, used by the composer's picker pills.
    /// Haze `--surface-2`.
    static var subtleFill: Color { surface2 }
    /// Grouped settings card. Haze `--surface`.
    static var card: Color { surface }
    /// Haze `--ok`: #22A06B light, #3DCB8A dark.
    static var positive: Color {
        Color(nsColor: NSColor(name: "BeruOk") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 61 / 255, green: 203 / 255, blue: 138 / 255, alpha: 1)
                : NSColor(srgbRed: 34 / 255, green: 160 / 255, blue: 107 / 255, alpha: 1)
        })
    }
    /// Haze `--warn`: #E0A100 light, #F2B933 dark.
    static var warning: Color {
        Color(nsColor: NSColor(name: "BeruWarn") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 242 / 255, green: 185 / 255, blue: 51 / 255, alpha: 1)
                : NSColor(srgbRed: 224 / 255, green: 161 / 255, blue: 0, alpha: 1)
        })
    }
    /// Haze `--bad`: #E5484D light, #F26B6F dark.
    static var destructive: Color {
        Color(nsColor: NSColor(name: "BeruBad") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 242 / 255, green: 107 / 255, blue: 111 / 255, alpha: 1)
                : NSColor(srgbRed: 229 / 255, green: 72 / 255, blue: 77 / 255, alpha: 1)
        })
    }
    /// Danger well fill behind destructive settings groups.
    /// Haze `--bad-soft`: bad 8% light, bad 14% dark.
    static var dangerFill: Color {
        Color(nsColor: NSColor(name: "BeruBadSoft") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 242 / 255, green: 107 / 255, blue: 111 / 255, alpha: 0.14)
                : NSColor(srgbRed: 229 / 255, green: 72 / 255, blue: 77 / 255, alpha: 0.08)
        })
    }
    /// Hairline for the danger well. Haze `--bad-hair`: bad 22% light, bad 30% dark.
    static var dangerBorder: Color {
        Color(nsColor: NSColor(name: "BeruBadHair") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 242 / 255, green: 107 / 255, blue: 111 / 255, alpha: 0.30)
                : NSColor(srgbRed: 229 / 255, green: 72 / 255, blue: 77 / 255, alpha: 0.22)
        })
    }

    /// 170° panel wash over the blurred plate. Haze `--g-panel`.
    static var panelGradient: LinearGradient {
        LinearGradient(
            colors: [panelGradientTop, panelGradientBottom],
            startPoint: UnitPoint(x: 0.42, y: 0),
            endPoint: UnitPoint(x: 0.58, y: 1)
        )
    }

    static var panelGradientTop: Color {
        Color(nsColor: NSColor(name: "BeruPanelTop") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 40 / 255, green: 41 / 255, blue: 45 / 255, alpha: 0.96)
                : NSColor.white.withAlphaComponent(0.96)
        })
    }

    static var panelGradientBottom: Color {
        Color(nsColor: NSColor(name: "BeruPanelBottom") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 30 / 255, green: 31 / 255, blue: 34 / 255, alpha: 0.90)
                : NSColor.white.withAlphaComponent(0.82)
        })
    }

    /// 170° primary fill for pills and the send disc. Haze `--g-accent`.
    @MainActor
    static var accentGradient: LinearGradient {
        let base = accent
        let top = Color(nsColor: accentNSColor.blended(withFraction: 0.18, of: .white) ?? accentNSColor)
        return LinearGradient(
            colors: [top, base],
            startPoint: UnitPoint(x: 0.42, y: 0),
            endPoint: UnitPoint(x: 0.58, y: 1)
        )
    }

    /// Soft accent wash for tonal pills and selected rows.
    /// Haze `--accent-soft` at 10% light, 16% dark.
    @MainActor
    static var accentSoft: Color { accent.opacity(0.10) }

    /// Soft 3pt halo used as the focus ring. Haze `--glow`.
    @MainActor
    static var focusGlow: Color { accent.opacity(0.14) }

    /// Track of the loading ring at 50% opacity so it does not read as a black disc.
    static var loaderTrack: Color {
        Color(nsColor: NSColor(name: "BeruLoaderTrack") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark
                ? NSColor(srgbRed: 35 / 255, green: 35 / 255, blue: 38 / 255, alpha: 0.5)
                : NSColor(srgbRed: 0.90, green: 0.90, blue: 0.91, alpha: 0.5)
        })
    }

    // MARK: - Fixed appearance pairs

    /// For surfaces that must pick a side explicitly rather than follow the
    /// dynamic canvas, such as the panel's glass chips.
    enum Light {
        static let canvas = Color(red: 242 / 255, green: 243 / 255, blue: 246 / 255)
        static let surface = Color.white
        static let border = Color(red: 17 / 255, green: 20 / 255, blue: 24 / 255).opacity(0.07)
    }

    enum Dark {
        static let canvas = Color(red: 20 / 255, green: 21 / 255, blue: 23 / 255)
        static let surface = Color(red: 32 / 255, green: 33 / 255, blue: 36 / 255)
        static let border = Color.white.opacity(0.08)
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

    /// Haze e2 lift for floating cards (menus, popups): soft lift plus a tight
    /// contact shadow. Window slabs use `softShadow` instead.
    static var liftShadow: Color {
        Color(nsColor: NSColor(name: "BeruLift") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor.black.withAlphaComponent(dark ? 0.35 : 0.06)
        })
    }

    static var contactShadow: Color {
        Color(nsColor: NSColor(name: "BeruContact") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor.black.withAlphaComponent(dark ? 0.30 : 0.04)
        })
    }
}
