import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let invokeBeru = Self("invokeBeru", default: .init(.p, modifiers: [.control, .option, .command]))
    /// Toggle dictation. Defaults to Control-Option-Command-L. Opens Beru in
    /// Ask and starts listening. Press again to stop.
    static let dictateToBeru = Self("dictateToBeru", default: .init(.l, modifiers: [.control, .option, .command]))
}

@main
struct BeruApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(coordinator: appDelegate.coordinator)
        } label: {
            Image("MenuBarIcon")
                .resizable()
                .renderingMode(.template)
                .frame(width: 24, height: 24)
                .accessibilityLabel("Beru")
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarContent: View {
    let coordinator: AppCoordinator
    @Bindable private var settings = SettingsStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let rowHeight: CGFloat = 40
    private let rowRadius: CGFloat = 10

    var body: some View {
        let _ = AppearanceObserver.shared.signature
        let _ = settings.primaryColorID
        VStack(spacing: 8) {
            header
            primaryAction
            HStack(spacing: 8) {
                compactAction("Dictate", symbol: "mic", action: coordinator.dictateNewText)
                compactAction("Vault", symbol: "library", action: {
                    openDashboard(.vault)
                })
            }
            providerRow
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
        .background(colorScheme == .dark ? BrandColors.darkSurface : BrandColors.lightSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 24, y: 10)
        .tint(BrandColors.accentColor)
    }

    private var wellFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("BrandMark").resizable().scaledToFit().frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Beru").font(.headline)
                Text(headerStatus.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Circle()
                .fill(headerStatus.ready ? DashboardTheme.accent : Color.secondary.opacity(0.45))
                .frame(width: 8, height: 8)
                .accessibilityLabel(headerStatus.ready ? "Beru is ready" : headerStatus.text)
        }
        .padding(.bottom, 4)
    }

    private var headerStatus: (text: String, ready: Bool) {
        if !Permissions.isAccessibilityTrusted() {
            return ("Needs Accessibility", false)
        }
        if !settings.isConfigured(settings.activeProvider) {
            return ("Set up a provider in Settings", false)
        }
        return ("Ready to refine your writing", true)
    }

    private var primaryAction: some View {
        Button { coordinator.enhanceClipboard() } label: {
            HStack(spacing: 8) {
                BeruIcon(name: "sparkles", size: 15, strokeWidth: 2)
                Text("Enhance Clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let shortcut = KeyboardShortcuts.getShortcut(for: .invokeBeru) {
                    Text(shortcut.description)
                        .font(.system(size: 12, weight: .medium).monospaced())
                        .opacity(0.72)
                }
            }
            .foregroundStyle(SettingsTheme.onActive)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: rowHeight)
            .background(DashboardTheme.accent, in: RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enhance Clipboard")
        .accessibilityHint("Run Beru on the current clipboard")
    }

    private func compactAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                BeruIcon(name: symbol, size: 15, strokeWidth: 2)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: rowHeight)
            .background(wellFill, in: RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title)
    }

    /// `NSMenu.popUp` works in a MenuBarExtra window. SwiftUI `Menu` as an
    /// overlay on a custom row does not receive clicks.
    private var providerRow: some View {
        Button {
            presentProviderMenu()
        } label: {
            HStack(spacing: 8) {
                BeruIcon(name: "cpu", size: 15, strokeWidth: 2)
                Text(settings.activeProvider.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                BeruIcon(name: "chevrons-up-down", size: 14, strokeWidth: 2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
            .background(wellFill, in: RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Change the active provider")
        .accessibilityLabel("Active provider, \(settings.activeProvider.title)")
        .accessibilityHint("Choose which AI provider Beru sends requests to")
    }

    private func presentProviderMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let selected = settings.activeProvider
        ProviderMenuRelay.shared.onPick = { kind in
            settings.selectProvider(kind)
        }
        for kind in ProviderKind.allCases {
            let item = NSMenuItem(
                title: kind.title,
                action: #selector(ProviderMenuRelay.pick(_:)),
                keyEquivalent: ""
            )
            item.target = ProviderMenuRelay.shared
            item.representedObject = kind.rawValue
            item.state = kind == selected ? .on : .off
            item.isEnabled = settings.isConfigured(kind)
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private var footer: some View {
        HStack {
            Button { openDashboard(.general) } label: {
                HStack(spacing: 8) {
                    BeruIcon(name: "settings", size: 14, strokeWidth: 2)
                    Text("Settings")
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
        .foregroundStyle(.primary)
        .padding(.top, 4)
    }

    private func openDashboard(_ route: DashboardRoute) {
        closeMenuBarWindow()
        coordinator.showDashboard(route: route)
    }

    /// Window-style `MenuBarExtra` does not dismiss on its own when another
    /// window is opened. `Environment.dismiss` is the SwiftUI path; the status
    /// item window is ordered out as a fallback.
    private func closeMenuBarWindow() {
        dismiss()
        // The extra is still key when this button fires. Ordering it out is
        // what actually hides a window-style MenuBarExtra.
        NSApp.keyWindow?.orderOut(nil)
        for window in NSApp.windows where window.className.contains("NSStatusBar") {
            window.orderOut(nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    /// Sent by a duplicate launch to the instance that is already running.
    static let showDashboardNotification = Notification.Name("com.rahul.beru.showDashboard")

    /// True when the process is hosting an XCTest bundle rather than running
    /// as the real app.
    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside an app host that shares this bundle id. Left
        // unguarded, the single-instance check below would terminate the test
        // runner before it connects whenever the installed app is running.
        guard !isRunningTests else { return }

        // Single-instance guard: a copy in /Applications and a debug build in
        // DerivedData can otherwise run simultaneously, and both would answer
        // the global hotkey (racing captures, duplicate panels). Newest launch
        // yields to the already-running instance. LaunchServices can briefly
        // report already-dead processes, so confirm liveness with kill(pid, 0)
        // before yielding to one.
        let others = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.rahul.beru"
        ).filter { app in
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && !app.isTerminated
                && kill(app.processIdentifier, 0) == 0
        }
        if !others.isEmpty {
            // Hand the request over before yielding. The user just asked for
            // the app to open; exiting without a word is indistinguishable from
            // a crash, and was — the running copy is a menu bar process with no
            // window, so nothing at all appeared.
            DistributedNotificationCenter.default().postNotificationName(
                Self.showDashboardNotification, object: nil, userInfo: nil, deliverImmediately: true
            )
            NSApp.terminate(nil)
            return
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Self.showDashboardNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.coordinator.showDashboard()
            }
        }

        coordinator.start()
    }

    /// Opening an app that is already running does not launch it again — AppKit
    /// sends this instead, for a Dock click, a Finder double-click, Spotlight
    /// and Launchpad alike.
    ///
    /// Without it every one of those did nothing whatsoever. For an ordinary app
    /// that is merely unhelpful, because its window is already on screen; for a
    /// menu bar app there is no window, so the only feedback was none. Reported
    /// as "Beru doesn't open when I click it in the Dock", which is
    /// exactly what was happening.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        coordinator.showDashboard()
        return true
    }
}

/// Target of `NSMenuItem` actions. SwiftUI views cannot be `@objc` targets.
private final class ProviderMenuRelay: NSObject {
    static let shared = ProviderMenuRelay()
    var onPick: ((ProviderKind) -> Void)?

    @objc func pick(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let kind = ProviderKind(rawValue: raw) else { return }
        onPick?(kind)
    }
}
