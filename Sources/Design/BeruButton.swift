import SwiftUI

/// The button system.
///
/// Beru shipped four button languages at once: capsule pills in Settings,
/// system `.borderedProminent` in the panel, rounded rectangles in the menu
/// bar, and hand-rolled circles for send and dictation. Two shapes now cover
/// every case — this capsule/text button and `BeruIconButton`.
struct BeruButton: View {
    enum Variant {
        /// Filled with the accent. One per view, for the primary action.
        case primary
        /// Bordered capsule. The default.
        case pill
        /// Text only, for actions packed into a tight row.
        case inline
    }

    enum Size {
        /// Onboarding, where one CTA carries the step.
        case large
        /// Settings and dashboard.
        case regular
        /// The panel, where a 420pt width has to hold several actions.
        case compact
    }

    let title: String
    var variant: Variant = .pill
    var size: Size = .regular
    var leadingIcon: String?
    var trailingIcon: String?
    /// Renders like `.primary` while keeping the pill's layout. For controls
    /// that represent an on/off choice.
    var isActive: Bool = false
    var enabled: Bool = true
    var role: ButtonRole?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(role: role, action: action) {
            label
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .fixedSize()
        .opacity(enabled ? 1 : 0.45)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var label: some View {
        switch variant {
        case .inline:
            Text(title)
                .font(BeruType.footnote)
                .foregroundStyle(role == .destructive ? BeruColor.destructive : BeruColor.textSecondary)
                .padding(.horizontal, BeruSpace.xs)
                .padding(.vertical, BeruSpace.xxs)
                .background {
                    BeruRadius.shape(BeruRadius.sm)
                        .fill(isHovered ? BeruColor.hoverFill : .clear)
                }
        case .primary, .pill:
            capsuleLabel
        }
    }

    private var capsuleLabel: some View {
        HStack(spacing: BeruSpace.xxs) {
            if let leadingIcon {
                BeruIcon(name: leadingIcon, size: iconSize)
            }
            Text(title)
                .font(font)
                .lineLimit(1)
            if let trailingIcon {
                BeruIcon(name: trailingIcon, size: iconSize)
            }
        }
        .foregroundStyle(isFilled ? BeruColor.onAccent : BeruColor.textPrimary)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background {
            Capsule()
                .fill(fill)
                .overlay {
                    if !isFilled {
                        Capsule().strokeBorder(BeruColor.border, lineWidth: 1)
                    }
                }
        }
    }

    private var isFilled: Bool { variant == .primary || isActive }

    private var fill: Color {
        guard isFilled else {
            return isHovered && enabled ? BeruColor.hoverFill : .clear
        }
        if !enabled { return BeruColor.accent.opacity(0.45) }
        return isHovered ? BeruColor.accent.opacity(0.88) : BeruColor.accent
    }

    private var font: Font {
        switch size {
        case .large: return BeruType.control
        case .regular: return BeruType.control
        case .compact: return BeruType.footnote
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .large, .regular: return 14
        case .compact: return 12
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .large: return BeruSpace.xl
        case .regular: return BeruSpace.md
        case .compact: return BeruSpace.sm
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .large: return BeruSpace.sm
        case .regular: return BeruSpace.xs
        case .compact: return BeruSpace.xxs
        }
    }
}

/// Icon-only button. `help` is required so an icon never ships without a name
/// for VoiceOver and the hover tooltip.
struct BeruIconButton: View {
    let icon: String
    var size: CGFloat = 16
    /// Hit target. Use `BeruMetrics.hitTargetCompact` inside dense list rows.
    var frameSize: CGFloat = BeruMetrics.hitTarget
    var enabled: Bool = true
    var tint: Color?
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            BeruIcon(name: icon, size: size)
                .foregroundStyle(tint ?? BeruColor.textPrimary)
                .frame(width: frameSize, height: frameSize)
                .background {
                    BeruRadius.shape(BeruRadius.sm)
                        .fill(isHovered && enabled ? BeruColor.hoverFill : .clear)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .fixedSize()
        .opacity(enabled ? 1 : 0.45)
        .help(help)
        .accessibilityLabel(help)
        .onHover { isHovered = $0 }
    }
}
