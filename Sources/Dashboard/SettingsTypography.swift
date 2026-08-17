import SwiftUI

/// system-ui stack — matches Unsloth settings reference.
enum BeruSans {
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static let pageTitle = font(20, weight: .semibold)
    static let pageSubtitle = font(13)
    static let section = font(14, weight: .semibold)
    static let rowTitle = font(14)
    static let rowCaption = font(12)
    static let sidebar = font(14)
    static let sidebarSelected = font(14, weight: .medium)
    static let sidebarHeader = font(12, weight: .medium)
    static let control = font(14)
    static let search = font(14)
    static let footnote = font(12)
    static let mono = Font.system(size: 13, design: .monospaced)
}
