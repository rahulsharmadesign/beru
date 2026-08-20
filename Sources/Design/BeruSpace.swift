import CoreGraphics

/// The spacing scale. A 4pt base with an 8pt rhythm.
///
/// Before this existed the app used 3, 5, 6, 7, 9, 10, 11, 14, 18, 22 and 28
/// interchangeably for the same visual role, so two rows that should have
/// matched never did. Every gap and inset now resolves to one of these.
///
/// Nothing outside `Sources/Design` may inline a spacing number; the
/// `offgrid_spacing` guard in `scripts/qa.sh` enforces it.
enum BeruSpace {
    /// Optical separation only: a label above its own caption, a badge inset.
    static let hair: CGFloat = 2
    /// Tight pairing inside a single control.
    static let xxs: CGFloat = 4
    /// Between controls in a row; the smallest gap that reads as a gap.
    static let xs: CGFloat = 8
    /// Inside a row or control group.
    static let sm: CGFloat = 12
    /// Card padding, and between stacked blocks in a section.
    static let md: CGFloat = 16
    /// Screen content inset, and between sections.
    static let lg: CGFloat = 24
    /// Between major sections on a scrolling page.
    static let xl: CGFloat = 32
    /// Page top and bottom breathing room.
    static let xxl: CGFloat = 48
}
