import AppKit
import SwiftUI

// Moved out of Sources/Settings/SettingsView.swift, which held five
// unrelated pages in one 622-line file and no longer contained a
// SettingsView at all. These are dashboard pages, so they live with the
// dashboard; SettingsStore stays the single place they read and write.

struct PermissionsSettingsTab: View {
    /// Live trust state: the distributed `com.apple.accessibility.api`
    /// notification refreshes the badge the moment the toggle lands, without
    /// waiting for the app to become active again. A plain `@State` snapshot
    /// refreshed only on appear missed exactly the post-update re-grant.
    @Bindable private var a11y = AccessibilityPreferences.shared
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
                badgeTitle: a11y.isAccessibilityTrusted ? "Granted" : "Needed",
                isPositive: a11y.isAccessibilityTrusted,
                message: a11y.isAccessibilityTrusted
                    ? "Required to read and replace text in other apps."
                    : "Required to read and replace text in other apps. If the toggle won't stick: quit Beru, keep only /Applications/Beru.app, then remove (–) and re-add (+) that copy. Still stuck: run `tccutil reset Accessibility com.rahul.beru` in Terminal and grant again."
            ) {
                if a11y.isAccessibilityTrusted {
                    SettingsPillButton(title: "Open") {
                        Permissions.openAccessibilitySettings()
                    }
                } else {
                    SettingsPrimaryButton(title: "Grant") {
                        // The system prompt appears at most once; after an
                        // update the stale TCC entry must be fixed by hand, so
                        // only fall through to System Settings while untrusted.
                        if !Permissions.requestAccessibilityIfNeeded() {
                            Permissions.openAccessibilitySettings()
                        }
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
        AccessibilityPreferences.shared.refreshTrust()
        dictation.refreshAvailability()
    }
}
