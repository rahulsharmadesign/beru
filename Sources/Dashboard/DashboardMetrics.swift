import CoreGraphics

/// Shared spacing for dashboard screens.
///
/// One scale so Models, Runs, and the absorbed Settings tabs don't each
/// invent their own insets. Values sit on an 8pt grid.
enum DashboardMetrics {
    /// Tight control padding (chips, badge inset).
    static let xs: CGFloat = 8
    /// Row / control group padding.
    static let sm: CGFloat = 12
    /// Card / section-internal padding.
    static let md: CGFloat = 16
    /// Screen content inset (detail panes).
    static let lg: CGFloat = 28
    /// Space between major sections on a scroll page.
    static let section: CGFloat = 32
    /// Space between related blocks inside a section.
    static let stack: CGFloat = 16
    /// Gap between tiles in a grid.
    static let grid: CGFloat = 16
    /// Readable form / article column.
    static let contentWidth: CGFloat = 640
    /// Corner radius for soft wells.
    static let radius: CGFloat = 10
}
