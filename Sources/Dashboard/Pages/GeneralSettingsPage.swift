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
                    Picker("", selection: $settings.primaryColorID) {
                        ForEach(PrimaryColor.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Primary color")
                    .pickerStyle(.menu)
                    .fixedSize()
                    .tint(BeruColor.accent)
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

/// Native shortcut recorder. `KeyboardShortcuts.RecorderCocoa` is an
/// `NSSearchField`; leave its system bezel in place. The host reports a
/// fixed intrinsic size so `SettingsRow`'s `.fixedSize` does not shrink
/// each recorder to its shortcut string (P vs L).
private struct SettingsShortcutRecorder: View {
    let name: KeyboardShortcuts.Name

    var body: some View {
        ShortcutRecorderField(name: name)
            .frame(width: BeruMetrics.fieldWidth, height: BeruMetrics.hitTarget)
    }
}

private struct ShortcutRecorderField: NSViewRepresentable {
    let name: KeyboardShortcuts.Name

    func makeNSView(context: Context) -> ShortcutRecorderHost {
        ShortcutRecorderHost(name: name)
    }

    func updateNSView(_ host: ShortcutRecorderHost, context: Context) {
        host.recorder.shortcutName = name
    }
}

private final class ShortcutRecorderHost: NSView {
    let recorder: KeyboardShortcuts.RecorderCocoa

    init(name: KeyboardShortcuts.Name) {
        recorder = KeyboardShortcuts.RecorderCocoa(for: name)
        super.init(frame: .zero)
        recorder.focusRingType = .default
        recorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(recorder)
        NSLayoutConstraint.activate([
            recorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            recorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            recorder.topAnchor.constraint(equalTo: topAnchor),
            recorder.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: BeruMetrics.fieldWidth, height: BeruMetrics.hitTarget)
    }
}
