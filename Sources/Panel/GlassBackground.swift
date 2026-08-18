import AppKit
import SwiftUI

/// Plain opaque backing for the floating panel.
///
/// This keeps the rounded AppKit silhouette and shadow while removing every
/// trace of the former blur and translucency treatment.
struct BehindWindowBlur: NSViewRepresentable {
    var radius: CGFloat = PanelMetrics.cornerRadius

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        apply(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        apply(to: nsView)
    }

    private func apply(to view: NSView) {
        view.wantsLayer = true
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.layer?.backgroundColor = BrandColors.canvasNSColor.cgColor
        }
        view.layer?.cornerRadius = radius
        view.layer?.cornerCurve = .circular
        view.layer?.masksToBounds = true
    }
}
