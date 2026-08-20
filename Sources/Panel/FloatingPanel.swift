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
            layer?.backgroundColor = BeruColor.canvasNSColor.cgColor
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
            backgroundColor = BeruColor.canvasNSColor
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
