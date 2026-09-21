import AppKit
import SwiftUI

// Presenting, sizing and dismissing the panel window. Split from
// FloatingPanel, which is the window itself.

import os.log

private let layoutLog = Logger(subsystem: "com.rahul.beru", category: "panel-layout")

/// Owns the lifecycle of the floating panel and hosts the SwiftUI content.
///
/// Height contract (frozen):
/// - SwiftUI reports chrome + result ideal heights via band preferences.
/// - Incomplete chrome bands are ignored; undersized chrome keeps the last real
///   measure so a tab swap cannot clip the close strip or composer.
/// - Window height = min(chrome + result, 75% of visible screen).
/// - Below the cap: result is intrinsic. At the cap: result scrolls inside
///   `appState.panelResultScrollHeight`; close / chips / composer stay pinned.
/// - Grow immediately and unanimated. Tab-change shrinks are skipped so
///   Search ↔ Enhance cannot jump the window; leftover height sits between
///   the result and the composer. Other shrinks debounce. Never drive height
///   from `NSHostingView.intrinsicContentSize` (`sizingOptions` stays empty).
@MainActor
final class PanelController {
    /// Internal for PanelZoom.swift, which owns the green-disc zoom state
    /// machine while this file owns show/hide/resize.
    var panel: FloatingPanel?
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    private var showGeneration = 0
    /// Internal for PanelZoom.swift.
    var pendingResize: DispatchWorkItem?
    private var isStreaming = false
    /// Internal for PanelZoom.swift.
    var preZoomFrame: NSRect?
    /// True from hide() until the next show(). Band reports arriving mid-fade
    /// (state clears synchronously on dismiss) must not resize a window that
    /// is going away — that resize-during-fade is the close-button jump.
    private var isHiding = false
    /// Internal, not private: the entrance/retract choreography lives in
    /// PanelEntrance.swift and reads these.
    var growsDownward = true
    /// Internal for PanelZoom.swift.
    var pinnedTopY: CGFloat?
    private var entranceSettledAt: CFAbsoluteTime = 0
    /// Internal for PanelZoom.swift.
    var isProgrammaticMove = false
    private var moveObserver: NSObjectProtocol?
    private var isApplyingHeight = false
    private var lastAppliedHeight: CGFloat = 0
    private var lastChrome: CGFloat = 0
    private var lastResult: CGFloat = 0
    private var lastActionID: String?
    /// Internal for PanelZoom.swift, which re-resolves after unzooming.
    var lastResolvedLayout: PanelLayoutHeights?
    /// Once the user switches tabs this session, never shrink below the
    /// height already on screen. Search (no footer, thread) and Enhance
    /// (footer, diff) disagree enough to jump the window otherwise.
    private var heightFrozen = false

    /// Internal for PanelEntrance.swift, which shares the reduce-motion check.
    var a11y: AccessibilityPreferences { AccessibilityPreferences.shared }

    func show(at point: CGPoint, appState: AppState, engine: PanelEngine) {
        showGeneration += 1
        let generation = showGeneration
        isHiding = false
        appState.isPanelZoomed = false
        preZoomFrame = nil
        pendingResize?.cancel()
        isStreaming = false
        lastAppliedHeight = 0
        lastChrome = 0
        lastResult = 0
        lastActionID = nil
        lastResolvedLayout = nil
        heightFrozen = false
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
        Self.resetLayerState(panel)
        panel.makeKeyAndOrderFront(nil)
        animateInFromDockEdge(panel)
        panel.invalidateShadow()
        // A hide fade still in flight would land alpha 0 on completion and
        // blank this show. Re-assert past its 0.12s duration.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak panel] in
            guard let self, let panel, self.showGeneration == generation, !self.isHiding else { return }
            panel.alphaValue = 1
        }
        panel.makeFirstResponder(nil)
        DispatchQueue.main.async {
            panel.focusFirstTextField()
        }
    }

    func hide() {
        guard let panel else { return }
        isHiding = true
        pendingResize?.cancel()
        isStreaming = false
        appState.panelResultScrollHeight = nil
        showGeneration += 1
        let generation = showGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.showGeneration == generation else { return }
            if let panel = self.panel {
                // Order out first: resetting alpha while still front is what
                // flashed the panel back for a frame on close.
                panel.orderOut(nil)
                Self.resetLayerState(panel)
            }
        }
    }

    /// Chrome + result ideal heights from SwiftUI band preferences.
    /// Ignored while hiding: dismiss clears state synchronously, and sizing
    /// a fading window to the emptied content is the close-button jump.
    func setLayoutHeights(_ layout: PanelLayoutHeights) {
        guard !isHiding else { return }
        let previousResult = lastResult
        guard let applied = PanelLayoutHeights.resolved(
            layout: layout,
            lastChrome: lastChrome,
            lastResult: lastResult
        ) else { return }
        lastChrome = applied.lastChrome
        lastResult = applied.lastResult
        lastResolvedLayout = PanelLayoutHeights(chrome: applied.chrome, result: applied.result)
        // Zoomed: size the result's scroll budget to the fullscreen frame,
        // never the window itself.
        if appState.isPanelZoomed, let panel {
            let fill = max(PanelMetrics.resultIdleMinHeight, (panel.frame.height - applied.chrome).rounded())
            if appState.panelResultScrollHeight != fill {
                appState.panelResultScrollHeight = fill
            }
            return
        }
        let resultGrew = applied.result > previousResult + 0.5

        let cap = maxPanelHeight()
        let chrome = applied.chrome
        let ideal = chrome + applied.result
        let capped = ideal > cap + 0.5

        let computed: CGFloat
        let scrollHeight: CGFloat?
        if capped, chrome < cap {
            let scroll = max(PanelMetrics.resultIdleMinHeight, (cap - chrome).rounded())
            scrollHeight = scroll
            computed = min(cap, (chrome + scroll).rounded())
        } else {
            scrollHeight = nil
            // Resting floor: the window never opens shorter than 60% of the
            // visible screen. Leftover height sits between the result and the
            // composer per the frozen height contract.
            computed = max(min(ideal, cap), PanelLayoutHeights.restingFloor(cap: cap)).rounded()
        }

        // Apply scroll budget before resizing so the next SwiftUI pass lays
        // out chrome + ScrollView inside the capped window (composer visible).
        if appState.panelResultScrollHeight != scrollHeight {
            appState.panelResultScrollHeight = scrollHeight
        }

        layoutLog.debug("layout chrome=\(applied.chrome, format: .fixed(precision: 0)) result=\(applied.result, format: .fixed(precision: 0)) ideal=\(applied.chrome + applied.result, format: .fixed(precision: 0)) cap=\(self.maxPanelHeight(), format: .fixed(precision: 0)) scroll=\(scrollHeight ?? -1, format: .fixed(precision: 0))")

        let isTabChange = lastActionID != nil && lastActionID != appState.selectedActionID
        if isTabChange { heightFrozen = true }
        rememberActionID()

        let target = PanelLayoutHeights.frozenTarget(
            computed: computed,
            lastApplied: lastAppliedHeight,
            heightFrozen: heightFrozen,
            resultGrew: resultGrew
        )
        let growing = target > (panel?.frame.height ?? 0) + 0.5
        if growing {
            pendingResize?.cancel()
            applyContentHeight(target, animated: false)
            return
        }
        if heightFrozen {
            pendingResize?.cancel()
            return
        }

        switch PanelLayoutHeights.shrinkBehavior(isTabChange: isTabChange, isStreaming: isStreaming) {
        case .applyNowUnanimated:
            pendingResize?.cancel()
            applyContentHeight(target, animated: false)
        case .skip:
            return
        case .debounceAnimated:
            pendingResize?.cancel()
            let delay: TimeInterval
            if CFAbsoluteTimeGetCurrent() < entranceSettledAt {
                // Preference callbacks during the entrance window used to `return`
                // without scheduling, so a seed-height panel never shrank once
                // SwiftUI went quiet.
                delay = max(0.12, entranceSettledAt - CFAbsoluteTimeGetCurrent() + 0.02)
            } else {
                delay = 0.12
            }
            let work = DispatchWorkItem { [weak self] in
                self?.applyContentHeight(target, animated: true)
            }
            pendingResize = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    func streamingDidStart() {
        isStreaming = true
    }

    func streamingDidEnd() {
        isStreaming = false
        panel?.invalidateShadow()
        if let lastResolvedLayout {
            setLayoutHeights(lastResolvedLayout)
        }
    }

    private func rememberActionID() {
        lastActionID = appState.selectedActionID
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

    private func applyContentHeight(_ height: CGFloat, animated: Bool = false) {
        guard let panel, panel.isVisible, !isApplyingHeight else {
            layoutLog.debug("applyContentHeight skipped visible=\(self.panel?.isVisible ?? false) applying=\(self.isApplyingHeight)")
            return
        }
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
        if animated, !a11y.reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.isProgrammaticMove = false
                    self?.panel?.invalidateShadow()
                }
            }
            isApplyingHeight = false
        } else {
            panel.setFrame(frame, display: true)
            isProgrammaticMove = false
            isApplyingHeight = false
            panel.invalidateShadow()
        }
        lastAppliedHeight = targetWidgetHeight
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
        // Same as the dashboard: an empty set. The default includes
        // intrinsicContentSize, which sizes the host to SwiftUI's ideal, then
        // layout() forces the window's bounds — the mismatch centers overflow
        // and shears the 10pt inset on tab switch.
        hosting.sizingOptions = []
        hosting.setContentHuggingPriority(.defaultLow, for: .vertical)
        hosting.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hosting.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        hosting.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
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
