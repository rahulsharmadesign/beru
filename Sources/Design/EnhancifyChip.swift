import SwiftUI

/// Haze chip: dense glyph + caption on an outlined pill. Non-interactive
/// decoration for feature hints and metadata rows; actions use `EnhancifyButton`.
struct EnhancifyChip: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: EnhancifySpace.xxs) {
            EnhancifyIcon(name: icon, size: EnhancifyMetrics.iconSizeDense)
            Text(title)
                .font(EnhancifyType.footnote)
        }
        .foregroundStyle(EnhancifyColor.textSecondary)
        .lineLimit(1)
        .padding(.horizontal, EnhancifySpace.xs)
        .frame(height: EnhancifyMetrics.chipHeight)
        .background {
            Capsule()
                .fill(Color.clear)
                .overlay {
                    Capsule().strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
                }
        }
    }
}

/// Haze kbd chip: monospaced caption in a hairline well. `.onAccent` sits on
/// the accent gradient (menu footer); `.neutral` is outlined on canvas.
struct EnhancifyKbd: View {
    enum Tone { case neutral, onAccent }
    let text: String
    var tone: Tone = .neutral

    var body: some View {
        Text(text)
            .font(EnhancifyType.monoCaption)
            .foregroundStyle(foreground)
            .padding(.horizontal, EnhancifySpace.xs)
            .padding(.vertical, EnhancifySpace.hair)
            .background {
                EnhancifyRadius.shape(EnhancifyRadius.sm)
                    .fill(fill)
                    .overlay {
                        EnhancifyRadius.shape(EnhancifyRadius.sm)
                            .strokeBorder(stroke, lineWidth: EnhancifyMetrics.hairline)
                    }
            }
    }

    private var foreground: Color {
        tone == .onAccent ? EnhancifyColor.onAccent.opacity(0.85) : EnhancifyColor.textSecondary
    }

    private var fill: Color {
        tone == .onAccent ? EnhancifyColor.onAccent.opacity(0.16) : Color.clear
    }

    private var stroke: Color {
        tone == .onAccent ? EnhancifyColor.onAccent.opacity(0.25) : EnhancifyColor.strongBorder
    }
}
