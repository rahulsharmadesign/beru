import SwiftUI

/// A glowing beam that rides the border of a shape — the SwiftUI take on the
/// border-beam effect. A bright arc with a fading tail sweeps the perimeter
/// while a blurred twin underneath blooms onto the surrounding surface.
///
/// Pure overlay: contributes nothing to layout, so surface height contracts
/// are untouched. `active` freezes the beam in place (position preserved),
/// and Reduce Motion hides it entirely.
struct BorderBeam<S: InsettableShape>: View {
    let shape: S
    var palette: BorderBeamPalette = .mono
    var lineWidth: CGFloat = BeruMetrics.beamWidth
    /// Glow bloom, 0-1. Low stays Haze-subtle.
    var strength: Double = 0.4
    var active: Bool = true
    /// Laps to run before stopping. After the last lap the beam holds its
    /// heading and fades out rather than looping forever.
    var loops: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !active)) { context in
                let progress = sweepProgress(at: context.date)
                let ring = shape
                    .inset(by: lineWidth / 2)
                    .strokeBorder(
                        AngularGradient(
                            stops: palette.stops.map { Gradient.Stop(color: $0.color, location: $0.location) },
                            center: .center,
                            angle: .degrees(progress.angle)
                        ),
                        lineWidth: lineWidth
                    )
                ZStack {
                    ring
                        .blur(radius: BeruMetrics.beamGlowBlur * strength)
                        .opacity(strength * progress.opacity)
                    ring
                        .opacity(progress.opacity)
                }
                .onAppear { startedAt = context.date }
            }
            .accessibilityHidden(true)
        }
    }

    /// Angle plus visibility for the moment. Runs `loops` laps; during the
    /// final stretch the beam dissolves as it travels, so it is already gone
    /// when it reaches the end — no visible freeze at the bright head.
    private func sweepProgress(at date: Date) -> (angle: Double, opacity: Double) {
        let start = startedAt ?? date
        let elapsed = date.timeIntervalSince(start)
        let total = BeruMetrics.beamPeriod * loops
        guard elapsed < total else {
            return (360 * loops, 0)
        }
        let angle = elapsed / BeruMetrics.beamPeriod * 360
        let remaining = total - elapsed
        let fadeWindow = BeruMetrics.beamPeriod * 0.4
        let opacity = min(1, remaining / fadeWindow)
        return (angle, opacity)
    }
}

/// The gradient riding the beam. One bright head near the seam with a tail
/// that fades backwards; `colorful` runs three heads so the ring reads
/// prismatic. Colors live here because Design owns every literal.
enum BorderBeamPalette {
    case mono
    case ocean
    case sunset
    case colorful

    @MainActor fileprivate var stops: [(location: Double, color: Color)] {
        switch self {
        case .mono:
            let head = BeruColor.accent
            return [
                (0.0, .clear),
                (0.68, .clear),
                (0.93, head.opacity(0.35)),
                (0.995, head),
                (1.0, .clear),
            ]
        case .ocean:
            return [
                (0.0, .clear),
                (0.68, .clear),
                (0.93, Color(red: 0.05, green: 0.55, blue: 0.85).opacity(0.35)),
                (0.995, Color(red: 0.1, green: 0.8, blue: 1.0)),
                (1.0, .clear),
            ]
        case .sunset:
            return [
                (0.0, .clear),
                (0.68, .clear),
                (0.93, Color(red: 0.95, green: 0.35, blue: 0.35).opacity(0.35)),
                (0.995, Color(red: 1.0, green: 0.55, blue: 0.2)),
                (1.0, .clear),
            ]
        case .colorful:
            return [
                (0.0, Color(red: 0.42, green: 0.38, blue: 0.98)),
                (0.18, Color(red: 0.42, green: 0.38, blue: 0.98).opacity(0.2)),
                (0.30, .clear),
                (0.45, Color(red: 0.1, green: 0.8, blue: 1.0)),
                (0.58, Color(red: 0.1, green: 0.8, blue: 1.0).opacity(0.2)),
                (0.70, .clear),
                (0.85, Color(red: 0.95, green: 0.3, blue: 0.6)),
                (0.96, Color(red: 0.95, green: 0.3, blue: 0.6).opacity(0.2)),
                (1.0, Color(red: 0.42, green: 0.38, blue: 0.98)),
            ]
        }
    }
}
