import SwiftUI

/// The button system. Haze pill-first: 32 default, 28 small, no large.
/// Primary is the 170° accent gradient; default is the surface-2 hairline
/// pill; inline is text only. One slab only — no Liquid Glass refraction.
struct BeruButton: View {
    enum Variant {
        /// Filled with the accent gradient. One per view, for the primary action.
        case primary
        /// Hairline pill. The default.
        case pill
        /// Text only, for actions packed into a tight row.
        case inline
    }

    enum Size {
        /// Capped at 32. Former onboarding large maps to the Haze default.
        case large
        /// Settings and dashboard. 32.
        case regular
        /// The panel, where a 420pt width has to hold several actions. 28.
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
        Button(role: role, action: action) { label }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .fixedSize()
            .opacity(enabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
.beruHoverEase(isHovered)
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
        .foregroundStyle(isFilled ? BeruColor.onAccent : foreground)
        .frame(height: height)
        .padding(.horizontal, horizontalPadding)
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

    private var foreground: Color {
        if role == .destructive { return BeruColor.destructive }
        return BeruColor.textPrimary
    }

    private var fill: AnyShapeStyle {
        if isFilled {
            if !enabled { return AnyShapeStyle(BeruColor.accent.opacity(0.45)) }
            return AnyShapeStyle(BeruColor.accentGradient)
        }
        if isHovered && enabled { return AnyShapeStyle(BeruColor.hoverFill) }
        return AnyShapeStyle(BeruColor.subtleFill)
    }

    private var font: Font {
        switch size {
        case .large: return BeruType.control
        case .regular: return BeruType.control
        case .compact: return BeruType.footnote
        }
    }

    /// Haze pill height. 32 default, 28 compact, large capped at 32.
    private var height: CGFloat {
        switch size {
        case .large, .regular: return BeruMetrics.pillHeight
        case .compact: return BeruMetrics.pillHeightSm
        }
    }

    /// 16 across the app; 14 inside the dense 28pt compact pill.
    private var iconSize: CGFloat {
        switch size {
        case .large, .regular: return BeruMetrics.iconSize
        case .compact: return 14
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .large: return BeruSpace.lg
        case .regular: return BeruSpace.md
        case .compact: return BeruSpace.sm
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
.beruHoverEase(isHovered)
    }
}
