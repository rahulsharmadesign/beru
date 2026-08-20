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
    /// Secondary list column inside a workspace page (Actions, Targets, Vault).
    static let workspaceListWidth: CGFloat = 280
    static let workspaceListInset = BeruSpace.md

    static let contentPadding = BeruSpace.xl
    static let headerContentSpacing = BeruSpace.md

    /// The one readable form width.
    static let formMaxWidth: CGFloat = 680
    /// Right-aligned control column in a settings row.
    static let fieldWidth: CGFloat = 200
    /// Label column in a settings row. Narrow enough that title, caption and a
    /// full-width control still fit side by side inside `formMaxWidth`.
    static let labelMaxWidth: CGFloat = 420

    /// Square hit target for icon-only buttons. Also the panel's send and
    /// dictation buttons, which were three separate 28pt literals.
    static let hitTarget: CGFloat = 28
    /// Compact hit target inside dense list rows.
    static let hitTargetCompact: CGFloat = 22
}
