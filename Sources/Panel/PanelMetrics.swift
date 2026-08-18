import AppKit
import SwiftUI

/// The panel's geometry, defined once. Corner radius used to be hard-coded in
/// three places (SwiftUI clip, hosting layer, glass background); when those
/// rasterized differently a hairline of square backing showed at the corners.
enum PanelMetrics {
    static let width: CGFloat = 420
    /// Idle panel should feel compact — a tall empty middle read as broken UI.
    static let minHeight: CGFloat = 320
    /// Absolute ceiling. The live cap is 80% of the viewport (see
    /// `PanelController`); this only guards against an implausibly tall screen.
    static let maxHeight: CGFloat = 2000
    /// Fraction of the screen's visible height the panel may fill before its
    /// result area begins to scroll internally.
    static let maxViewportFraction: CGFloat = 0.8
    /// Outer window. Layer radius is the source of truth — do not use a
    /// stretchable mask, which inflates this into a capsule.
    static let cornerRadius: CGFloat = 20
    /// Gap between the window edge and the SwiftUI hosting view. Applied in
    /// AppKit so SwiftUI layout cannot draw flush with the window mask.
    static let windowInset: CGFloat = 10
    /// Title chrome sits flush with the rounded top; only sides and bottom keep this inset.
    static let windowTopInset: CGFloat = 0
    /// Title chrome above the inner cards — holds the close control.
    static let closeStripHeight: CGFloat = 28
    /// Kept at zero: the panel uses the window-server shadow (`hasShadow`),
    /// which draws outside the frame. A transparent inset is not needed.
    static let shadowInset: CGFloat = 0
    static var windowWidth: CGFloat { width + shadowInset * 2 }
    static func windowHeight(for contentHeight: CGFloat) -> CGFloat {
        contentHeight + shadowInset * 2 + windowTopInset + windowInset
    }

    // MARK: - Modules
    /// 10pt on every side of the widget and between the four inner cards.
    static let moduleInset: CGFloat = 10
    static let moduleSpacing: CGFloat = 10
    /// All four inner cards share this outer radius.
    static var moduleRadius: CGFloat { 10 }
    static var moduleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: moduleRadius, style: .circular)
    }
    /// Horizontal chip row. A ScrollView without this collapses and clips
    /// the chips' vertical padding against the toolbar border.
    static let chipRowHeight: CGFloat = 32
    /// Footer (regenerate / dismiss) refuses to compress below this.
    static let footerMinHeight: CGFloat = 36
    /// Composer, including its internal padding.
    static let composerMinHeight: CGFloat = 44
    /// Gaps between the four modules.
    static let moduleChromeHeight: CGFloat = moduleSpacing * 3
    static let screenInset: CGFloat = 8
    /// Ignore height changes smaller than this to stop the window resizing on
    /// every reflow.
    static let resizeDeadband: CGFloat = 4
    /// The single path definition. AppKit masks and SwiftUI clips both derive
    /// from this so the two rasterizations match exactly.
    static func cgPath(in rect: CGRect, radius: CGFloat = cornerRadius) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    struct CardShape: InsettableShape {
        var radius: CGFloat = PanelMetrics.cornerRadius
        var inset: CGFloat = 0
        func path(in rect: CGRect) -> Path {
            Path(PanelMetrics.cgPath(in: rect.insetBy(dx: inset, dy: inset), radius: max(radius - inset, 0)))
        }
        func inset(by amount: CGFloat) -> Self {
            var copy = self
            copy.inset += amount
            return copy
        }
    }

    static var cardShape: CardShape { CardShape() }

    /// A stretchable mask matching `cardShape`. NSVisualEffectView cannot be
    /// clipped by SwiftUI's `.clipShape`, and its opaque region is what AppKit
    /// derives the window shadow from — so without this the shadow stays
    /// square even when the pixels look rounded.
    static func roundedMaskImage(radius: CGFloat = cornerRadius) -> NSImage {
        let diameter = radius * 2 + 1
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            NSColor.black.setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            path.fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
