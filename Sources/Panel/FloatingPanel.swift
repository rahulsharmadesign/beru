import AppKit
import SwiftUI

/// Opaque rounded card. The window-server shadow is derived from this view's
/// alpha, so the mask must stay rounded as the panel resizes.
private final class RoundedPanelView: NSView {
    override var isOpaque: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    override func layout() {
        super.layout()
        updateMask()
        refreshColors()
    }

    func refreshColors() {
        wantsLayer = true
        effectiveAppearance.performAsCurrentDrawingAppearance { [self] in
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }

    private func updateMask() {
        wantsLayer = true
        layer?.mask = nil
        layer?.cornerRadius = PanelMetrics.cornerRadius
        layer?.cornerCurve = .circular
        layer?.masksToBounds = true
    }
}

/// A borderless, non-activating panel that floats above the active app without
/// stealing keyboard focus or the Dock/menu bar highlight from the host application.
///
/// Depth comes from `NSWindow.hasShadow` — the same window-server shadow the
/// Settings window uses. CALayer shadows inside a transparent panel do not
/// composite, which is why a custom shadow was invisible on dark hosts.
final class FloatingPanel: NSPanel {
    /// The solid backdrop the SwiftUI content sits on.
    let backdropView: NSView

    init(contentRect: NSRect) {
        let card = RoundedPanelView(frame: contentRect)
        card.wantsLayer = true
        card.layer?.cornerRadius = PanelMetrics.cornerRadius
        card.layer?.cornerCurve = .circular
        card.autoresizingMask = [.width, .height]
        self.backdropView = card

        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.contentView = card

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = true
        isOpaque = true
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        syncAppearance()
    }

    /// Keep the AppKit backdrop in lockstep with SwiftUI. Snapshotting
    /// `controlBackgroundColor.cgColor` at init left a white frame in dark mode.
    func syncAppearance(with appearance: NSAppearance = NSApp.effectiveAppearance) {
        self.appearance = appearance
        appearance.performAsCurrentDrawingAppearance { [self] in
            backgroundColor = .windowBackgroundColor
            (backdropView as? RoundedPanelView)?.refreshColors()
        }
    }

    // Required for text entry. canBecomeMain stays false so the app never
    // takes the menu bar or app-switcher highlight from the host app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Seats the field editor on the panel's first text field. Changes the
    /// responder within this window only — it does NOT activate the app, so
    /// the host application stays frontmost.
    func focusFirstTextField() {
        guard let contentView else { return }
        var queue: [NSView] = [contentView]
        while !queue.isEmpty {
            let view = queue.removeFirst()
            if view is NSTextField || view is NSTextView, view.acceptsFirstResponder {
                makeFirstResponder(view)
                return
            }
            queue.append(contentsOf: view.subviews)
        }
    }
}

/// Owns the lifecycle of the floating panel and hosts the SwiftUI content.
@MainActor
final class PanelController {
    private var panel: FloatingPanel?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    /// Incremented on every show so a stale hide completion can't order out a
    /// panel that has since been re-shown.
    private var showGeneration = 0
    private var pendingResize: DispatchWorkItem?
    /// While tokens are arriving the panel only grows; shrinking on every
    /// reflow makes it visibly oscillate.
    private var isStreaming = false
    private var growsDownward = true
    /// Absolute top edge to pin while growing downward. Incremental
    /// `origin += current - target` plus clamp was letting the panel creep
    /// down across resizes within a run.
    private var pinnedTopY: CGFloat?
    /// Block preference-driven animated resizes while the entrance spring runs,
    /// so the top of the panel doesn't tear against the window shadow.
    private var entranceSettledAt: CFAbsoluteTime = 0

    /// True while the controller itself is setting the panel's frame. Used to
    /// tell a programming-driven move apart from a user drag in `panelDidMove`,
    /// so a manual drag re-pins growth instead of being mistaken for our resize.
    private var isProgrammaticMove = false
    /// Tracks user-initiated drags so a later height change extends from where
    /// the user dropped the panel rather than snapping back to the anchor it was
    /// presented at.
    private var moveObserver: NSObjectProtocol?

    private var a11y: AccessibilityPreferences { AccessibilityPreferences.shared }

    func show(at point: CGPoint, appState: AppState, engine: PanelEngine) {
        showGeneration += 1
        pendingResize?.cancel()
        isStreaming = true
        // Spring settle; height applies still run, but without animator/shadow
        // thrash until this passes.
        entranceSettledAt = CFAbsoluteTimeGetCurrent() + 0.55

        let widgetSize = CGSize(width: PanelMetrics.width, height: PanelMetrics.minHeight)
        let size = CGSize(
            width: PanelMetrics.windowWidth,
            height: PanelMetrics.windowHeight(for: widgetSize.height)
        )
        let inset = PanelMetrics.shadowInset
        // `point` is the selection's bottom-left (or mouse). The visible widget
        // still sits below it; the transparent margin only contains the soft shadow.
        let preferred = CGPoint(
            x: point.x - inset,
            y: point.y - widgetSize.height - SelectionLocator.panelGapBelowSelection - inset
        )
        let origin = clampedOrigin(preferred: preferred, size: size)
        // If clamping pushed the panel up past the selection it is now above
        // the anchor, so it should grow upward instead.
        growsDownward = origin.y <= preferred.y + 1

        let panel = self.panel ?? makePanel(engine: engine)
        self.panel = panel
        panel.syncAppearance()

        let frame = NSRect(origin: origin, size: size)
        pinnedTopY = frame.maxY
        isProgrammaticMove = true
        panel.setFrame(frame, display: false)
        isProgrammaticMove = false
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()

        // Drop the responder left over from the previous invocation, then seat
        // a fresh one after the hosting view has materialized its AppKit
        // backing (which happens after the window is ordered in).
        panel.makeFirstResponder(nil)
        DispatchQueue.main.async { panel.focusFirstTextField() }

        animateIn(panel)
    }

    /// Springs up from the edge nearest the selection. Driven from AppKit
    /// because the hosting view is reused, so SwiftUI's onAppear never fires
    /// again after the first invocation.
    private func animateIn(_ panel: FloatingPanel) {
        guard let layer = panel.contentView?.layer else { return }
        layer.removeAllAnimations()
        layer.transform = CATransform3DIdentity
        layer.opacity = 1

        guard !a11y.reduceMotion else {
            panel.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
            return
        }

        let size = layer.bounds.size
        let anchor = CGPoint(x: 0, y: growsDownward ? size.height : 0)
        let spring = CASpringAnimation(keyPath: "transform")
        spring.damping = 20
        spring.stiffness = 160
        spring.mass = 1
        spring.fromValue = NSValue(caTransform3D: Self.scaleTransform(0.92, about: anchor, in: size))
        spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        spring.duration = spring.settlingDuration
        layer.add(spring, forKey: "panel.in")

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.28
        fade.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
        layer.add(fade, forKey: "panel.in.opacity")
    }

    /// Scale about an arbitrary point without touching layer.anchorPoint,
    /// which AppKit re-derives during layout and would fight on every resize.
    private static func scaleTransform(_ scale: CGFloat, about point: CGPoint, in size: CGSize) -> CATransform3D {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = (1 - scale) * (point.x - center.x)
        let dy = (1 - scale) * (point.y - center.y)
        return CATransform3DConcat(
            CATransform3DMakeScale(scale, scale, 1),
            CATransform3DMakeTranslation(dx, dy, 0)
        )
    }

    func hide() {
        guard let panel else { return }
        pendingResize?.cancel()
        isStreaming = false
        showGeneration += 1
        let generation = showGeneration

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.showGeneration == generation else { return }
            self.panel?.orderOut(nil)
        }
    }

    /// Called from SwiftUI as content is laid out. Debounced on top of the
    /// engine's stream coalescing, with a deadband, so the window doesn't
    /// resize on every token. Longer debounce while streaming — height thrash
    /// plus `invalidateShadow` was a major heat source.
    func setDesiredHeight(_ height: CGFloat) {
        pendingResize?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.applyHeight(height) }
        pendingResize = work
        let delay: TimeInterval = isStreaming ? 0.16 : 0.08
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Lets the panel settle to its true content height once a stream ends.
    func streamingDidEnd() {
        isStreaming = false
        // One shadow refresh after growth finishes — not on every token.
        panel?.invalidateShadow()
    }

    /// The panel moved. This fires for every frame change — our own resizes and
    /// the user's drags alike. A move we did not programmatically set is a user
    /// drag: re-pin the growth anchor so the panel keeps growing from wherever
    /// the user placed it instead of jumping back to the presentation position.
    private func panelDidMove() {
        guard !isProgrammaticMove, let panel, growsDownward else { return }
        pinnedTopY = panel.frame.maxY
    }

    /// The tallest the window may grow before its content scrolls: 80% of the
    /// visible height of whichever screen the panel is on. Auto-sizing to content
    /// (via PanelHeightKey) means the panel only scrolls once it hits this.
    private func maxPanelHeight() -> CGFloat {
        let reference = panel?.frame.origin ?? .zero
        let screen = NSScreen.screens.first(where: { $0.frame.contains(reference) }) ?? NSScreen.main
        let visible = screen?.visibleFrame.height ?? PanelMetrics.maxHeight
        return min(PanelMetrics.maxHeight, (visible * PanelMetrics.maxViewportFraction).rounded() - PanelMetrics.shadowInset * 2)
    }

    private func applyHeight(_ height: CGFloat) {
        guard let panel, panel.isVisible else { return }
        let targetWidgetHeight = min(max(height.rounded(), PanelMetrics.minHeight), maxPanelHeight())
        let targetWindowHeight = PanelMetrics.windowHeight(for: targetWidgetHeight)
        let current = panel.frame.height
        guard abs(current - targetWindowHeight) >= PanelMetrics.resizeDeadband else { return }
        if isStreaming, targetWindowHeight < current { return }

        var frame = panel.frame
        frame.size.height = targetWindowHeight
        if growsDownward {
            // Pin to the absolute top captured at show — not a delta on the
            // current origin, which crept after clamp/round trips.
            let top = pinnedTopY ?? frame.maxY
            frame.origin.y = top - targetWindowHeight
        }
        frame.origin = clampedOrigin(preferred: frame.origin, size: frame.size)
        if growsDownward {
            pinnedTopY = frame.maxY
        }

        let entrancePending = CFAbsoluteTimeGetCurrent() < entranceSettledAt
        // During entrance or streaming: hard setFrame, no animator. Animated
        // resize + spring + shadow was tearing the top edge for ~2s on open.
        if a11y.reduceMotion || isStreaming || entrancePending {
            isProgrammaticMove = true
            panel.setFrame(frame, display: true)
            isProgrammaticMove = false
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        }
        // Shadow invalidation is expensive (full window backdrop). Skip while
        // streaming/entrance; `streamingDidEnd` refreshes once.
        if !isStreaming, !entrancePending {
            panel.invalidateShadow()
        }
    }

    private func makePanel(engine: PanelEngine) -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PanelMetrics.windowWidth,
                height: PanelMetrics.windowHeight(for: PanelMetrics.minHeight)
            )
        )

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panelDidMove() }
        }

        // The white backdrop is the content view (set in FloatingPanel.init).
        // Add the SwiftUI hosting view as a subview on top of it.
        let hosting = PanelHostingView(
            rootView: PanelView(appState: appState, engine: engine) { [weak self] height in
                self?.setDesiredHeight(height)
            }
        )
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.backdropView.addSubview(hosting)
        let inset = PanelMetrics.windowInset
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: panel.backdropView.topAnchor, constant: PanelMetrics.windowTopInset),
            hosting.bottomAnchor.constraint(equalTo: panel.backdropView.bottomAnchor, constant: -inset),
            hosting.leadingAnchor.constraint(equalTo: panel.backdropView.leadingAnchor, constant: inset),
            hosting.trailingAnchor.constraint(equalTo: panel.backdropView.trailingAnchor, constant: -inset)
        ])

        return panel
    }

    private func clampedOrigin(preferred: CGPoint, size: CGSize) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(preferred) }) ?? NSScreen.main else {
            return preferred
        }
        let visible = screen.visibleFrame
        let inset = PanelMetrics.screenInset
        var origin = preferred
        origin.x = min(max(origin.x, visible.minX + inset), visible.maxX - size.width - inset)
        origin.y = min(max(origin.y, visible.minY + inset), visible.maxY - size.height - inset)
        return origin
    }
}

/// Clicks on empty chrome drag via `PanelDragRegion`. Do not remap `hitTest` —
/// SwiftUI chips and the close button are not `NSControl`s, and stealing their
/// clicks is what broke tab switching and dismiss.
private final class PanelHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension NSView {
    /// `NSHostingView` ignores `mouseDownCanMoveWindow`. Track the drag ourselves.
    func beruBeginWindowDrag(with event: NSEvent) {
        guard let window else { return }
        let grab = event.locationInWindow
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { break }
            let mouse = NSEvent.mouseLocation
            window.setFrameOrigin(NSPoint(x: mouse.x - grab.x, y: mouse.y - grab.y))
        }
    }
}
