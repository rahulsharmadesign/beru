import SwiftUI

/// Dashboard-flavored names for the scale in `BeruType`.
///
/// Aliases, not a second scale. New code should reach for `BeruType`; this
/// keeps the existing dashboard call sites readable while there is one
/// definition behind them.
enum BeruSans {
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        BeruType.font(size, weight: weight)
    }

    static let pageTitle = BeruType.pageTitle
    static let pageSubtitle = BeruType.pageSubtitle
    static let section = BeruType.section
    static let rowTitle = BeruType.rowTitle
    static let rowCaption = BeruType.footnote
    static let sidebar = BeruType.sidebar
    static let sidebarSelected = BeruType.sidebarSelected
    static let sidebarHeader = BeruType.sidebarHeader
    static let control = BeruType.control
    static let search = BeruType.search
    static let footnote = BeruType.footnote
    static let mono = BeruType.mono
}
