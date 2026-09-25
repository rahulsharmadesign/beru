import AppKit
import SwiftUI

/// Lucide glyphs first, SF Symbols as fallback. Stored ids stay Lucide
/// kebab-case (or legacy Material names); vendored SVGs in Assets.xcassets
/// render with template intent at their native 2px stroke, and anything
/// without an asset resolves through `IconNames.system`.
///
/// Haze glyph is 16x16 across the app. Dense chips, cites, and kbd may use
/// `EnhancifyMetrics.iconSizeDense`.
struct EnhancifyIcon: View {
    let name: String
    var size: CGFloat = 16
    /// Kept so existing call sites compile. SF Symbols use font weight, not
    /// stroke; Lucide assets ignore it.
    var strokeWidth: CGFloat = 1.8

    var body: some View {
        if Self.hasTemplateAsset(name) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: IconNames.system(stored: name))
                .font(.system(size: size, weight: strokeWidth >= 2.2 ? .semibold : .medium))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    /// Asset probe, cached per name. SF Symbols remain the fallback for
    /// true-SF names and custom ids (`target-cursor`).
    private static var templateCache: [String: Bool] = [:]

    private static func hasTemplateAsset(_ name: String) -> Bool {
        if let hit = templateCache[name] { return hit }
        let found = NSImage(named: name) != nil
        templateCache[name] = found
        return found
    }
}

/// Icon + title label using SF Symbols.
struct EnhancifyLabel: View {
    let title: String
    let icon: String
    var iconSize: CGFloat = 16
    var strokeWidth: CGFloat = 1.8

    var body: some View {
        Label {
            Text(title)
        } icon: {
            EnhancifyIcon(name: icon, size: iconSize, strokeWidth: strokeWidth)
        }
    }
}

/// Resolves stored icon ids (Lucide kebab-case, Material, or SF Symbol) to SF Symbols.
enum IconNames {
    static func system(stored: String) -> String {
        if let mapped = lucideToSystem[stored] { return mapped }
        if stored.contains(".") { return stored }
        return stored
    }

    private static let lucideToSystem: [String: String] = [
        // Lucide kebab-case
        "circle-check": "checkmark.circle",
        "sparkles": "sparkles",
        "corner-up-left": "arrowshape.turn.up.left",
        "list": "list.bullet",
        "lightbulb": "lightbulb",
        "smile": "face.smiling",
        "briefcase": "briefcase",
        "minimize-2": "arrow.down.right.and.arrow.up.left",
        "circle-dashed": "circle.dashed",
        "code": "chevron.left.forwardslash.chevron.right",
        "messages-square": "bubble.left.and.bubble.right",
        "globe": "globe",
        "message-square": "message",
        "wand-sparkles": "wand.and.stars",
        "target": "target",
        "message-circle": "message.circle",
        "maximize-2": "arrow.up.left.and.arrow.down.right",
        "settings": "gearshape",
        "check": "checkmark",
        "chevrons-up-down": "chevron.up.chevron.down",
        "graduation-cap": "graduationcap",
        "chevron-down": "chevron.down",
        "rotate-cw": "arrow.clockwise",
        "x": "xmark",
        "search": "magnifyingglass",
        "circle-arrow-up": "arrow.up.circle.fill",
        "arrow-down-right": "arrow.down.right",
        "arrow-up-right": "arrow.up.right",
        "arrow-up": "arrow.up",
        "equal": "equal",
        "trash-2": "trash",
        "plus": "plus",
        "minus": "minus",
        "mic": "mic.fill",
        "library": "books.vertical",
        "mic-off": "mic.slash",
        // DictationButton. Lucide `audio-lines` is not an SF Symbol name.
        "audio-lines": "mic.fill",
        "eye": "eye",
        "eye-off": "eye.slash",
        "circle-x": "xmark.circle",
        "pin": "pin",
        "pin-off": "pin.slash",
        "sticky-note": "note.text",
        "list-filter": "line.3.horizontal.decrease",
        "package": "shippingbox",
        "cpu": "cpu",
        "house": "house",
        "link": "link",
        "pause": "pause",
        "history": "clock.arrow.circlepath",
        "person": "person",
        "info": "info.circle",
        "lock": "lock.fill",
        "database": "internaldrive",
        // Lucide `braces` has no asset; the SF Symbol is `curlybraces`.
        "braces": "curlybraces",
        // Material Symbols leftover in settings chrome
        "close": "xmark",
        "visibility": "eye",
        "visibility_off": "eye.slash",
        "expand_more": "chevron.down",
        "check_circle": "checkmark.circle",
        "cancel": "xmark.circle",
        "keep": "pin",
        "keep_off": "pin.slash",
        "sticky_note_2": "note.text",
        "auto_awesome": "sparkles",
        "filter_list": "line.3.horizontal.decrease",
        "inventory_2": "shippingbox",
        "track_changes": "target",
        "memory": "cpu",
        "remove": "minus",
        "add": "plus",
        "home": "house",
    ]
}

/// Menu-bar mark: the ant SVG baked to exact pixels as a *template* image,
/// so the system tints it for the bar's actual luminance — black on a light
/// bar, white on a dark one — at draw time, on every frame.
///
/// This replaced a snapshot design that baked Black/White per the view's
/// `colorScheme` Bool at body-evaluation time. That froze whenever the
/// MenuBarExtra label missed an appearance invalidation, and disagreed with
/// wallpaper-tinted bars where the bar and the app use different schemes. A
/// template can be stale in neither way: there is no variant to pick and
/// nothing to re-cook on a theme change.
///
/// Two lessons baked into this shape. First, never read the scheme here at
/// all — not the view's, not `NSApp.effectiveAppearance`. Second, the size
/// must be baked: a `MenuBarExtra` label stretches a framed SwiftUI `Image`
/// to bar height, ignoring the frame — measured 49px on screen for an 18pt
/// frame — while an explicitly-sized NSImage renders exactly.
struct EnhancifyMenuBarIcon: View {
    var body: some View {
        Image(nsImage: Self.glyph())
            .renderingMode(.template)
            .accessibilityLabel("Enhancify")
    }

    private static func glyph() -> NSImage {
        let side = EnhancifyMetrics.menuBarGlyph
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            NSImage(named: "MenuBarIcon")?.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }
        // Alpha is the mask; the bar supplies the color live. Either catalog
        // variant (Black/White solid on transparent) yields the same mask.
        image.isTemplate = true
        return image
    }
}
