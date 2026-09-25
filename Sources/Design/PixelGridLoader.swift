import SwiftUI

// Pixel-grid loading furniture for long-running work: a 3×3 field of tiny
// cells whose staggered delays draw a wavefront (chevron sweep, or a comet
// lapping the perimeter), a shimmering label, and a live elapsed timer.
// Same contract as EnhancifyLoader: computed per frame from wall-clock time,
// frame-rate independent, Reduce Motion freezes to the dim state.

/// Which cells lead the wave.
enum PixelGridVariant {
    /// Square cells; the chevron drives right, two fronts always in flight.
    case drive
    /// The Drive wavefront with circular cells.
    case dots
    /// A comet lapping the perimeter; the center cell stays dim.
    case orbit

    fileprivate var round: Bool { self == .dots }

    /// Per-cell pulse delay in seconds; nil cells never pulse.
    fileprivate func delays() -> [Double?] {
        switch self {
        case .drive, .dots:
            // (column + |row - 1|) * step: the middle row leads, top and
            // bottom rows chase — a sideways chevron sweeping right.
            return (0..<9).map { index in
                let row = index / 3
                let column = index % 3
                return Double(column + abs(row - 1)) * EnhancifyMetrics.pixelStep
            }
        case .orbit:
            let ring: [Int] = [0, 1, 2, 5, 8, 7, 6, 3]
            return (0..<9).map { index in
                guard let lap = ring.firstIndex(of: index) else { return nil }
                return Double(lap) * EnhancifyMetrics.pixelOrbitStep
            }
        }
    }
}

/// The 3×3 cell field. Roughly glyph-sized: 14pt across.
struct PixelGridLoader: View {
    var variant: PixelGridVariant = .drive
    var tint: Color = EnhancifyColor.textSecondary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let delays = variant.delays()
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
            VStack(spacing: EnhancifyMetrics.pixelGap) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: EnhancifyMetrics.pixelGap) {
                        ForEach(0..<3, id: \.self) { column in
                            let index = row * 3 + column
                            CircleCapCell(round: variant.round, tint: tint)
                                .opacity(cellOpacity(delays[index], at: context.date))
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func cellOpacity(_ delay: Double?, at date: Date) -> Double {
        guard let delay else { return EnhancifyMetrics.pixelDimIdle }
        if reduceMotion { return EnhancifyMetrics.pixelDimRest }
        let cycle = EnhancifyMetrics.pixelCycle
        let phase = (date.timeIntervalSinceReferenceDate - delay)
            .truncatingRemainder(dividingBy: cycle) / cycle
        // Half-cosine pulse: dim at the seam, full brightness mid-cycle.
        let pulse = 0.5 - 0.5 * cos(phase * 2 * .pi)
        return EnhancifyMetrics.pixelDimRest + (1 - EnhancifyMetrics.pixelDimRest) * pulse
    }
}

private struct CircleCapCell: View {
    let round: Bool
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: round ? EnhancifyMetrics.pixelCell / 2 : 1, style: .continuous)
            .fill(tint)
            .frame(width: EnhancifyMetrics.pixelCell, height: EnhancifyMetrics.pixelCell)
    }
}

/// A light band sweeping across the label, masked to the glyphs.
struct ShimmerLabel: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(EnhancifyType.footnoteMedium)
            .foregroundStyle(EnhancifyColor.textSecondary)
            .overlay {
                if !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        GeometryReader { geo in
                            let sweep = geo.size.width + EnhancifySpace.xl
                            LinearGradient(
                                colors: [.clear, EnhancifyColor.textPrimary, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: EnhancifySpace.xl)
                            .offset(x: offset(at: context.date, sweep: sweep) - EnhancifySpace.xl)
                        }
                    }
                    .mask {
                        Text(text)
                            .font(EnhancifyType.footnoteMedium)
                    }
                }
            }
    }

    private func offset(at date: Date, sweep: Double) -> Double {
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: EnhancifyMetrics.shimmerPeriod) / EnhancifyMetrics.shimmerPeriod
        return t * sweep
    }
}

/// Live elapsed time since first appearance: "12.3s", then "1m 04.5s".
/// Tabular figures so the digits never shift width while ticking.
struct ElapsedTimer: View {
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            Text(Self.format(context.date.timeIntervalSince(startedAt)))
                .font(EnhancifyType.footnote.monospacedDigit())
                .foregroundStyle(EnhancifyColor.textTertiary)
        }
    }

    static func format(_ interval: Double) -> String {
        if interval < 60 {
            return String(format: "%.1fs", interval)
        }
        return String(format: "%dm %.1fs", Int(interval) / 60, interval.truncatingRemainder(dividingBy: 60))
    }
}

/// The composed loading line: pixel grid + shimmering label + elapsed time.
/// This is the long-running-work moment (a local model thinking).
struct PixelLoadingState: View {
    var label: String
    var variant: PixelGridVariant = .drive

    var body: some View {
        HStack(spacing: EnhancifySpace.sm) {
            PixelGridLoader(variant: variant)
            ShimmerLabel(text: label)
            ElapsedTimer()
        }
    }
}
