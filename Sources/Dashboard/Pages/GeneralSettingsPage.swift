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
        SettingsPage(
            title: DashboardRoute.general.title,
            subtitle: DashboardRoute.general.pageSubtitle,
            icon: DashboardRoute.general.lucideIcon
        ) {
            SettingsSection(title: "Account") {
                SettingsRow(title: "Name") {
                    SettingsField(placeholder: "Your name", text: $settings.userName, alignment: .center)
                }
            }

            SettingsSection(
                title: "Accent",
                subtitle: "Beru's tint across pills, selection, and the send disc."
            ) {
                SettingsAccentSwatches(
                    selection: Binding(
                        get: { PrimaryColor(rawValue: settings.primaryColorID) ?? .indigo },
                        set: { settings.primaryColorID = $0.rawValue }
                    )
                )
            }

            SettingsSection(title: "Keyboard") {
                SettingsRow(title: "Open Beru", caption: "Select text in another app, then press this shortcut.") {
                    SettingsShortcutRecorder(name: .invokeBeru)
                }
                SettingsRow(title: "Dictate", caption: "Opens Beru in Ask and starts listening.") {
                    SettingsShortcutRecorder(name: .dictateToBeru)
                }
            }

            SettingsSection(title: "Startup") {
                SettingsRow(title: "Run Beru at login") {
                    SettingsSwitch(isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { enabled in
                            settings.launchAtLogin = enabled
                            applyLaunchAtLogin(enabled)
                        }
                    ), accessibilityLabel: "Run Beru at login")
                }
            }

            SettingsSection(title: "Panel") {
                SettingsRow(title: "Default action", caption: "Used when enhancing the clipboard or a vault note.") {
                    SettingsMenuPicker(
                        selection: $settings.defaultActionID,
                        options: ActionRegistry.shared.allActions.map {
                            SettingsPickerOption(value: $0.id, title: $0.name)
                        },
                        accessibilityLabel: "Default action"
                    )
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
                    caption: "Follow-ups can build on earlier requests in the same app. Memory only, never written to disk."
                ) {
                    SettingsSwitch(
                        isOn: $settings.sessionContextEnabled,
                        accessibilityLabel: "Remember recent turns"
                    )
                }
            }

            SettingsSection(
                title: "Reset",
                subtitle: "Clear what Beru has learned from how you use it.",
                tone: .danger
            ) {
                SettingsRow(
                    title: "Learned preferences",
                    caption: "Beru forgets the tone, grammar kind, and target it saw you pick last."
                ) {
                    SettingsPillButton(title: "Clear", role: .destructive) {
                        settings.clearInteractionProfile()
                    }
                    .disabled(settings.interactionProfile.isEmpty)
                    .accessibilityLabel("Clear learned preferences")
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
