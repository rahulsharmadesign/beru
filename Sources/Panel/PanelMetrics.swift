import AppKit
import SwiftUI

/// The panel's geometry, defined once. Corner radius used to be hard-coded in
/// three places (SwiftUI clip, hosting layer, glass background); when those
/// rasterized differently a hairline of square backing showed at the corners.
enum PanelMetrics {
    static let width: CGFloat = 420
    /// Provisional window height for the first offscreen frame only. After the
    /// first SwiftUI measure, the window equals content — never re-impose this
    /// as a floor (that fake gap under idle states looked like "extra padding").
    static let seedHeight: CGFloat = 280
    /// Compatibility alias for tests / call sites that mean the seed frame.
    static var minHeight: CGFloat { seedHeight }
    /// Absolute ceiling. The live cap is 75% of the viewport (see
    /// `PanelController`); this only guards against an implausibly tall screen.
    static let maxHeight: CGFloat = 2000
    /// Fraction of the screen's visible height the panel may fill before the
    /// result area scrolls and chrome (close / chips / composer) stays pinned.
    /// Freeze: do not change without updating PanelViewportCapTests + QA.
    static let maxViewportFraction: CGFloat = 0.75
    /// Outer window. Layer radius is the source of truth — do not use a
    /// stretchable mask, which inflates this into a capsule.
    static let cornerRadius: CGFloat = 20
    /// SwiftUI fills the glass slab. Inner padding is `moduleInset` on the
    /// SwiftUI root — not AppKit (`windowInset` / `shadowInset` stay 0).
    static let windowInset: CGFloat = 0
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
    /// 10pt on every side of the widget and between close / tabs / print / composer.
    /// Layout only — never inflate to "fix" crop.
    static let moduleInset: CGFloat = 10
    static let moduleSpacing: CGFloat = 10
    /// Smallest chrome that still contains close + composer + the outer inset
    /// and the two spacings around the result. Incomplete band reports land
    /// around 40pt (insets + spacings, GeometryReaders not yet in the tree).
    /// Floor must stay below real chrome or the window sticks at seed height.
    static var minimumChromeHeight: CGFloat {
        moduleInset * 2 + closeStripHeight + composerMinHeight + moduleSpacing * 2
    }
    /// All four inner cards share this outer radius.
    static var moduleRadius: CGFloat { 10 }
    static var moduleShape: RoundedRectangle {
        BeruRadius.shape(moduleRadius)
    }
    /// Horizontal chip row. Matches the iOS 26 compact toolbar pill.
    static var chipRowHeight: CGFloat { BeruMetrics.tabPillHeight }
    /// Footer (regenerate / dismiss) refuses to compress below this.
    static let footerMinHeight: CGFloat = 36
    /// Composer, including its internal padding. Two-row field + chrome.
    static let composerMinHeight: CGFloat = 76
    /// Height reserved by the result area while a request is in flight.
    static let resultPlaceholderHeight: CGFloat = 120
    /// Idle result card floor so Search ↔ Enhance placeholder copy does not
    /// change the print-area height and crop the composer on tab switch.
    static let resultIdleMinHeight: CGFloat = 72
    /// Composer card only — toolbar and result stay on `moduleRadius`.
    static let composerRadius: CGFloat = 16
    /// How far the outcome strip tucks under the composer.
    static let composerOverlap: CGFloat = 12
    static let screenInset: CGFloat = 8
    /// Sub-point only — ignore measurement noise, not 10pt layout changes.
    static let resizeDeadband: CGFloat = 1
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
