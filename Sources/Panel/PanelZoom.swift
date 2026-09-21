import AppKit

// Green-disc zoom: the panel fills the visible screen; a second click
// restores the pre-zoom frame and re-resolves. Show/hide/resize stay in
// PanelController; this file owns only the zoom state machine.
//
// Layout reports keep arriving while zoomed — `setLayoutHeights` sizes the
// result's scroll budget to the fullscreen frame and never moves the window.

extension PanelController {
    /// Green-disc zoom: fill the visible screen; click again to restore the
    /// pre-zoom frame and re-resolve. Layout reports keep arriving while
    /// zoomed — they size the result's scroll budget, never the window.
    func toggleZoom() {
        guard let panel else { return }
        if appState.isPanelZoomed {
            appState.isPanelZoomed = false
            appState.panelResultScrollHeight = nil
            if let saved = preZoomFrame {
                preZoomFrame = nil
                setPanelFrame(saved, animated: true)
            }
            if let last = lastResolvedLayout {
                setLayoutHeights(last)
            }
            return
        }
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        appState.isPanelZoomed = true
        preZoomFrame = panel.frame
        pendingResize?.cancel()
        setPanelFrame(NSRect(origin: visible.origin, size: visible.size), animated: true)
        if let last = lastResolvedLayout {
            setLayoutHeights(last)
        }
    }

    /// Direct frame move shared by zoom in/out. Unlike content resizes this
    /// never pins an edge: the frame is already fully specified.
    private func setPanelFrame(_ frame: NSRect, animated: Bool) {
        guard let panel, panel.isVisible else { return }
        isProgrammaticMove = true
        if animated, !a11y.reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    self?.isProgrammaticMove = false
                    self?.pinnedTopY = frame.maxY
                    self?.panel?.invalidateShadow()
                }
            }
        } else {
            panel.setFrame(frame, display: true)
            isProgrammaticMove = false
            pinnedTopY = frame.maxY
            panel.invalidateShadow()
        }
    }
}
