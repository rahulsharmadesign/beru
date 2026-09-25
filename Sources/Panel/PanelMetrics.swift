import AppKit
import SwiftUI

/// The panel's geometry, defined once. Corner radius used to be hard-coded in
/// three places (SwiftUI clip, hosting layer, glass background); when those
/// rasterized differently a hairline of square backing showed at the corners.
enum PanelMetrics {
    static let width: CGFloat = 480
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
    /// Outer window. Haze panel radius 28 on macOS. Layer radius is the
    /// source of truth — do not use a stretchable mask, which inflates
    /// this into a capsule.
    static let cornerRadius: CGFloat = 28
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
    /// Smallest real chrome: close strip + the footer band (the collapsed
    /// composer contributes nothing else) + the outer inset and the two
    /// spacings around the result. Incomplete band reports land around 40pt
    /// (insets + spacings, GeometryReaders not yet in the tree).
    /// Floor must stay below real chrome or the window sticks at seed height —
    /// it used to count the full composer, so once the composer could
    /// collapse every report was rejected and long results ran under the
    /// footer at the 280pt seed height.
    static var minimumChromeHeight: CGFloat {
        moduleInset * 2 + closeStripHeight + footerMinHeight + moduleSpacing * 2
    }
    /// All four inner cards share this outer radius. Haze card radius.
    static var moduleRadius: CGFloat { EnhancifyRadius.md }
    /// Horizontal chip row. Haze pill height.
    static var chipRowHeight: CGFloat { EnhancifyMetrics.pillHeight }
    /// Outcome-row slot above the composer. Always reserved so a tab switch
    /// cannot grow the window when the icons appear. Haze pill height.
    static let footerMinHeight: CGFloat = 32
    /// Composer, including its internal padding. Must stay below the real
    /// idle composer height — the window floors to this when a band report
    /// is incomplete, and anything taller leaves a gap under the composer.
    static let composerMinHeight: CGFloat = 76
    /// Height reserved by the result area while a request is in flight.
    static let resultPlaceholderHeight: CGFloat = 120
    /// Idle result band floor. Tall enough that the opening widget breathes;
    /// placeholder copy stays vertically centered in it. Search ↔ Enhance
    /// placeholder swaps never change this height, so tab switches cannot
    /// crop the composer.
    static let resultIdleMinHeight: CGFloat = 172
    /// Focused mode's empty state: the composer is the whole prompt, so the
    /// result band only keeps a sliver. Must stay above 1pt — the controller
    /// treats a smaller result as "not measured yet" and reuses the last one.
    static let resultIdleCompactHeight: CGFloat = 8
    /// Composer card only — toolbar and result stay on `moduleRadius`.
    /// Haze composer radius.
    static let composerRadius: CGFloat = 22
    static let screenInset: CGFloat = 8
    /// Sub-point only — ignore measurement noise, not 10pt layout changes.
    static let resizeDeadband: CGFloat = 1
}
