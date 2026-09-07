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
            MenuBarStatusIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

/// Status-item glyph. Template intent comes from the asset catalog, so the
/// system tints it for light, dark, and wallpaper-tinted menu bars. Do not
/// route through `NSImage`: SwiftUI rasterizes those pixels literally and a
/// dark glyph goes invisible on dark bars.
private struct MenuBarStatusIcon: View {
    var body: some View {
        Image("MenuBarIcon")
            .accessibilityLabel("Beru")
    }
}

struct MenuBarContent: View {
    let coordinator: AppCoordinator
    @Bindable private var settings = SettingsStore.shared
    @Bindable private var appearance = AppearanceObserver.shared
    @Environment(\.dismiss) private var dismiss

    /// Hero CTA height. Rows sit at the 32pt Haze pill height.
    private let rowHeight: CGFloat = BeruMetrics.pillHeight

    var body: some View {
        // Observation only invalidates on values read while body runs, and
        // nothing in this tree reads the system appearance. This read is the
        // subscription that repaints AppKit-backed surfaces on a light/dark switch.
        let _ = appearance.signature
        let _ = settings.primaryColorID
        VStack(spacing: BeruSpace.xs) {
            header
            primaryAction
            HStack(spacing: BeruSpace.xs) {
                compactAction("Dictate", symbol: "mic", action: coordinator.dictateNewText)
                compactAction("Vault", symbol: "library", action: {
                    openDashboard(.vault)
                })
            }
            MenuProviderPicker()
            Divider()
            footer
        }
        .padding(BeruSpace.sm)
        .frame(width: BeruMetrics.menuDropdownWidth)
        .background(BeruColor.panelSolid)
        .clipShape(BeruRadius.shape(BeruRadius.lg))
        .overlay {
            BeruRadius.shape(BeruRadius.lg)
                .strokeBorder(BeruColor.border, lineWidth: 1)
        }
        .shadow(color: BeruColor.softShadow, radius: BeruSpace.lg, y: BeruSpace.xs)
        .tint(BeruColor.accent)
    }

    private var header: some View {
        HStack(spacing: BeruSpace.sm) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: BeruMetrics.brandMark, height: BeruMetrics.brandMark)
                .clipShape(BeruRadius.shape(BeruRadius.sm))
            VStack(alignment: .leading, spacing: 0) {
                Text("Beru").font(BeruType.controlSemibold)
                Text(headerStatus.text)
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: BeruSpace.xs)
            Circle()
                .fill(headerStatus.ready ? BeruColor.accent : BeruColor.textSecondary.opacity(0.45))
                .frame(width: BeruSpace.xs, height: BeruSpace.xs)
                .accessibilityLabel(headerStatus.ready ? "Beru is ready" : headerStatus.text)
        }
        .padding(.bottom, BeruSpace.xxs)
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
            HStack(spacing: BeruSpace.xs) {
                BeruIcon(name: "sparkles", size: BeruMetrics.iconSize, strokeWidth: 2)
                Text("Enhance Clipboard")
                    .font(BeruType.controlSemibold)
                    .lineLimit(1)
                Spacer(minLength: BeruSpace.xs)
                if let shortcut = KeyboardShortcuts.getShortcut(for: .invokeBeru) {
                    BeruKbd(text: shortcut.description, tone: .onAccent)
                        .opacity(0.85)
                }
            }
            .foregroundStyle(BeruColor.onAccent)
            .padding(.horizontal, BeruSpace.md)
            .frame(maxWidth: .infinity, minHeight: rowHeight)
            .background(BeruColor.accentGradient, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enhance Clipboard")
        .accessibilityHint("Run Beru on the current clipboard")
    }

    private func compactAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BeruSpace.xs) {
                BeruIcon(name: symbol, size: BeruMetrics.iconSize, strokeWidth: 2)
                Text(title)
                    .font(BeruType.controlMedium)
                    .lineLimit(1)
            }
            .foregroundStyle(BeruColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: BeruMetrics.pillHeight)
            .background(BeruColor.subtleFill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(BeruColor.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(title)
    }

    /// `NSMenu.popUp` works in a MenuBarExtra window. SwiftUI `Menu` as an
    /// overlay on a custom row does not receive clicks.
    private var footer: some View {
        HStack(spacing: BeruSpace.xxs) {
            MenuFooterRow(icon: "settings", title: "Settings") {
                openDashboard(.general)
            }
            MenuFooterRow(title: "Quit", role: .destructive) {
                NSApp.terminate(nil)
            }
        }
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

/// Haze menu row for the footer. Transparent idle, surface fill on hover,
/// destructive tint for Quit.
private struct MenuFooterRow: View {
    var icon: String? = nil
    let title: String
    var role: ButtonRole? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: BeruSpace.xs) {
                if let icon {
                    BeruIcon(name: icon, size: BeruMetrics.iconSize, strokeWidth: 2)
                }
                Text(title)
                    .font(BeruType.controlMedium)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(role == .destructive ? BeruColor.destructive : BeruColor.textPrimary)
            .padding(.horizontal, BeruSpace.sm)
            .frame(maxWidth: .infinity, minHeight: BeruMetrics.pillHeight, alignment: .leading)
            .background {
                BeruRadius.shape(BeruRadius.sm)
                    .fill(isHovered ? BeruColor.hoverFill : .clear)
            }
            .contentShape(BeruRadius.shape(BeruRadius.sm))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .onHover { isHovered = $0 }
.beruHoverEase(isHovered)
        .accessibilityLabel(title)
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


