import SwiftUI

/// Hover helper in the ChatGPT "Copy response" shape: a solid capsule
/// parked above the control. Not a glass lens, not a native tooltip.
struct BeruHelpPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BeruType.captionMedium)
            .foregroundStyle(BeruColor.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, BeruSpace.xs)
            .frame(height: BeruMetrics.metapillHeight)
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

/// Which way a hover helper pill grows out of its control.
///
/// Centered is the default. A centered pill is wider than the control it
/// describes, so half of the difference hangs past the control's leading
/// edge. For a control parked on the panel's leading inset that lands outside
/// the window, and the clipping hosting view shears the cap off — which is
/// what the Replace footer action did. Controls on an edge opt into
/// `.leading` / `.trailing` so the pill grows inward instead.
enum BeruHelpAnchor {
    case center
    case leading
    case trailing

    var overlayAlignment: Alignment {
        switch self {
        case .center: return .top
        case .leading: return .topLeading
        case .trailing: return .topTrailing
        }
    }
}

private struct BeruHoverHelp: ViewModifier {
    let text: String
    let isVisible: Bool
    var anchor: BeruHelpAnchor = .center

    func body(content: Content) -> some View {
        content
            .overlay(alignment: anchor.overlayAlignment) {
                BeruHelpPill(text: text)
                    .offset(y: -BeruMetrics.helpPillOffset)
                    .opacity(isVisible && !text.isEmpty ? 1 : 0)
            }
    }
}

extension View {
    /// Paints `BeruHelpPill` above this view while `isVisible`. Does not
    /// change layout height. Pass `anchor` for a control on a window edge.
    func beruHoverHelp(
        _ text: String,
        isVisible: Bool,
        anchor: BeruHelpAnchor = .center
    ) -> some View {
        modifier(BeruHoverHelp(text: text, isVisible: isVisible, anchor: anchor))
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
