import AppKit
import Observation
import SwiftUI

/// Sidebar selection, held outside the view so it survives closing the window
/// and so `show(route:)` can retarget an already-open dashboard without
/// rebuilding the hosting view.
@MainActor
@Observable
final class DashboardModel {
    var route: DashboardRoute
    /// Opens the panel on arbitrary text (vault notes, pinned runs).
    let enhanceText: (String) -> Void
    /// Opens the panel on a vault note and writes Replace back into that note.
    let enhanceNote: (String) -> Void

    init(
        route: DashboardRoute = .general,
        enhanceText: @escaping (String) -> Void = { _ in },
        enhanceNote: @escaping (String) -> Void = { _ in }
    ) {
        self.route = route
        self.enhanceText = enhanceText
        self.enhanceNote = enhanceNote
    }
}

/// Hosts the dashboard in a normal titled window.
///
/// An `NSWindowController` rather than a SwiftUI `Window` scene, matching
/// `OnboardingWindowController`. The app is `LSUIElement`, which is exactly the
/// case SwiftUI's window scenes handle least predictably: with no Dock icon the
/// process is never "active", so a scene opened through `openWindow` can appear
/// behind the frontmost app. Driving the window directly keeps activation and
/// ordering explicit, and gives control over the frame autosave name.
@MainActor
final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let model: DashboardModel

    init(
        enhanceText: @escaping (String) -> Void,
        enhanceNote: @escaping (String) -> Void
    ) {
        model = DashboardModel(
            enhanceText: enhanceText,
            enhanceNote: enhanceNote
        )
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: SettingsChrome.windowWidth,
                height: SettingsChrome.windowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Beru"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.isOpaque = true
        window.hasShadow = true
        window.backgroundColor = BeruColor.canvasNSColor
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 880, height: 560)
        window.setFrameAutosaveName("BeruDashboardFixed")
        window.center()
        super.init(window: window)
        window.delegate = self
        let hosting = DashboardHostingView(rootView: DashboardView(model: model))
        hosting.sizingOptions = []
        hosting.setContentHuggingPriority(.defaultLow, for: .vertical)
        hosting.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hosting.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        hosting.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        window.contentView = hosting
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; the dashboard is created in code")
    }

    /// Brings the window forward, optionally jumping to a section first.
    ///
    /// `activate(ignoringOtherApps:)` is required rather than defensive: an
    /// `LSUIElement` process is never frontmost, so `makeKeyAndOrderFront`
    /// alone puts the window behind whatever the user was using — the same
    /// wrinkle the menu bar's Settings item already works around.
    func show(route: DashboardRoute? = nil) {
        if let route { model.route = route }
        // Become a regular app for as long as the dashboard is open.
        //
        // `LSUIElement` makes the process an accessory, and an accessory has no
        // menu bar — which costs more than the Dock icon it saves. Without a
        // menu bar there is no Edit menu, so Cut, Copy, Paste, Select All and
        // Undo have nothing to route to and stop working inside the window's
        // text fields; ⌘W and ⌘Q go the same way. A window built around editing
        // prompts and instructions cannot ship without them.
        //
        // The panel is unaffected: it is non-activating and driven by a global
        // hotkey, neither of which depends on the activation policy.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Drop back to accessory so closing the dashboard removes the Dock icon
    /// and returns the app to being a menu bar utility.
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// SwiftUI reports a new intrinsic height whenever the selected tab's content
/// changes. `NSHostingView` forwards that to the window, so General → Models
/// grows the frame. This view never participates in that chain: the window
/// size is whatever the user (or the autosave) last set.
private final class DashboardHostingView<Content: View>: NSHostingView<Content> {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func invalidateIntrinsicContentSize() {}
}
