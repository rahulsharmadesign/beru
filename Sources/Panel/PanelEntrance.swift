import AppKit

// Entrance choreography. The unfurl math lives here; the invocation-point
// variant (`animateIn`) stays parked, and the live show path pours the panel
// out of the Dock edge (`animateInFromDockEdge`).
//
// macOS exposes no Dock icon rects, so the Dock contributes only its edge:
// `dockEdge` diffs the screen frame against the visible frame (top is always
// the menu bar, never the Dock). The panel keeps its cursor-anchored position
// and unfurls with the Dock-side edge pinned, which reads as rising out of
// the Dock without a full-screen fly-in on every invocation.
//
// Reuse safety: every show resets layer state before the reveal lands, and
// every hide resets before ordering out — a completed or interrupted reveal
// must never leave a transform, zero opacity, or a missing shadow behind for
// the next show. Reduce Motion always takes the plain fade.

extension PanelController {
    /// How long the reveal runs. PanelController also holds height changes
    /// until this settles: a hard resize mid-reveal is the other half of what
    /// made the entrance look broken.
    static let revealDuration: TimeInterval = 0.25
    /// How long the retract runs before the panel is ordered out.
    static let retractDuration: TimeInterval = 0.16

    /// Live entrance: the panel pours out of the Dock edge. Position stays
    /// cursor-anchored; only the unfurl's fixed point rides the Dock side.
    func animateInFromDockEdge(_ panel: FloatingPanel) {
        guard let layer = panel.contentView?.layer else {
            // No layer, no animation: the window must still be visible.
            panel.alphaValue = 1
            return
        }
        let screen = panel.screen ?? NSScreen.main
        let edge: CGRectEdge
        if let screen {
            edge = Self.dockEdge(frame: screen.frame, visible: screen.visibleFrame) ?? .minYEdge
        } else {
            edge = .minYEdge
        }
        runUnfurl(layer: layer, panel: panel, anchor: Self.anchorForDockEdge(edge, in: layer.bounds.size))
    }

    /// Defensive reset for window reuse. Called on show (before the reveal
    /// lands) and on hide (before ordering out) so a completed or interrupted
    /// animation never leaks a transform, zero opacity, or a missing shadow
    /// into the next show.
    static func resetLayerState(_ panel: FloatingPanel) {
        if let layer = panel.contentView?.layer {
            layer.removeAllAnimations()
            layer.transform = CATransform3DIdentity
            layer.opacity = 1
        }
        panel.alphaValue = 1
        panel.hasShadow = true
    }

    /// Which screen edge the Dock eats, if any. Pure geometry: the menu bar
    /// owns the top, so only left/right/bottom insets count. Nil when the
    /// Dock is hidden or the lone inset is the menu bar.
    nonisolated static func dockEdge(frame: CGRect, visible: CGRect) -> CGRectEdge? {
        let candidates: [(CGRectEdge, CGFloat)] = [
            (.minXEdge, visible.minX - frame.minX),
            (.maxXEdge, frame.maxX - visible.maxX),
            (.minYEdge, visible.minY - frame.minY),
        ]
        guard let best = candidates.max(by: { $0.1 < $1.1 }), best.1 > 1 else { return nil }
        return best.0
    }

    /// Slab point the unfurl pins for a Dock edge, in layer coordinates.
    nonisolated static func anchorForDockEdge(_ edge: CGRectEdge, in size: CGSize) -> CGPoint {
        switch edge {
        case .minXEdge: return CGPoint(x: 0, y: size.height / 2)
        case .maxXEdge: return CGPoint(x: size.width, y: size.height / 2)
        case .maxYEdge: return CGPoint(x: size.width / 2, y: size.height)
        case .minYEdge: return CGPoint(x: size.width / 2, y: 0)
        @unknown default: return CGPoint(x: size.width / 2, y: 0)
        }
    }

    /// Shared unfurl runner: non-uniform scale about the anchor plus a fast
    /// fade, with the window shadow parked while the slab is small. Both the
    /// parked invocation-point reveal and the live Dock-edge reveal run here
    /// so the keyframes cannot drift apart.
    private func runUnfurl(layer: CALayer, panel: FloatingPanel, anchor: CGPoint) {
        layer.removeAllAnimations()
        layer.transform = CATransform3DIdentity
        layer.opacity = 1

        let size = layer.bounds.size

        guard !a11y.reduceMotion else {
            panel.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
            return
        }

        // The window shadow cannot follow a layer transform: hide it while the
        // slab is small, restore it as the slab lands.
        panel.hasShadow = false

        let unfurl = CAKeyframeAnimation(keyPath: "transform")
        unfurl.values = [
            // Born small, pinned at the anchor — then one clean ease to rest.
            // No overshoot: bounce on a utility panel reads as rubber.
            NSValue(caTransform3D: Self.scaleTransform(0.88, 0.92, about: anchor, in: size)),
            NSValue(caTransform3D: CATransform3DIdentity)
        ]
        unfurl.keyTimes = [0, 1]
        unfurl.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
        ]
        unfurl.duration = Self.revealDuration
        layer.add(unfurl, forKey: "panel.in")

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.16
        fade.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
        layer.add(fade, forKey: "panel.in.opacity")

        // Back on before the slab finishes settling, so the shadow does not
        // visibly pop in at the end.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealDuration * 0.72) { [weak panel] in
            panel?.hasShadow = true
            panel?.invalidateShadow()
        }
    }

    /// Genie-style entrance: the panel unfolds out of the invocation point.
    /// Parked: the live show path uses the Dock edge instead.
    ///
    /// Non-uniform on purpose. The slab is born narrower than it is short
    /// (`narrow` < `short`) and pinned to the invocation point, so the first
    /// frames read as material being poured out of the selection; a uniform
    /// scale reads as a plain zoom from a corner.
    func animateIn(_ panel: FloatingPanel, to point: CGPoint?) {
        guard let layer = panel.contentView?.layer else {
            // No layer, no animation: the window must still be visible.
            panel.alphaValue = 1
            return
        }

        let size = layer.bounds.size
        let anchor = Self.clampedAnchor(point, in: size, growsDownward: growsDownward)
        runUnfurl(layer: layer, panel: panel, anchor: anchor)
    }

    /// The exit half: the slab draws back toward the point it came from, so
    /// dismissing mirrors the entrance instead of fading out in place.
    func retract(_ panel: FloatingPanel, from current: NSRect, anchor: CGPoint?) {
        guard !a11y.reduceMotion, let layer = panel.contentView?.layer else {
            panel.alphaValue = 0
            panel.hasShadow = true
            return
        }
        layer.removeAllAnimations()
        let size = layer.bounds.size
        let localAnchor = Self.localAnchor(anchor, frame: current, size: size, growsDownward: growsDownward)

        panel.hasShadow = false
        let collapse = CAKeyframeAnimation(keyPath: "transform")
        collapse.values = [
            NSValue(caTransform3D: CATransform3DIdentity),
            NSValue(caTransform3D: Self.scaleTransform(0.94, 1.02, about: localAnchor, in: size)),
            NSValue(caTransform3D: Self.scaleTransform(0.58, 0.70, about: localAnchor, in: size))
        ]
        collapse.keyTimes = [0, 0.34, 1]
        collapse.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.3, 0.0, 0.4, 1.0),
            CAMediaTimingFunction(controlPoints: 0.5, 0.0, 0.8, 1.0)
        ]
        collapse.duration = Self.retractDuration
        layer.add(collapse, forKey: "panel.out")

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = Self.retractDuration
        fade.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.8, 1.0)
        layer.add(fade, forKey: "panel.out.opacity")
    }

    /// Converts a screen-space anchor into the slab's own coordinates.
    nonisolated static func localAnchor(
        _ point: CGPoint?,
        frame: NSRect,
        size: CGSize,
        growsDownward: Bool
    ) -> CGPoint {
        guard let point else {
            return CGPoint(x: size.width / 2, y: growsDownward ? size.height : 0)
        }
        return clampedAnchor(
            CGPoint(x: point.x - frame.minX, y: point.y - frame.minY),
            in: size,
            growsDownward: growsDownward
        )
    }

    /// Scales about an arbitrary point so a transform can be anchored on the
    /// invocation point instead of the layer's center. Non-uniform on purpose:
    /// the difference between the axes is what reads as unfolding.
    ///
    /// Form: scale, then shift by `(1 - s) * anchor`. Scaling about `a` is
    /// `S(p - a) + a`, which rearranges to `S(p) + (1 - s) * a` — so the shift
    /// must be built from the anchor itself, not from the anchor minus the
    /// center. (The old helper subtracted the center here, which planted the
    /// fixed point off the panel and skewed every anchored transform.)
    nonisolated static func scaleTransform(
        _ sx: CGFloat,
        _ sy: CGFloat,
        about point: CGPoint,
        in size: CGSize
    ) -> CATransform3D {
        let dx = (1 - sx) * point.x
        let dy = (1 - sy) * point.y
        return CATransform3DConcat(
            CATransform3DMakeScale(sx, sy, 1),
            CATransform3DMakeTranslation(dx, dy, 0)
        )
    }

    /// Keeps the transform origin inside the slab, and falls back to the edge
    /// the panel grows from when the invoke carried no cursor point (dictation,
    /// menu bar, a hotkey with no capture).
    nonisolated static func clampedAnchor(
        _ point: CGPoint?,
        in size: CGSize,
        growsDownward: Bool
    ) -> CGPoint {
        guard let point else {
            return CGPoint(x: size.width / 2, y: growsDownward ? size.height : 0)
        }
        return CGPoint(x: min(max(point.x, 0), size.width), y: min(max(point.y, 0), size.height))
    }
}