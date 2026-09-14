import SwiftUI

/// Hover helper in the ChatGPT "Copy response" shape: a solid capsule
/// parked above the control. Not a glass lens, not a native tooltip.
struct BeruHelpPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BeruType.controlMedium)
            .foregroundStyle(BeruColor.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, BeruSpace.md)
            .frame(height: BeruMetrics.pillHeight)
            .background {
                Capsule()
                    .fill(BeruColor.panelSolid)
                    .overlay {
                        Capsule().strokeBorder(
                            BeruColor.strongBorder,
                            lineWidth: BeruMetrics.hairline
                        )
                    }
                    .shadow(
                        color: BeruColor.liftShadow,
                        radius: BeruSpace.xs,
                        y: BeruSpace.hair
                    )
            }
            .fixedSize()
            .allowsHitTesting(false)
    }
}

private struct BeruHoverHelp: ViewModifier {
    let text: String
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                BeruHelpPill(text: text)
                    .offset(y: -BeruMetrics.helpPillOffset)
                    .opacity(isVisible && !text.isEmpty ? 1 : 0)
            }
    }
}

extension View {
    /// Paints `BeruHelpPill` above this view while `isVisible`. Does not
    /// change layout height.
    func beruHoverHelp(_ text: String, isVisible: Bool) -> some View {
        modifier(BeruHoverHelp(text: text, isVisible: isVisible))
    }

    @ViewBuilder
    func beruNativeHelp(_ text: String, enabled: Bool) -> some View {
        if enabled {
            self.help(text)
        } else {
            self
        }
    }
}
