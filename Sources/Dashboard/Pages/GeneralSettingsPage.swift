import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

// Moved out of Sources/Settings/SettingsView.swift, which held five
// unrelated pages in one 622-line file and no longer contained a
// SettingsView at all. These are dashboard pages, so they live with the
// dashboard; SettingsStore stays the single place they read and write.

struct GeneralSettingsTab: View {
    @Bindable private var settings = SettingsStore.shared

    var body: some View {
        SettingsPage(title: "General", subtitle: DashboardRoute.general.pageSubtitle) {
            SettingsSection(title: "Account", subtitle: "Profile details stored only on this Mac.") {
                SettingsRow(title: "Name", caption: "Used only for greetings on this Mac.") {
                    SettingsField(placeholder: "Your name", text: $settings.userName, alignment: .trailing)
                }
            }

            SettingsSection(title: "Accent", subtitle: "Primary color for selected controls and actions.") {
                SettingsRow(title: "Primary color", caption: "Selected controls, focus, and primary actions.") {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(22), spacing: BeruSpace.xs),
                            count: 6
                        ),
                        spacing: BeruSpace.xs
                    ) {
                        ForEach(PrimaryColor.allCases) { option in
                            Button {
                                settings.primaryColorID = option.rawValue
                            } label: {
                                ZStack {
                                    Circle().fill(option.color)
                                    if settings.primaryColorID == option.rawValue {
                                        BeruIcon(name: "check", size: 10)
                                            .foregroundStyle(option.selectedForeground)
                                    }
                                }
                                .frame(width: 18, height: 18)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.title)
                        }
                    }
                    .frame(width: 156, alignment: .trailing)
                }
            }

            SettingsSection(title: "Keyboard", subtitle: "Global shortcuts for opening Beru and dictation.") {
                SettingsRow(title: "Open Beru", caption: "Select text in another app, then press this shortcut.") {
                    SettingsShortcutRecorder(name: .invokeBeru)
                }
                SettingsRow(title: "Dictate", caption: "Opens Beru in Ask and starts listening. Press again, Escape, or the mic to stop.") {
                    SettingsShortcutRecorder(name: .dictateToBeru)
                }
            }

            SettingsSection(title: "Startup", subtitle: "Launch behavior when you sign in.") {
                SettingsRow(title: "Run Beru at login", caption: "Start in the menu bar when you sign in.") {
                    SettingsSwitch(isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { enabled in
                            settings.launchAtLogin = enabled
                            applyLaunchAtLogin(enabled)
                        }
                    ), accessibilityLabel: "Run Beru at login")
                }
            }

            SettingsSection(title: "Panel", subtitle: "Default behavior for the floating composer.") {
                SettingsRow(title: "Default action", caption: "Used when enhancing the clipboard or a vault note.") {
                    Picker("", selection: $settings.defaultActionID) {
                        ForEach(ActionRegistry.shared.allActions) { action in
                            Text(action.name).tag(action.id)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Default action")
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                SettingsRow(
                    title: "Explain what changed",
                    caption: "A short rationale with the result. No extra round trip."
                ) {
                    SettingsSwitch(
                        isOn: $settings.explainChanges,
                        accessibilityLabel: "Explain what changed"
                    )
                }
                SettingsRow(
                    title: "Remember recent turns",
                    caption: """
                    Lets Enhance, Describe and Search build on your last \
                    \(SessionThread.maxTurns) requests in the same app, so a follow-up like \
                    "shorter" has something to refer to. Kept in memory only, never written \
                    to disk, and forgotten when you switch apps or after \
                    \(Int(SessionThread.idleTimeout / 60)) minutes idle.
                    """
                ) {
                    SettingsSwitch(
                        isOn: $settings.sessionContextEnabled,
                        accessibilityLabel: "Remember recent turns"
                    )
                }
            }
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { }
    }
}

/// Shortcut field on the Settings glass slab. `KeyboardShortcuts.Recorder` is
/// an `NSSearchField`; its cancel × inherits a glass bezel that paints a dark
/// rectangle over the capsule.
private struct SettingsShortcutRecorder: View {
    let name: KeyboardShortcuts.Name

    var body: some View {
        ShortcutRecorderField(name: name)
            .frame(width: BeruMetrics.fieldWidth, height: BeruMetrics.hitTarget)
            .background {
                Capsule()
                    .fill(BeruColor.input)
                    .overlay(Capsule().strokeBorder(BeruColor.border, lineWidth: 1))
            }
    }
}

private struct ShortcutRecorderField: NSViewRepresentable {
    let name: KeyboardShortcuts.Name

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let field = KeyboardShortcuts.RecorderCocoa(for: name)
        Self.style(field)
        return field
    }

    func updateNSView(_ field: KeyboardShortcuts.RecorderCocoa, context: Context) {
        field.shortcutName = name
        Self.style(field)
    }

    private static func style(_ field: NSSearchField) {
        field.focusRingType = .none
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.wantsLayer = true
        field.layer?.isOpaque = false
        field.layer?.backgroundColor = .clear
        if let cell = field.cell as? NSSearchFieldCell {
            cell.drawsBackground = false
            cell.focusRingType = .none
            cell.searchButtonCell = nil
            if let cancel = cell.cancelButtonCell {
                cancel.isBordered = false
                cancel.bezelStyle = .inline
                cancel.backgroundColor = .clear
            }
        }
        stripButtonChrome(field)
        DispatchQueue.main.async { stripButtonChrome(field) }
    }

    private static func stripButtonChrome(_ view: NSView) {
        if let button = view as? NSButton {
            button.isBordered = false
            button.bezelStyle = .inline
            button.wantsLayer = true
            button.layer?.isOpaque = false
            button.layer?.backgroundColor = .clear
        }
        for sub in view.subviews {
            stripButtonChrome(sub)
        }
    }
}
