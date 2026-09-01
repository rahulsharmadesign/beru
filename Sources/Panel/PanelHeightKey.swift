import SwiftUI

/// Ideal panel layout heights. Window size uses `ideal` until the 75% viewport
/// cap; past that only the result band scrolls and chrome stays pinned.
struct PanelLayoutHeights: Equatable {
    var chrome: CGFloat = 0
    var result: CGFloat = 0

    var ideal: CGFloat { chrome + result }

    /// Nil when a chrome band is still missing. Those frames used to size the
    /// window to ~40pt, then `clipsToBounds` sheared the close strip and composer.
    static func fromBands(top: CGFloat, bottom: CGFloat, result: CGFloat) -> PanelLayoutHeights? {
        // Missing GeometryReaders report 0 and used to size the window to ~40pt.
        // Any real chrome band is enough; the controller still rejects a total
        // below minimumChromeHeight.
        guard top > 1, bottom > 1 else { return nil }
        let chrome = PanelMetrics.moduleInset * 2
            + top
            + bottom
            + PanelMetrics.moduleSpacing * 2
        return PanelLayoutHeights(chrome: chrome, result: result)
    }

    /// How a shrink should land. Grow is always immediate and unanimated.
    /// Tab changes skip the debounce and the window animator so close / composer
    /// do not sit at the old Y for 0.3s. Streaming layout jitter still debounces;
    /// a shrink during a stream is dropped until `streamingDidEnd` flushes.
    enum ShrinkBehavior: Equatable {
        case applyNowUnanimated
        case debounceAnimated
        case skip
    }

    static func shrinkBehavior(isTabChange: Bool, isStreaming: Bool) -> ShrinkBehavior {
        if isTabChange { return .applyNowUnanimated }
        if isStreaming { return .skip }
        return .debounceAnimated
    }

    /// Picks chrome and result that are safe to size the window from.
    /// Undersized chrome (inset-only) keeps the last real chrome; a missing
    /// result keeps the last real result so a tab swap cannot collapse the window.
    static func resolved(
        layout: PanelLayoutHeights,
        lastChrome: CGFloat,
        lastResult: CGFloat
    ) -> (chrome: CGFloat, result: CGFloat, lastChrome: CGFloat, lastResult: CGFloat)? {
        let chrome: CGFloat
        var storedChrome = lastChrome
        if layout.chrome >= PanelMetrics.minimumChromeHeight {
            storedChrome = layout.chrome
            chrome = layout.chrome
        } else if lastChrome >= PanelMetrics.minimumChromeHeight {
            chrome = lastChrome
        } else {
            return nil
        }

        let result: CGFloat
        var storedResult = lastResult
        if layout.result > 1 {
            storedResult = layout.result
            result = layout.result
        } else if lastResult > 1 {
            result = lastResult
        } else {
            result = layout.result
        }
        return (chrome, result, storedChrome, storedResult)
    }
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
    /// Publishes the receiver's unconstrained height into a layout band.
    ///
    /// A `GeometryReader` background reports the size the parent offered. In the
    /// seed-height window that is leftover space, so `chrome + result` never
    /// exceeds the current frame and the window never grows. This asks
    /// `sizeThatFits` with a nil height, which is independent of the proposal.
    func reportsPanelBand(_ band: PanelHeightBand) -> some View {
        modifier(ReportIdealBandModifier(band: band))
    }
}

private struct ReportIdealBandModifier: ViewModifier {
    var band: PanelHeightBand
    @State private var idealHeight: CGFloat = 0

    func body(content: Content) -> some View {
        IdealHeightLayout(onIdealHeight: { height in
            guard abs(height - idealHeight) > 0.5 else { return }
            idealHeight = height
        }) {
            content
        }
        .preference(
            key: PanelBandHeightKey.self,
            value: idealHeight > 1 ? [band: idealHeight] : [:]
        )
    }
}

/// Reports the height the child wants at the offered width with no height cap.
///
/// Compresses when the parent is shorter than ideal (viewport-capped
/// ScrollView). Never grows past ideal — leftover window height after a tall
/// tab used to stretch the result and pin the composer to the old bottom.
private struct IdealHeightLayout: Layout {
    var onIdealHeight: (CGFloat) -> Void

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        DispatchQueue.main.async { onIdealHeight(ideal.height) }
        if let proposedHeight = proposal.height, proposedHeight + 0.5 < ideal.height {
            return child.sizeThatFits(proposal)
        }
        return CGSize(width: proposal.width ?? ideal.width, height: ideal.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        let ideal = child.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        let height = bounds.height + 0.5 < ideal.height ? bounds.height : ideal.height
        child.place(
            at: bounds.origin,
            proposal: ProposedViewSize(width: bounds.width, height: height)
        )
    }
}
