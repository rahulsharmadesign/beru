import AppKit
import SwiftUI

// Presenting, sizing and dismissing the panel window. Split from
// FloatingPanel, which is the window itself.

/// Owns the lifecycle of the floating panel and hosts the SwiftUI content.
///
/// Height contract (frozen):
/// - SwiftUI reports chrome + result ideal heights via band preferences.
/// - Window height = min(chrome + result, 75% of visible screen).
/// - Below the cap: result is intrinsic. At the cap: result scrolls inside
///   `appState.panelResultScrollHeight`; close / chips / composer stay pinned.
/// - Grow immediately; shrink after a short debounce. Never drive height from
///   `NSHostingView.intrinsicContentSize`.
@MainActor
final class PanelController {
    private var panel: FloatingPanel?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    private var showGeneration = 0
    private var pendingResize: DispatchWorkItem?
    private var isStreaming = false
    private var growsDownward = true
    private var pinnedTopY: CGFloat?
    private var entranceSettledAt: CFAbsoluteTime = 0
    private var isProgrammaticMove = false
    private var moveObserver: NSObjectProtocol?
    private var isApplyingHeight = false
    private var lastAppliedHeight: CGFloat = 0
    private var lastChrome: CGFloat = 0

    private var a11y: AccessibilityPreferences { AccessibilityPreferences.shared }

    func show(at point: CGPoint, appState: AppState, engine: PanelEngine) {
        showGeneration += 1
        pendingResize?.cancel()
        isStreaming = false
        lastAppliedHeight = 0
        lastChrome = 0
        appState.panelResultScrollHeight = nil
        entranceSettledAt = CFAbsoluteTimeGetCurrent() + 0.55

        let widgetSize = CGSize(width: PanelMetrics.width, height: PanelMetrics.seedHeight)
        let size = CGSize(
            width: PanelMetrics.windowWidth,
            height: PanelMetrics.windowHeight(for: widgetSize.height)
        )
        let inset = PanelMetrics.shadowInset
        let preferred = CGPoint(
            x: point.x - inset,
            y: point.y - widgetSize.height - SelectionLocator.panelGapBelowSelection - inset
        )
        let origin = clampedOrigin(preferred: preferred, size: size)
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
        panel.makeFirstResponder(nil)
        DispatchQueue.main.async {
            panel.focusFirstTextField()
        }
        animateIn(panel)
    }

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
        appState.panelResultScrollHeight = nil
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

    /// Chrome + result ideal heights from SwiftUI band preferences.
    func setLayoutHeights(_ layout: PanelLayoutHeights) {
        guard layout.chrome > 1 || layout.result > 1 else { return }
        lastChrome = max(layout.chrome, lastChrome)

        let cap = maxPanelHeight()
        let chrome = layout.chrome > 1 ? layout.chrome : lastChrome
        let ideal = chrome + layout.result
        let capped = ideal > cap + 0.5

        let target: CGFloat
        let scrollHeight: CGFloat?
        if capped, chrome < cap {
            let scroll = max(PanelMetrics.resultIdleMinHeight, (cap - chrome).rounded())
            scrollHeight = scroll
            target = min(cap, (chrome + scroll).rounded())
        } else {
            scrollHeight = nil
            target = min(ideal, cap).rounded()
        }

        // Apply scroll budget before resizing so the next SwiftUI pass lays
        // out chrome + ScrollView inside the capped window (composer visible).
        if appState.panelResultScrollHeight != scrollHeight {
            appState.panelResultScrollHeight = scrollHeight
        }

        let growing = target > (panel?.frame.height ?? 0) + 0.5
        if growing {
            pendingResize?.cancel()
            applyContentHeight(target)
            return
        }

        if isStreaming { return }
        if CFAbsoluteTimeGetCurrent() < entranceSettledAt { return }

        pendingResize?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.applyContentHeight(target)
        }
        pendingResize = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    func streamingDidStart() {
        isStreaming = true
    }

    func streamingDidEnd() {
        isStreaming = false
        panel?.invalidateShadow()
    }

    private func panelDidMove() {
        guard !isProgrammaticMove, let panel, growsDownward else { return }
        pinnedTopY = panel.frame.maxY
    }

    /// 75% of the visible frame on the panel's screen.
    func maxPanelHeight() -> CGFloat {
        let reference = panel?.frame.origin ?? .zero
        let screen = NSScreen.screens.first(where: { $0.frame.contains(reference) }) ?? NSScreen.main
        let visible = screen?.visibleFrame.height ?? PanelMetrics.maxHeight
        let windowChrome = PanelMetrics.shadowInset * 2
            + PanelMetrics.windowTopInset
            + PanelMetrics.windowInset
        let cap = (visible * PanelMetrics.maxViewportFraction).rounded() - windowChrome
        return min(PanelMetrics.maxHeight, max(PanelMetrics.seedHeight, cap))
    }

    private func applyContentHeight(_ height: CGFloat) {
        guard let panel, panel.isVisible, !isApplyingHeight else { return }
        let targetWidgetHeight = min(height.rounded(), maxPanelHeight())
        let targetWindowHeight = PanelMetrics.windowHeight(for: targetWidgetHeight)
        let current = panel.frame.height
        guard abs(current - targetWindowHeight) >= PanelMetrics.resizeDeadband else {
            lastAppliedHeight = targetWidgetHeight
            return
        }

        var frame = panel.frame
        frame.size.height = targetWindowHeight
        if growsDownward {
            let top = pinnedTopY ?? frame.maxY
            frame.origin.y = top - targetWindowHeight
        }
        frame.origin = clampedOrigin(preferred: frame.origin, size: frame.size)
        if growsDownward {
            pinnedTopY = frame.maxY
        }

        isApplyingHeight = true
        isProgrammaticMove = true
        panel.setFrame(frame, display: true)
        isProgrammaticMove = false
        isApplyingHeight = false
        lastAppliedHeight = targetWidgetHeight
        panel.invalidateShadow()
    }

    private func makePanel(engine: PanelEngine) -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: PanelMetrics.windowWidth,
                height: PanelMetrics.windowHeight(for: PanelMetrics.seedHeight)
            )
        )

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panelDidMove() }
        }

        let hosting = PanelHostingView(
            rootView: PanelView(appState: appState, engine: engine) { [weak self] layout in
                self?.setLayoutHeights(layout)
            }
        )
        hosting.sceneBridgingOptions = []
        hosting.safeAreaRegions = []
        hosting.wantsLayer = true
        hosting.layer?.isOpaque = false
        hosting.layer?.backgroundColor = .clear
        panel.attachHost(hosting)

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

/// Hosts SwiftUI. Window height comes only from layout band preferences.
private final class PanelHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clearHostFill()
    }

    override func layout() {
        super.layout()
        clearHostFill()
        if let container = superview {
            frame = container.bounds
        }
        clipsToBounds = true
    }

    private func clearHostFill() {
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = .clear
    }
}

extension NSView {
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
