import AppKit

// Parked. The unfurl math lives here, unused by the panel for now.
//
// A reveal from the invocation point ("poured out of the selection") needs the
// transform's fixed point planted exactly on the anchor — scale, then shift by
// (1 - s) * anchor — plus a shadow that can follow a layer transform while a
// window reuse never leaves sticky state behind. The last live attempt hid the
// shadow during the animation but could leave the window ordered front yet
// fully transparent when reused, and the panel is back to an instant reveal.
// Revisit only with resets on every path and a manual pass on a real machine.

extension PanelController {
    /// How long the reveal runs. PanelController also holds height changes
    /// until this settles: a hard resize mid-reveal is the other half of what
    /// made the entrance look broken.
    static let revealDuration: TimeInterval = 0.32
    /// How long the retract runs before the panel is ordered out.
    static let retractDuration: TimeInterval = 0.16

    /// Genie-style entrance: the panel unfolds out of the invocation point.
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
        layer.removeAllAnimations()
        layer.transform = CATransform3DIdentity
        layer.opacity = 1

        let size = layer.bounds.size
        let anchor = Self.clampedAnchor(point, in: size, growsDownward: growsDownward)

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
            // Born narrow and short, pinned at the point.
            NSValue(caTransform3D: Self.scaleTransform(0.62, 0.74, about: anchor, in: size)),
            // Unwinds across, a hair past its height.
            NSValue(caTransform3D: Self.scaleTransform(0.92, 1.02, about: anchor, in: size)),
            // Settles with a whisper of overshoot.
            NSValue(caTransform3D: Self.scaleTransform(1.008, 0.998, about: anchor, in: size)),
            NSValue(caTransform3D: CATransform3DIdentity)
        ]
        unfurl.keyTimes = [0, 0.46, 0.74, 1]
        unfurl.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.18, 0.9, 0.3, 1.0),
            CAMediaTimingFunction(controlPoints: 0.24, 1.0, 0.36, 1.0),
            CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
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