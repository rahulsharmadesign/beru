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
                    KeyboardShortcuts.Recorder(for: .invokeBeru)
                }
                SettingsRow(title: "Dictate", caption: "Opens Beru in Ask and starts listening. Press again, Escape, or the mic to stop.") {
                    KeyboardShortcuts.Recorder(for: .dictateToBeru)
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
