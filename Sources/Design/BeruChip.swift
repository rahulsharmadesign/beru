import SwiftUI

/// Haze chip: dense glyph + caption on an outlined pill. Non-interactive
/// decoration for feature hints and metadata rows; actions use `BeruButton`.
struct BeruChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: BeruSpace.xxs) {
            BeruIcon(name: icon, size: BeruMetrics.iconSizeDense)
            Text(title)
                .font(BeruType.footnote)
        }
        .foregroundStyle(BeruColor.textSecondary)
        .lineLimit(1)
        .padding(.horizontal, BeruSpace.xs)
        .frame(height: BeruMetrics.chipHeight)
        .background {
            Capsule()
                .fill(Color.clear)
                .overlay {
                    Capsule().strokeBorder(BeruColor.strongBorder, lineWidth: BeruMetrics.hairline)
                }
        }
    }
}

/// Haze kbd chip: monospaced caption in a hairline well. `.onAccent` sits on
/// the accent gradient (menu footer); `.neutral` is outlined on canvas.
struct BeruKbd: View {
    enum Tone { case neutral, onAccent }
    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .font(BeruType.monoCaption)
            .foregroundStyle(foreground)
            .padding(.horizontal, BeruSpace.xs)
            .padding(.vertical, BeruSpace.hair)
            .background {
                BeruRadius.shape(BeruRadius.sm)
                    .fill(fill)
                    .overlay {
                        BeruRadius.shape(BeruRadius.sm)
                            .strokeBorder(stroke, lineWidth: BeruMetrics.hairline)
                    }
            }
    }

    private var foreground: Color {
        tone == .onAccent ? BeruColor.onAccent.opacity(0.85) : BeruColor.textSecondary
    }

    private var fill: Color {
        tone == .onAccent ? BeruColor.onAccent.opacity(0.16) : Color.clear
    }

    private var stroke: Color {
        tone == .onAccent ? BeruColor.onAccent.opacity(0.25) : BeruColor.strongBorder
    }
}
