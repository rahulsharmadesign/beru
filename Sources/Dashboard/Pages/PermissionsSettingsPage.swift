import AppKit
import SwiftUI

// Moved out of Sources/Settings/SettingsView.swift, which held five
// unrelated pages in one 622-line file and no longer contained a
// SettingsView at all. These are dashboard pages, so they live with the
// dashboard; SettingsStore stays the single place they read and write.

struct PermissionsSettingsTab: View {
    @State private var isTrusted = Permissions.isAccessibilityTrusted()
    @Bindable private var dictation = DictationService.shared

    var body: some View {
        SettingsPage(title: "Permissions", subtitle: DashboardRoute.permissions.pageSubtitle) {
            SettingsSection(title: "Accessibility", subtitle: "Required to read and replace text in other apps.") {
                SettingsRow(title: "Status", caption: "Required to read and replace selected text in other apps.") {
                    SettingsValue(text: isTrusted ? "Granted" : "Needed")
                }
                SettingsRow(title: "System Settings") {
                    SettingsPillButton(title: "Open") {
                        Permissions.openAccessibilitySettings()
                    }
                }
            }

            SettingsSection(title: "Dictation", subtitle: "On-device speech for panel instructions.") {
                SettingsRow(
                    title: "Status",
                    caption: dictation.availability.message
                        ?? "Speech is transcribed on this Mac. Beru will not fall back to Apple’s servers."
                ) {
                    SettingsValue(text: dictation.availability.isReady ? "Ready" : "Unavailable")
                }
                SettingsRow(title: dictation.availability == .needsPermission ? "Microphone" : "System Settings") {
                    if dictation.availability == .needsPermission {
                        SettingsPillButton(title: "Allow") {
                            Task { await dictation.requestPermissions() }
                        }
                    } else {
                        SettingsPillButton(title: "Open") {
                            dictation.availability.openSystemSettings()
                        }
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                isTrusted = Permissions.isAccessibilityTrusted()
                dictation.refreshAvailability()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
