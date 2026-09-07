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
        SettingsPage(
            title: DashboardRoute.permissions.title,
            subtitle: DashboardRoute.permissions.pageSubtitle,
            icon: DashboardRoute.permissions.lucideIcon
        ) {
            SettingsStatusCard(
                icon: "accessibility",
                title: "Accessibility",
                badgeTitle: isTrusted ? "Granted" : "Needed",
                isPositive: isTrusted,
                message: "Required to read and replace text in other apps."
            ) {
                if isTrusted {
                    SettingsPillButton(title: "Open") {
                        Permissions.openAccessibilitySettings()
                    }
                } else {
                    SettingsPrimaryButton(title: "Grant") {
                        Permissions.requestAccessibilityIfNeeded()
                        Permissions.openAccessibilitySettings()
                    }
                }
            }

            SettingsStatusCard(
                icon: "mic",
                title: "Dictation",
                badgeTitle: dictation.availability.permissionBadgeTitle,
                isPositive: dictation.availability.isReady,
                message: dictation.availability.message
                    ?? "Speech is transcribed on this Mac. Beru will not fall back to Apple’s servers."
            ) {
                if dictation.availability == .needsPermission {
                    SettingsPrimaryButton(title: "Grant") {
                        Task { await dictation.requestPermissions() }
                    }
                } else {
                    SettingsPillButton(title: "Open") {
                        dictation.availability.openSystemSettings()
                    }
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
}
