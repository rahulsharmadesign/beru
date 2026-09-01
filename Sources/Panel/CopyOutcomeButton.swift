import SwiftUI

/// Copy control that swaps to a green check + "Copied", matching the CSS
/// stacked-icon morph (`opacity` 0.2s, scale `cubic-bezier(0.34, 1.56, 0.64, 1)`).
struct CopyOutcomeButton: View {
    var copied: Bool
    var variant: BeruButton.Variant
    @Bindable private var a11y = AccessibilityPreferences.shared

    var body: some View {
        HStack(spacing: BeruSpace.xxs) {
            iconStack
            Text(copied ? "Copied" : "Copy")
                .font(BeruType.footnote)
                .lineLimit(1)
                .foregroundStyle(labelColor)
        }
        .padding(.horizontal, BeruSpace.sm)
        .padding(.vertical, BeruSpace.xxs)
        .background {
            Capsule()
                .fill(fill)
                .overlay {
                    if !isFilled {
                        Capsule().strokeBorder(BeruColor.border, lineWidth: 1)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copied ? "Copied" : "Copy")
    }

    private var iconStack: some View {
        ZStack {
            BeruIcon(name: "square.on.square", size: 12)
                .foregroundStyle(labelColor)
                .opacity(copied ? 0 : 1)
                .animation(opacityMorph, value: copied)
                .scaleEffect(copied ? 0.5 : 1)
                .animation(scaleMorph, value: copied)
            BeruIcon(name: "checkmark", size: 12)
                .foregroundStyle(BeruColor.positive)
                .opacity(copied ? 1 : 0)
                .animation(opacityMorph, value: copied)
                .scaleEffect(copied ? 1 : 0.5)
                .animation(scaleMorph, value: copied)
        }
        .frame(width: 12, height: 12)
    }

    private var opacityMorph: Animation {
        a11y.reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.2)
    }

    /// CSS `cubic-bezier(0.34, 1.56, 0.64, 1)` — slight overshoot on the check.
    private var scaleMorph: Animation {
        a11y.reduceMotion
            ? .easeOut(duration: 0.12)
            : .timingCurve(0.34, 1.56, 0.64, 1, duration: 0.3)
    }

    private var isFilled: Bool { variant == .primary }

    private var labelColor: Color {
        isFilled ? BeruColor.onAccent : BeruColor.textPrimary
    }

    private var fill: Color {
        isFilled ? BeruColor.accent : Color.clear
    }
}
