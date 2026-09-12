import SwiftUI

/// Haze dashed spinner. Tint follows the selected primary
/// (`BeruColor.accent`) unless overridden.
///
/// Two superposed motions keep it from reading as a ticking wheel: the ring
/// rotates at one rate while the dash pattern drifts through it at a slower
/// one, so gaps appear to travel around the circumference. Computed per frame
/// from wall-clock time — frame-rate independent, and trivially pausable.
struct BeruLoader: View {
    var tint: Color = BeruColor.accent
    var size: CGFloat = BeruMetrics.loaderSize
    var lineWidth: CGFloat = BeruMetrics.loaderStroke

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
            Circle()
                .stroke(
                    tint,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        dash: [BeruMetrics.loaderDashOn, BeruMetrics.loaderDashGap],
                        dashPhase: reduceMotion ? 0 : dashDrift(at: context.date)
                    )
                )
                .rotationEffect(.degrees(reduceMotion ? 0 : spinAngle(at: context.date)))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Loading")
    }

    /// Compact ring for the 40pt send / 28pt Replace controls.
    static func compact(tint: Color = BeruColor.accent) -> BeruLoader {
        BeruLoader(
            tint: tint,
            size: BeruMetrics.loaderSizeCompact,
            lineWidth: BeruMetrics.loaderStrokeCompact
        )
    }

    private func spinAngle(at date: Date) -> Double {
        let period = 0.9
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return t * 360
    }

    /// The dash pattern slides backwards more slowly than the ring spins
    /// forward, so individual strokes appear to breathe while the wheel turns.
    private func dashDrift(at date: Date) -> CGFloat {
        let on = BeruMetrics.loaderDashOn
        let gap = BeruMetrics.loaderDashGap
        let segment = on + gap
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(
            dividingBy: BeruMetrics.loaderDriftPeriod
        ) / BeruMetrics.loaderDriftPeriod
        return CGFloat(-t * segment)
    }
}
