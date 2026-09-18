import AppKit

/// macOS 27 Liquid Glass APIs that the 26.5 SDK we build with does not
/// declare. Reached by selector so a Tahoe-linked binary still lights them
/// up on Golden Gate, and a 26-only Mac no-ops.
enum LiquidGlassChrome {
    /// Window-level slab. `interactive` stays off: the panel and Settings
    /// *are* the glass, and macOS 27's interactive response bounces the
    /// whole window a few pixels on every click.
    ///
    /// `.regular` plus a tint, not `.clear`: clear is so transparent the
    /// desktop's text reads straight through the panel (measured — unusable),
    /// while untinted regular is the frosted near-opaque card that reads as
    /// plain blur. A 38% scrim tint keeps regular's refraction and edge
    /// highlights visible but puts enough material under the type. Content
    /// scrims (composer well, result card) sit on top; Reduce Transparency
    /// still swaps to the opaque plate.
    static func prepareWindowSlab(_ glass: NSGlassEffectView, interactive: Bool = false) {
        glass.style = .regular
        glass.tintColor = BeruColor.glassTintNSColor
        let setter = NSSelectorFromString("setEffectIsInteractive:")
        guard glass.responds(to: setter) else { return }
        glass.setValue(interactive, forKey: "effectIsInteractive")
    }

    /// Object/concept rows (targets, providers) keep their symbols. macOS 27
    /// hides SF Symbols in menus by default, including `NSMenu.popUp`.
    static func keepMenuImageVisible(_ item: NSMenuItem) {
        let setter = NSSelectorFromString("setPreferredImageVisibility:")
        guard item.responds(to: setter) else { return }
        // NSMenuItem.ImageVisibility.visible. Raw value is stable; the 26.5
        // SDK has no Swift name for it.
        item.setValue(1, forKey: "preferredImageVisibility")
    }

    static func isInteractive(_ glass: NSGlassEffectView) -> Bool? {
        guard glass.responds(to: NSSelectorFromString("effectIsInteractive")) else {
            return nil
        }
        return (glass.value(forKey: "effectIsInteractive") as? NSNumber)?.boolValue
    }

    static func menuImageVisibility(_ item: NSMenuItem) -> Int? {
        guard item.responds(to: NSSelectorFromString("preferredImageVisibility")) else {
            return nil
        }
        return (item.value(forKey: "preferredImageVisibility") as? NSNumber)?.intValue
    }
}
