import AppKit
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
    static let section = font(bodySize, weight: .semibold)

    // MARK: Rows and controls

    static let rowTitle = font(bodySize)
    static let control = font(bodySize)
    static let controlMedium = font(bodySize, weight: .medium)
    static let controlSemibold = font(bodySize, weight: .semibold)
    static let search = font(14)
    static let sidebar = font(14)
    static let sidebarSelected = font(14, weight: .medium)
    static let sidebarHeader = font(12, weight: .medium)

    // MARK: Content

    /// Reading size for panel body, controls, and printed results. 15pt,
    /// off the 4pt grid on purpose — the requested app body size.
    static let bodySize: CGFloat = 15
    /// Extra leading so 15pt type sits on a 20pt line.
    static let resultLineSpacing: CGFloat = 5

    static var bodyNSFont: NSFont { .systemFont(ofSize: bodySize) }

    /// Result text, composer input, error copy.
    static let body = font(bodySize)
    static let bodyMedium = font(bodySize, weight: .medium)
    /// Long-form printed text (AI Search, diffs, suggestion bodies).
    static let resultBody = font(bodySize)
    static let resultBodyBold = font(bodySize, weight: .semibold)
    /// Markdown heading scale for search answers and vault preview.
    static let heading1 = font(22, weight: .bold)
    static let heading2 = font(20, weight: .semibold)
    static let heading3 = font(bodySize, weight: .semibold)
    /// Row captions and secondary list lines.
    static let footnote = font(12)
    static let footnoteMedium = font(12, weight: .medium)
    static let footnoteSemibold = font(12, weight: .semibold)
    /// Panel chips, provenance, notices. The smallest legible size we ship.
    static let caption = font(11)
    static let captionMedium = font(11, weight: .medium)
    static let captionSemibold = font(11, weight: .semibold)

    static let mono = Font.system(size: 13, design: .monospaced)
    /// Keyboard-chip mono: the dense floor at monospaced design.
    static let monoCaption = Font.system(size: 12, design: .monospaced)
}

extension View {
    /// Printed panel copy: 15pt body on 20pt leading.
    func beruPrintedText() -> some View {
        font(BeruType.resultBody)
            .lineSpacing(BeruType.resultLineSpacing)
    }
}
