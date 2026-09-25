import CoreGraphics

/// Window and layout geometry for the settings dashboard.
///
/// The readable form width was declared three times with three values —
/// `DashboardTheme.formMaxWidth` at 720, `DashboardChrome.formMaxWidth` at 680
/// and `DashboardMetrics.contentWidth` at 640 — and only 680 was ever applied.
/// A refactor could easily have "fixed" one of the dead ones.
///
/// Panel geometry stays in `PanelMetrics`, which also owns the window mask and
/// path machinery that AppKit and SwiftUI must derive from the same source.
enum BeruMetrics {
    static let windowWidth: CGFloat = 1180
    static let windowHeight: CGFloat = 720

    /// Navigation sidebar in the settings window.
    static let sidebarWidth: CGFloat = 240
    /// Settings sidebar row. 36pt, on the 4pt grid.
    static let sidebarRowHeight: CGFloat = 36
    /// Settings sidebar icon tile: 28pt well, 16pt glyph. Radius 8 matches
    /// `BeruRadius.sm` so the well is a rounded square, not a circle.
    static let sidebarTileBox: CGFloat = 28
    static let sidebarTileGlyph: CGFloat = 16

    /// Shared height for toolbar, list footer, and inspector bars.
    static let workspaceChromeMinHeight = BeruSpace.xxl

    static let contentPadding = BeruSpace.xl
    static let headerContentSpacing = BeruSpace.md
    /// Band under the traffic lights before the settings body. Hairline sits
    /// on its bottom edge and meets the sidebar vertical rule.
    static let titlebarHeight: CGFloat = 4

    /// The one readable form width.
    static let formMaxWidth: CGFloat = 680
    /// Right-aligned control column in a settings row.
    static let fieldWidth: CGFloat = 200
    /// Label column in a settings row. Narrow enough that title, caption and a
    /// full-width control still fit side by side inside `formMaxWidth`.
    static let labelMaxWidth: CGFloat = 420

    /// Square hit target for icon-only buttons. Visuals are Haze 32/28;
    /// the hit target stays 28 so dense rows remain clickable.
    static let hitTarget: CGFloat = 28
    /// Compact hit target inside dense list rows.
    static let hitTargetCompact: CGFloat = 22
    /// Haze pill height. 32 max per reskin decision; small is 28.
    static let pillHeight: CGFloat = 32
    static let pillHeightSm: CGFloat = 28
    /// Legacy alias for the Haze pill track.
    static var tabPillHeight: CGFloat { pillHeight }
    /// Haze round icon button. 32 max; compact 28 inside dense rows.
    static let roundButton: CGFloat = 32
    static let roundButtonSm: CGFloat = 28
    /// Composer send. 40pt circle, on the 4pt grid, sized as the primary
    /// action inside the well — larger than the 32pt mic beside it.
    static let sendButton: CGFloat = 40
    /// Haze text-field well. 32 to match pills.
    static let fieldHeight: CGFloat = 32
    /// Text bounds of the shortcut recorder. Off the grid on purpose: without
    /// its bezel the search-field cell paints text at the top of its bounds,
    /// so the control must be exactly one text line tall to center in the well.
    static let recorderTextHeight: CGFloat = 18
    /// Haze chip height. 32 to match pills and tabs.
    static let chipHeight: CGFloat = 32
    /// Haze tab height. 32.
    static let tabHeight: CGFloat = 32
    /// Haze float menu width.
    static let menuWidth: CGFloat = 230
    /// Menu-bar dropdown width. Fits hero + rows without wrapping.
    static let menuDropdownWidth: CGFloat = 320
    /// Status-item glyph. 22.5pt — the 18pt macOS standard plus 25%, per
    /// request, so the mark reads next to neighboring icons. Off the 4pt
    /// grid on purpose. The SVG carries its own ~10% internal padding, so the
    /// optical mark lands where system glyphs sit.
    static let menuBarGlyph: CGFloat = 22.5
    /// Haze glyph size. 16 across the app; 12-14 allowed only inside
    /// dense chips, cites, and kbd.
    static let iconSize: CGFloat = 16
    static let iconSizeDense: CGFloat = 12
    /// Compact glyph inside 28pt pills, tabs, and composer chips.
    /// 14 sits between dense (12) and the 16pt default. Off the 4pt
    /// grid on purpose.
    static let iconSizeCompact: CGFloat = 14
    /// Haze hairline. 1pt rules and strokes live here so Panel and
    /// Dashboard never inline the off-grid literal.
    static let hairline: CGFloat = 1
    /// Wide settings field (URLs, keys, model ids). Off the grid on purpose.
    static let wideFieldWidth: CGFloat = 260
    /// About hero brand mark. Off the grid on purpose.
    static let brandHero: CGFloat = 56
    /// Onboarding brand mark and window size. Dialog geometry, not spacing.
    static let brandOnboarding: CGFloat = 72
    static let onboardingWidth: CGFloat = 420
    static let onboardingHeight: CGFloat = 520
    /// Measure width for onboarding body copy so lines stay scannable.
    static let onboardingBodyWidth: CGFloat = 320
    /// Step-progress dots. 6pt height matches the Haze meter bars; the active
    /// dot stretches to 18pt.
    static let onboardingDotHeight: CGFloat = 6
    static let onboardingDotWidth: CGFloat = 18
    /// Haze metapill height for status pills on the panel.
    static let metapillHeight: CGFloat = 26
    /// Lift the hover helper so it sits above the control. The footer row
    /// clips a pill parked underneath (composer well covers it). Tracks the
    /// compact helper height, not the control pill.
    static var helpPillOffset: CGFloat { metapillHeight + BeruSpace.xs }
    /// Haze focus halo. 3pt ring, not a spacing step.
    static let focusHalo: CGFloat = 3
    /// Pixel-grid loader: a 3×3 field of 4pt cells with staggered delays.
    /// Cell/gap sit off the grid on purpose (sub-glyph furniture).
    static let pixelCell: CGFloat = 4
    static let pixelGap: CGFloat = 1.5
    /// One pulse cycle for the Drive/Dots wavefront, and the per-column step
    /// of the chevron stagger. Orbit steps slower around the perimeter.
    static let pixelCycle: Double = 0.65
    static let pixelStep: Double = 0.09
    static let pixelOrbitStep: Double = 0.11
    /// Resting opacities: active cells idle dim, the Orbit center idles dimmer.
    static let pixelDimRest: Double = 0.15
    static let pixelDimIdle: Double = 0.07
    /// Shimmer label: one light band sweep across the text.
    static let shimmerPeriod: Double = 1.4

    /// Result-area spinner. Capped at 32pt so it stays a glyph, not a disc.
    /// Send / Replace use `loaderSizeCompact`.
    static let loaderSize: CGFloat = 32
    /// Loader dash rhythm: short strokes, wide gaps, so the ring reads as
    /// three commas chasing each other rather than a solid ticked circle.
    /// Off the grid on purpose.
    static let loaderDashOn: CGFloat = 5
    static let loaderDashGap: CGFloat = 9
    /// Seconds for the dash pattern to drift one segment around the ring.
    /// Running at a different rate than the spin keeps the motion organic.
    static let loaderDriftPeriod: Double = 2.4
    /// Stroke of the result ring.
    static let loaderStroke: CGFloat = 4
    /// Fits inside `hitTarget` (28) on send and Replace.
    static let loaderSizeCompact: CGFloat = 16
    static let loaderStrokeCompact: CGFloat = 2
}
