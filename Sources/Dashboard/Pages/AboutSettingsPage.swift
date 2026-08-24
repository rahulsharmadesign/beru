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
        SettingsPage(title: "About", subtitle: DashboardRoute.about.pageSubtitle) {
            identity

            SettingsSection(title: "This build") {
                SettingsRow(title: "Version") {
                    SettingsValue(text: "\(version) (\(build))", mono: true)
                }
                SettingsRow(title: "License", caption: copyright) {
                    SettingsValue(text: "MIT")
                }
            }

            SettingsSection(
                title: "Privacy",
                subtitle: "Beru does not phone home. Requests go only to the provider you configure."
            ) {
                SettingsFootnote(text: "No analytics, telemetry, or crash reporting. API keys stay in the Keychain. Usage history is off until you turn it on, and never leaves this Mac.")
            }

            SettingsSection(title: "Support", subtitle: "Optional. Nothing here is required to use Beru.") {
                SettingsRow(
                    title: "Send a tip",
                    caption: "Made with love, late-night curiosity, and an AI companion that never runs out of tokens."
                ) {
                    SettingsPrimaryButton(title: "Razorpay") {
                        NSWorkspace.shared.open(BeruAbout.tip)
                    }
                }
                SettingsRow(
                    title: "Source",
                    caption: "Code, license, and release notes."
                ) {
                    SettingsPillButton(title: "GitHub") {
                        NSWorkspace.shared.open(BeruAbout.source)
                    }
                }
                SettingsRow(
                    title: "Contact",
                    caption: "Bugs, ideas, and questions. GitHub issues is the inbox."
                ) {
                    SettingsPillButton(title: "Open") {
                        NSWorkspace.shared.open(BeruAbout.issues)
                    }
                }
            }
        }
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(BeruRadius.shape(BeruRadius.lg))
            VStack(alignment: .leading, spacing: 4) {
                Text("Beru")
                    .font(BeruSans.pageTitle)
                    .foregroundStyle(SettingsTheme.textPrimary)
                Text("A menu bar utility that refines selected text in any app.")
                    .font(BeruSans.rowCaption)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if updates.showsUpdateButton {
                SettingsPrimaryButton(title: updates.buttonTitle, enabled: !updates.isBusy) {
                    updates.install()
                }
            }
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Beru, a menu bar utility that refines selected text in any app.")
        .onAppear { updates.check(force: true) }
    }
}
