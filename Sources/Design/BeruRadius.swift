import SwiftUI

/// The corner radius scale, and the one curve style.
///
/// Radius 10 used to be declared in six separate places and the panel drew its
/// cards with `.circular` while Settings drew the same metaphor with
/// `.continuous`, so identical cards had visibly different corners.
enum BeruRadius {
    /// Icon buttons, inline chips, small badges.
    static let sm: CGFloat = 6
    /// The default. Rows, cards, wells, panel modules.
    static let md: CGFloat = 10
    /// Composer and other content-bearing containers.
    static let lg: CGFloat = 16
    /// The panel window itself.
    static let xl: CGFloat = 20

    /// Always `.continuous`. Do not pass `.circular`.
    static func shape(_ radius: CGFloat = md) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
