import SwiftUI

/// The type scale, covering both the panel and the settings window.
///
/// `Sources/Panel/` used to hardcode `.system(size: 11/12/13)` in 26 places
/// while the dashboard used named roles, so the same caption rendered at a
/// different size depending on which surface it landed on. These are the same
/// sizes the app already ships; they now have names.
enum BeruType {
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: Page

    /// Onboarding only. The one place a title carries the whole window.
    static let heroTitle = font(22, weight: .bold)
    static let pageTitle = font(20, weight: .semibold)
    static let pageSubtitle = font(13)
    static let section = font(14, weight: .semibold)

    // MARK: Rows and controls

    static let rowTitle = font(14)
    static let control = font(14)
    static let search = font(14)
    static let sidebar = font(14)
    static let sidebarSelected = font(14, weight: .medium)
    static let sidebarHeader = font(12, weight: .medium)

    // MARK: Content

    /// Result text, composer input, error copy.
    static let body = font(13)
    static let bodyMedium = font(13, weight: .medium)
    /// Long-form result text (AI Search and the diff / vault preview). One step
    /// above `body`. A +14pt jump would overflow the 420pt panel.
    static let resultBody = font(14)
    static let resultBodyBold = font(14, weight: .semibold)
    /// Markdown heading scale for search answers and vault preview.
    static let heading1 = font(22, weight: .bold)
    static let heading2 = font(18, weight: .semibold)
    static let heading3 = font(16, weight: .semibold)
    /// Row captions and secondary list lines.
    static let footnote = font(12)
    static let footnoteMedium = font(12, weight: .medium)
    static let footnoteSemibold = font(12, weight: .semibold)
    /// Panel chips, provenance, notices. The smallest legible size we ship.
    static let caption = font(11)
    static let captionMedium = font(11, weight: .medium)
    static let captionSemibold = font(11, weight: .semibold)

    static let mono = Font.system(size: 13, design: .monospaced)
}
