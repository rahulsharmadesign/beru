import SwiftUI

/// The button system. Pill-first: 32 default, 28 small, no large.
/// Primary is the 170° accent gradient; default is an outlined hairline
/// pill (no gray fill); inline is text only. One slab only — no Liquid
/// Glass refraction.
struct EnhancifyButton: View {
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
        /// The panel, where a 480pt width has to hold several actions. 28.
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
    /// Full-width pill for the menu-bar extra. Off by default so Settings
    /// and onboarding keep hugging their label.
    var expands: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(role: role, action: action) { label }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .fixedSize(horizontal: !expands, vertical: true)
            .frame(maxWidth: expands ? .infinity : nil)
            .opacity(enabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
.enhancifyHoverEase(isHovered)
    }

    @ViewBuilder
    private var label: some View {
        switch variant {
        case .inline:
            Text(title)
                .font(EnhancifyType.footnote)
                .foregroundStyle(role == .destructive ? EnhancifyColor.destructive : EnhancifyColor.textSecondary)
                .padding(.horizontal, EnhancifySpace.xs)
                .padding(.vertical, EnhancifySpace.xxs)
                .background {
                    EnhancifyRadius.shape(EnhancifyRadius.sm)
                        .fill(isHovered ? EnhancifyColor.hoverFill : .clear)
                }
        case .primary, .pill:
            capsuleLabel
        }
    }

    private var capsuleLabel: some View {
        HStack(spacing: EnhancifySpace.xxs) {
            if let leadingIcon {
                EnhancifyIcon(name: leadingIcon, size: iconSize)
            }
            Text(title)
                .font(font)
                .lineLimit(1)
            if let trailingIcon {
                EnhancifyIcon(name: trailingIcon, size: iconSize)
            }
        }
        .foregroundStyle(isFilled ? EnhancifyColor.onAccent : foreground)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: expands ? .infinity : nil)
        .frame(height: height)
        .background {
            Capsule()
                .fill(fill)
                .overlay {
                    if !isFilled {
                        Capsule().strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
                    }
                }
        }
    }

    private var isFilled: Bool { variant == .primary || isActive }

    private var foreground: Color {
        if role == .destructive { return EnhancifyColor.destructive }
        return EnhancifyColor.textPrimary
    }

    private var fill: AnyShapeStyle {
        if isFilled {
            if !enabled { return AnyShapeStyle(EnhancifyColor.accent.opacity(0.45)) }
            return AnyShapeStyle(EnhancifyColor.accentGradient)
        }
        if isHovered && enabled { return AnyShapeStyle(EnhancifyColor.hoverFill) }
        return AnyShapeStyle(Color.clear)
    }

    private var font: Font {
        switch size {
        case .large: return EnhancifyType.control
        case .regular: return EnhancifyType.control
        case .compact: return EnhancifyType.footnote
        }
    }

    /// Haze pill height. 32 default, 28 compact, large capped at 32.
    private var height: CGFloat {
        switch size {
        case .large, .regular: return EnhancifyMetrics.pillHeight
        case .compact: return EnhancifyMetrics.pillHeightSm
        }
    }

    /// 16 across the app; compact inside the dense 28pt pill.
    private var iconSize: CGFloat {
        switch size {
        case .large, .regular: return EnhancifyMetrics.iconSize
        case .compact: return EnhancifyMetrics.iconSizeCompact
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .large: return EnhancifySpace.lg
        case .regular: return EnhancifySpace.md
        case .compact: return EnhancifySpace.sm
        }
    }
}

/// Icon-only button. `help` is required so an icon never ships without a name
/// for VoiceOver and the hover tooltip.
struct EnhancifyIconButton: View {
    let icon: String
    var size: CGFloat = 16
    /// Hit target. Use `EnhancifyMetrics.hitTargetCompact` inside dense list rows.
    var frameSize: CGFloat = EnhancifyMetrics.hitTarget
    var enabled: Bool = true
    var tint: Color?
    let help: String
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.enhancifyParentHovered) private var parentHovered

    private var hovered: Bool { enabled && (isHovered || parentHovered) }

    var body: some View {
        Button(action: action) {
            EnhancifyIcon(name: icon, size: size)
                .foregroundStyle(tint ?? EnhancifyColor.textPrimary)
                .frame(width: frameSize, height: frameSize)
                .background {
                    EnhancifyRadius.shape(EnhancifyRadius.sm)
                        .fill(hovered ? EnhancifyColor.hoverFill : .clear)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .fixedSize()
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(help)
        .onHover { isHovered = $0 }
        .enhancifyHoverEase(hovered)
        .enhancifyHoverHelp(help, isVisible: hovered && !parentHovered)
    }
}
