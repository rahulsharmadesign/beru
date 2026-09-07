import SwiftUI

/// The corner radius scale, and the one curve style.
///
/// Haze is pill-first: 8 / 12 / 16 / 22 / 28, panel 28 on macOS.
enum BeruRadius {
    /// Chips, kbd, small badges, menu rows.
    static let sm: CGFloat = 8
    /// Menu floats, inputs in square mode.
    static let sm2: CGFloat = 12
    /// The default. Rows, cards, wells, panel modules.
    static let md: CGFloat = 16
    /// Composer and other content-bearing containers, floats.
    static let lg: CGFloat = 22
    /// The panel window and dialogs.
    static let xl: CGFloat = 28

    /// Always `.continuous`. Do not pass `.circular`.
    static func shape(_ radius: CGFloat = md) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
