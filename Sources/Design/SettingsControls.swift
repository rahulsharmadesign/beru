import AppKit
import SwiftUI

// Reusable dashboard controls. Settings screens use system macOS widgets
// (bordered buttons, rounded-border fields, switch, checkbox, menu picker,
// NSSearchField). The panel keeps Beru capsules.

struct SettingsPillButton: View {
    let title: String
    var role: ButtonRole?
    var enabled: Bool = true
    var trailingIcon: String? = nil
    var leadingIcon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            settingsButtonLabel(title: title, leadingIcon: leadingIcon, trailingIcon: trailingIcon)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(!enabled)
        .fixedSize()
    }
}

struct SettingsPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            settingsButtonLabel(title: title, leadingIcon: icon, trailingIcon: nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .disabled(!enabled)
        .fixedSize()
        .tint(BeruColor.accent)
    }
}

struct SettingsTogglePill: View {
    let title: String
    var icon: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            settingsButtonLabel(title: title, leadingIcon: icon, trailingIcon: nil)
        }
        .toggleStyle(.checkbox)
        .controlSize(.regular)
        .fixedSize()
    }
}

struct SettingsIconButton: View {
    let icon: String
    var size: CGFloat = 16
    var frameSize: CGFloat = BeruMetrics.hitTarget
    var enabled: Bool = true
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BeruIcon(name: icon, size: size)
                .frame(width: frameSize, height: frameSize)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(help)
        .fixedSize()
    }
}

struct SettingsInlineButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(title, role: role, action: action)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .fixedSize()
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
            .textSelection(.enabled)
    }
}

/// Granted / Needed (or Unavailable) on a settings row. Color is the status.
struct SettingsStatusBadge: View {
    let title: String
    var isPositive: Bool = false

    var body: some View {
        Text(title)
            .font(BeruType.captionMedium)
            .foregroundStyle(isPositive ? BeruColor.positive : BeruColor.textSecondary)
            .padding(.horizontal, BeruSpace.xs)
            .padding(.vertical, BeruSpace.xxs)
            .background(BeruColor.badge, in: BeruRadius.shape(BeruRadius.sm))
            .accessibilityLabel(title)
    }
}

struct SettingsField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat = BeruMetrics.fieldWidth
    var alignment: TextAlignment = .leading

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .font(BeruType.control)
            .multilineTextAlignment(alignment)
            .frame(width: width)
            .controlSize(.regular)
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
            .textFieldStyle(.roundedBorder)
            .font(BeruType.mono)
            .controlSize(.regular)
            Button {
                visible.toggle()
            } label: {
                BeruIcon(name: visible ? "visibility_off" : "visibility", size: 15)
            }
            .buttonStyle(.borderless)
            .help(visible ? "Hide secret" : "Show secret")
            .accessibilityLabel(visible ? "Hide secret" : "Show secret")
        }
        .frame(width: width)
    }
}

struct SettingsSwitch: View {
    @Binding var isOn: Bool
    var accessibilityLabel: String = "Toggle"

    var body: some View {
        Toggle(accessibilityLabel, isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(isOn ? "On" : "Off")
            .tint(BeruColor.accent)
    }
}

struct SettingsSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search settings..."

    var body: some View {
        SettingsSearchFieldRep(text: $text, placeholder: placeholder)
            .frame(minHeight: BeruSpace.lg)
            .accessibilityLabel(placeholder)
    }
}

private struct SettingsSearchFieldRep: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        field.placeholderString = placeholder
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

struct SettingsMenuPill<Selection: Hashable, Content: View>: View {
    @Binding var selection: Selection
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu(label) { content }
            .menuStyle(.automatic)
            .controlSize(.regular)
            .fixedSize()
            .accessibilityLabel(label)
            .accessibilityValue(String(describing: selection))
    }
}

/// Action menu (Folder, More) for workspace toolbars. Not a picker.
struct SettingsOverflowMenu<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        Menu(title) { content }
            .menuStyle(.automatic)
            .controlSize(.regular)
            .fixedSize()
            .accessibilityLabel(title)
    }
}

@ViewBuilder
private func settingsButtonLabel(title: String, leadingIcon: String?, trailingIcon: String?) -> some View {
    HStack(spacing: BeruSpace.xxs) {
        if let leadingIcon {
            BeruIcon(name: leadingIcon, size: 14)
        }
        Text(title)
            .font(BeruType.control)
            .lineLimit(1)
        if let trailingIcon {
            BeruIcon(name: trailingIcon, size: 14)
        }
    }
}
