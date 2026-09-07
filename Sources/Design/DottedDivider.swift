import SwiftUI

/// Haze dotted rule: 1pt round dots separating stacked results on the plate.
/// Stronger than a hairline so the rhythm reads at a glance, quieter than a
/// solid rule so it never competes with content. Drawn as a single line —
/// stroking a rectangle outline dashes around its perimeter and zigzags.
struct DottedDivider: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let y = geometry.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }
            .stroke(
                BeruColor.strongBorder,
                style: StrokeStyle(
                    lineWidth: BeruMetrics.hairline,
                    lineCap: .round,
                    dash: [BeruSpace.hair, BeruSpace.xxs]
                )
            )
        }
        .frame(height: BeruMetrics.hairline)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
