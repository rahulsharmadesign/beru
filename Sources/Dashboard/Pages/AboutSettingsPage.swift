import AppKit
import SwiftUI

// Moved out of Sources/Settings/SettingsView.swift, which held five
// unrelated pages in one 622-line file and no longer contained a
// SettingsView at all. These are dashboard pages, so they live with the
// dashboard; SettingsStore stays the single place they read and write.

// MARK: - About

/// Public identity for this build. Swap these URLs if the handles change.
enum BeruAbout {
    static let source = URL(string: "https://github.com/rahulsharmadesign/beru")!
    static let issues = URL(string: "https://github.com/rahulsharmadesign/beru/issues")!
    static let tip = URL(string: "https://razorpay.me/@rahulsharmadesign")!
}

struct AboutSettingsTab: View {
    @Bindable private var updates = AppUpdateService.shared

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var copyright: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "© 2026 Rahul Sharma" : trimmed
    }

    var body: some View {
        SettingsPage(
            title: DashboardRoute.about.title,
            subtitle: DashboardRoute.about.pageSubtitle,
            icon: DashboardRoute.about.lucideIcon
        ) {
            SettingsHeroCard(
                name: "Beru",
                tagline: "A menu bar utility that refines selected text in any app.",
                version: "\(version) (\(build))"
            )

            SettingsSection(title: "This build") {
                SettingsRow(title: "Version") {
                    SettingsValue(text: "\(version) (\(build))", mono: true)
                }
                SettingsRow(title: "License", caption: copyright) {
                    SettingsValue(text: "MIT")
                }
            }

            SettingsSection(
                title: "Updates",
                subtitle: "Checks GitHub Releases for a newer Beru DMG."
            ) {
                if let message = updates.statusMessage {
                    SettingsFootnote(text: message)
                }
                SettingsRow(title: "GitHub Releases") {
                    HStack(spacing: BeruSpace.xs) {
                        SettingsPrimaryButton(
                            title: updates.checkButtonTitle,
                            enabled: !updates.isBusy
                        ) {
                            updates.check()
                        }
                        if updates.showsInstallButton {
                            SettingsPrimaryButton(
                                title: updates.buttonTitle,
                                enabled: !updates.isBusy
                            ) {
                                updates.install()
                            }
                        }
                    }
                }
            }

            SettingsSection(
                title: "Privacy",
                subtitle: "Beru does not phone home. Requests go only to the provider you configure."
            ) {
                SettingsFootnote(text: "No analytics, telemetry, or crash reporting. API keys stay in the Keychain. Usage history is off until you turn it on, and never leaves this Mac.")
            }

            SettingsSection(title: "Support") {
                SettingsRow(
                    title: "Send a tip"
                ) {
                    SettingsPillButton(title: "Razorpay") {
                        NSWorkspace.shared.open(BeruAbout.tip)
                    }
                }
                SettingsRow(
                    title: "Source"
                ) {
                    SettingsPillButton(title: "GitHub") {
                        NSWorkspace.shared.open(BeruAbout.source)
                    }
                }
                SettingsRow(
                    title: "Contact"
                ) {
                    SettingsPillButton(title: "Open") {
                        NSWorkspace.shared.open(BeruAbout.issues)
                    }
                }
            }
        }
    }
}
