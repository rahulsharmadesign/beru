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
                SettingsRow(title: "Status") {
                    statusControl(
                        title: isTrusted ? "Granted" : "Needed",
                        isPositive: isTrusted,
                        showsGrant: !isTrusted,
                        grantTitle: "Grant",
                        onGrant: {
                            Permissions.requestAccessibilityIfNeeded()
                            Permissions.openAccessibilitySettings()
                        },
                        onOpen: { Permissions.openAccessibilitySettings() }
                    )
                }
            }

            SettingsSection(title: "Dictation", subtitle: "On-device speech for panel instructions.") {
                SettingsRow(
                    title: "Status",
                    caption: dictation.availability.message
                        ?? "Speech is transcribed on this Mac. Beru will not fall back to Apple’s servers."
                ) {
                    statusControl(
                        title: dictation.availability.permissionBadgeTitle,
                        isPositive: dictation.availability.isReady,
                        showsGrant: dictation.availability == .needsPermission,
                        grantTitle: "Grant",
                        onGrant: {
                            Task { await dictation.requestPermissions() }
                        },
                        onOpen: { dictation.availability.openSystemSettings() }
                    )
                }
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        isTrusted = Permissions.isAccessibilityTrusted()
        dictation.refreshAvailability()
    }

    private func statusControl(
        title: String,
        isPositive: Bool,
        showsGrant: Bool,
        grantTitle: String,
        onGrant: @escaping () -> Void,
        onOpen: @escaping () -> Void
    ) -> some View {
        HStack(spacing: BeruSpace.xs) {
            SettingsStatusBadge(title: title, isPositive: isPositive)
            if showsGrant {
                SettingsPrimaryButton(title: grantTitle, action: onGrant)
            } else {
                SettingsPillButton(title: "Open", action: onOpen)
            }
        }
    }
}
