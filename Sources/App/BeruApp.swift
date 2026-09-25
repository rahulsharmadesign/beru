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

    init() {
        #if DEBUG
        MainActor.assumeIsolated {
            DesignSnapshot.runIfRequested()
        }
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(coordinator: appDelegate.coordinator)
        } label: {
            BeruMenuBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarContent: View {
    let coordinator: AppCoordinator
    @Bindable private var settings = SettingsStore.shared
    @Bindable private var appearance = AppearanceObserver.shared
    @Environment(\.dismiss) private var dismiss

    /// Menu rows sit at the 32pt pill height.
    private let rowHeight: CGFloat = BeruMetrics.pillHeight

    var body: some View {
        // Observation only invalidates on values read while body runs, and
        // nothing in this tree reads the system appearance. This read is the
        // subscription that repaints AppKit-backed surfaces on a light/dark switch.
        let _ = appearance.signature
        let _ = settings.primaryColorID
        VStack(alignment: .leading, spacing: BeruSpace.hair) {
            header
            Divider().padding(.vertical, BeruSpace.xxs)
            menuRow("Enhance Clipboard", icon: "sparkles") {
                coordinator.enhanceClipboard()
            }
            menuRow(
                "Dictate",
                icon: "mic",
                shortcut: KeyboardShortcuts.getShortcut(for: .dictateToBeru)?.description
            ) {
                coordinator.dictateNewText()
            }
            Divider().padding(.vertical, BeruSpace.xxs)
            menuRow("Settings…", icon: "settings") {
                openDashboard(.general)
            }
            menuRow("Quit Enhancify", icon: "x") {
                NSApp.terminate(nil)
            }
        }
        .padding(BeruSpace.xs)
        .frame(width: BeruMetrics.menuDropdownWidth)
        // No opaque card, stroke, or shadow: the MenuBarExtra window is
        // already system glass. This translucent scrim is the same recipe as
        // the panel slab's tint, so the dropdown and the panel read as one
        // material.
        .background(BeruColor.glassScrim)
    }

    /// Name, the open shortcut, and a status line only when something is
    /// blocked. No colored dot: an accent that means "fine" is noise.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Enhancify").font(BeruType.controlSemibold)
                Spacer(minLength: BeruSpace.xs)
                if let shortcut = KeyboardShortcuts.getShortcut(for: .invokeBeru) {
                    BeruKbd(text: shortcut.description)
                }
            }
            if let status = headerStatus.text {
                Text(status)
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, BeruSpace.xs)
        .padding(.top, BeruSpace.xxs)
        .accessibilityElement(children: .combine)
    }

    /// Status copy only when something is blocked. Ready is the green dot.
    private var headerStatus: (text: String?, ready: Bool) {
        if !Permissions.isAccessibilityTrusted() {
            return ("Needs Accessibility", false)
        }
        if !settings.isConfigured(settings.activeProvider) {
            return ("Set up a provider in Settings", false)
        }
        return (nil, true)
    }

    /// One plain row, like a native menu item: icon, title, optional
    /// shortcut, a soft fill on hover.
    private func menuRow(
        _ title: String,
        icon: String,
        shortcut: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        MenuBarRow(title: title, icon: icon, shortcut: shortcut, height: rowHeight, action: action)
    }

    private func openDashboard(_ route: DashboardRoute) {
        // Defer past the MenuBarExtra tracking loop. Dismissing synchronously
        // inside the click action gets overridden when tracking ends, which
        // leaves the widget open under the dashboard. Closing after the loop
        // unwinds gives the requested order: widget closes, settings appear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            closeMenuBarWindow()
            coordinator.showDashboard(route: route)
        }
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

/// AppKit delivers every delegate callback on the main thread, so the class
/// is MainActor-isolated and owns the MainActor-bound coordinator directly.
@MainActor
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
            // Hand the request over before yielding. Activate the survivor so
            // Finder / Spotlight reopen is not silent for a menu-bar app.
            others.first?.activate(options: [.activateAllWindows])
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


