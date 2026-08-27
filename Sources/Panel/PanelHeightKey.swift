import SwiftUI

/// Ideal panel layout heights. Window size uses `ideal` until the 75% viewport
/// cap; past that only the result band scrolls and chrome stays pinned.
struct PanelLayoutHeights: Equatable {
    var chrome: CGFloat = 0
    var result: CGFloat = 0

    var ideal: CGFloat { chrome + result }
}

enum PanelHeightBand: Hashable {
    case chromeTop
    case chromeBottom
    case result
}

struct PanelBandHeightKey: PreferenceKey {
    static let defaultValue: [PanelHeightBand: CGFloat] = [:]

    static func reduce(value: inout [PanelHeightBand: CGFloat], nextValue: () -> [PanelHeightBand: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: max)
    }
}

extension View {
    /// Publishes the receiver's height into a layout band.
    func reportsPanelBand(_ band: PanelHeightBand) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: PanelBandHeightKey.self, value: [band: proxy.size.height])
            }
        )
    }
}
