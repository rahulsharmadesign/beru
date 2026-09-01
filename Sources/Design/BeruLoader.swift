import SwiftUI

/// CSS ring: 4pt track, accent on the top-right half, 0.8s linear spin.
/// Tint follows the selected primary (`BeruColor.accent`) unless overridden.
struct BeruLoader: View {
    var tint: Color = BeruColor.accent
    var size: CGFloat = BeruMetrics.loaderSize
    var lineWidth: CGFloat = BeruMetrics.loaderStroke

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
            ring
                .rotationEffect(.degrees(reduceMotion ? 0 : spinAngle(at: context.date)))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Loading")
    }

    /// Compact ring for the 28pt send / Replace controls.
    static func compact(tint: Color = BeruColor.accent) -> BeruLoader {
        BeruLoader(
            tint: tint,
            size: BeruMetrics.loaderSizeCompact,
            lineWidth: BeruMetrics.loaderStrokeCompact
        )
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(BeruColor.loaderTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
        }
    }

    private func spinAngle(at date: Date) -> Double {
        let period = 0.8
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return t * 360
    }
}
