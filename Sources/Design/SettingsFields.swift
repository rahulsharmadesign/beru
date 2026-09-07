import SwiftUI

// Haze field wells for settings: 32pt pills, surface fill, hairline,
// focus glow. Plain `TextField` / `SecureField` stay out.

/// Haze field well: 32pt pill, surface fill, hairline, focus glow.
struct SettingsField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = BeruMetrics.fieldWidth
    var alignment: TextAlignment = .leading
    var leadingIcon: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: BeruSpace.xs) {
            if let leadingIcon {
                BeruIcon(name: leadingIcon, size: BeruMetrics.iconSize)
                    .foregroundStyle(BeruColor.textSecondary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(BeruType.control)
                .multilineTextAlignment(alignment)
                .focused($focused)
        }
        .padding(.horizontal, BeruSpace.sm)
        .frame(width: width, height: BeruMetrics.fieldHeight, alignment: .leading)
        .background {
            Capsule()
                .fill(BeruColor.subtleFill)
                .overlay {
                    Capsule().strokeBorder(
                        focused ? BeruColor.accent : BeruColor.border,
                        lineWidth: 1
                    )
                }
                .shadow(color: focused ? BeruColor.focusGlow : .clear, radius: BeruMetrics.focusHalo)
        }
        .beruFocusEase(focused)
        .onTapGesture { focused = true }
    }
}

/// Secret field with a Lucide visibility round. Same well as `SettingsField`.
struct SettingsSecretField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = BeruMetrics.fieldWidth
    @State private var visible = false
    @FocusState private var focused: Bool

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
            .focused($focused)
            Button {
                visible.toggle()
            } label: {
                BeruIcon(name: visible ? "visibility_off" : "visibility", size: BeruMetrics.iconSize)
                    .foregroundStyle(BeruColor.textSecondary)
            }
            .buttonStyle(.plain)
            .help(visible ? "Hide secret" : "Show secret")
            .accessibilityLabel(visible ? "Hide secret" : "Show secret")
        }
        .padding(.horizontal, BeruSpace.sm)
        .frame(width: width, height: BeruMetrics.fieldHeight)
        .background {
            Capsule()
                .fill(BeruColor.subtleFill)
                .overlay {
                    Capsule().strokeBorder(
                        focused ? BeruColor.accent : BeruColor.border,
                        lineWidth: 1
                    )
                }
                .shadow(color: focused ? BeruColor.focusGlow : .clear, radius: BeruMetrics.focusHalo)
        }
        .beruFocusEase(focused)
    }
}

/// Haze search: Lucide glyph, plain field, clear round. Replaces
/// `NSSearchField` so settings search paints like every other well.
struct SettingsSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search settings..."

    var body: some View {
        HStack(spacing: BeruSpace.xs) {
            BeruIcon(name: "search", size: BeruMetrics.iconSize)
                .foregroundStyle(BeruColor.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(BeruType.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    BeruIcon(name: "x", size: BeruMetrics.iconSizeDense)
                        .foregroundStyle(BeruColor.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, BeruSpace.sm)
        .frame(height: BeruMetrics.fieldHeight)
        .background {
            Capsule()
                .fill(BeruColor.subtleFill)
                .overlay {
                    Capsule().strokeBorder(BeruColor.border, lineWidth: 1)
                }
        }
        .accessibilityLabel(placeholder)
    }
}
