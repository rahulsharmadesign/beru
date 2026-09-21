import AppKit

/// Traffic-disc paints for the panel titlebar, drawn in AppKit. Fixed rather
/// than dynamic: these are the traffic-light colors users expect in a window
/// corner, and they have to read the same over whatever the panel is
/// floating above.
///
/// Lives here rather than in BeruColor: that file sits at the 400-line
/// ceiling and the discs are one responsibility (titlebar chrome).
extension BeruColor {
    /// The panel's close disc.
    enum CloseDisc {
        static let fill = NSColor(srgbRed: 1, green: 0.37, blue: 0.34, alpha: 1)
        static let pressedFill = NSColor(srgbRed: 0.78, green: 0.16, blue: 0.14, alpha: 1)
        static let glyph = NSColor(srgbRed: 0.30, green: 0.04, blue: 0.03, alpha: 0.88)
    }

    /// The panel's zoom disc. Same reasoning as `CloseDisc`: a traffic-light
    /// green, fixed per appearance rather than dynamic.
    enum ZoomDisc {
        static let fill = NSColor(srgbRed: 0.20, green: 0.78, blue: 0.31, alpha: 1)
        static let pressedFill = NSColor(srgbRed: 0.13, green: 0.56, blue: 0.20, alpha: 1)
        static let glyph = NSColor(srgbRed: 0.03, green: 0.30, blue: 0.09, alpha: 0.88)
    }
}
