import SwiftUI

// Reusable dashboard controls. These are design-system components, not
// dashboard screens, which is why they live here rather than next to the pages
// that happen to use them.

// The five button types below are names for `BeruButton` variants, not separate
// implementations. Each used to hand-roll its own capsule, hover state, padding
// and disabled opacity, which is how the app ended up with four button
// languages that drifted apart. Keeping the names means the roughly eighty call
// sites read the same while there is one implementation.

struct SettingsPillButton: View {
    let title: String
    var role: ButtonRole?
    var enabled: Bool = true
    var trailingIcon: String? = nil
    var leadingIcon: String? = nil
    let action: () -> Void

    var body: some View {
        BeruButton(
            title: title,
            variant: .pill,
            leadingIcon: leadingIcon,
            trailingIcon: trailingIcon,
            enabled: enabled,
            role: role,
            action: action
        )
    }
}

struct SettingsPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        BeruButton(
            title: title,
            variant: .primary,
            leadingIcon: icon,
            enabled: enabled,
            action: action
        )
    }
}

struct SettingsTogglePill: View {
    let title: String
    var icon: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        BeruButton(
            title: title,
            variant: .pill,
            leadingIcon: icon,
            isActive: isOn
        ) {
            isOn.toggle()
        }
    }
}

struct SettingsIconButton: View {
    let icon: String
    var size: CGFloat = 16
    /// Tap-target frame. Smaller for icon buttons living inside a compact
    /// row (e.g. a card in a narrow list) rather than a toolbar/footer.
    var frameSize: CGFloat = BeruMetrics.hitTarget
    var enabled: Bool = true
    /// Hover tooltip and VoiceOver name. Required so an icon-only control
    /// never ships without a description of what it does.
    let help: String
    let action: () -> Void

    var body: some View {
        BeruIconButton(
            icon: icon,
            size: size,
            frameSize: frameSize,
            enabled: enabled,
            help: help,
            action: action
        )
    }
}

/// Small text-only button for actions packed into a tight row (e.g. a card
/// footer), where a full `SettingsPillButton` would be too heavy.
struct SettingsInlineButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        BeruButton(title: title, variant: .inline, role: role, action: action)
    }
}

struct SettingsValue: View {
    let text: String
    var mono: Bool = false

    var body: some View {
        Text(text)
            .font(mono ? BeruType.mono : BeruType.control)
            .foregroundStyle(BeruColor.textSecondary)
            .multilineTextAlignment(.trailing)
    }
}

struct SettingsField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = BeruMetrics.fieldWidth
    var alignment: TextAlignment = .leading

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(BeruType.control)
            .foregroundStyle(BeruColor.textPrimary)
            .multilineTextAlignment(alignment)
            .frame(width: width)
            .padding(.horizontal, BeruSpace.md)
            .padding(.vertical, BeruSpace.xs)
            .background {
                Capsule()
                    .fill(BeruColor.input)
                    .overlay(Capsule().strokeBorder(BeruColor.border, lineWidth: 1))
            }
    }
}

struct SettingsSecretField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = BeruMetrics.fieldWidth
    @State private var visible = false

    var body: some View {
        HStack(spacing: BeruSpace.xs) {
            Group {
                if visible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(BeruType.mono)
            .foregroundStyle(BeruColor.textSecondary)
            BeruIconButton(
                icon: visible ? "visibility_off" : "visibility",
                size: 15,
                frameSize: BeruMetrics.hitTargetCompact,
                tint: BeruColor.textSecondary,
                help: visible ? "Hide secret" : "Show secret"
            ) {
                visible.toggle()
            }
        }
        .frame(width: width)
        .padding(.horizontal, BeruSpace.md)
        .padding(.vertical, BeruSpace.xs)
        .background {
            Capsule()
                .fill(BeruColor.input)
                .overlay(Capsule().strokeBorder(BeruColor.border, lineWidth: 1))
        }
    }
}

struct SettingsSwitch: View {
    @Binding var isOn: Bool
    var accessibilityLabel: String = "Toggle"

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? BeruColor.accent : BeruColor.border)
                    .frame(width: 42, height: 24)
                Circle()
                    .fill(BeruColor.onAccent)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                    .padding(BeruSpace.hair)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isOn)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct SettingsSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search settings..."

    var body: some View {
        HStack(spacing: BeruSpace.xs) {
            BeruIcon(name: "search", size: 16)
                .foregroundStyle(BeruColor.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(BeruType.search)
                .foregroundStyle(BeruColor.textPrimary)
                .lineLimit(1)
                .frame(minWidth: 0, maxWidth: .infinity)
                .layoutPriority(1)
        }
        .padding(.horizontal, BeruSpace.md)
        .padding(.vertical, BeruSpace.sm)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background {
            Capsule()
                .strokeBorder(BeruColor.border, lineWidth: 1)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(placeholder)
    }
}

struct SettingsMenuPill<Selection: Hashable, Content: View>: View {
    @Binding var selection: Selection
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: BeruSpace.xs) {
                Text(label)
                    .font(BeruType.control)
                BeruIcon(name: "expand_more", size: 14)
            }
            .foregroundStyle(BeruColor.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, BeruSpace.md)
            .padding(.vertical, BeruSpace.xs)
            .background {
                Capsule()
                    .strokeBorder(BeruColor.border, lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
