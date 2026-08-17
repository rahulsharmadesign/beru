import SwiftUI

/// Sums the natural height of the panel's sections so the window can size to
/// its content. Additive because each section reports independently — the
/// result area reports the height of the text *inside* its scroll view, which
/// is the unclamped height the window would need to show it all.
struct PanelHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

extension View {
    func contributesPanelHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: PanelHeightKey.self, value: proxy.size.height)
            }
        )
    }
}
