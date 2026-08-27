import AppKit
import SwiftUI

/// Opaque rounded card used when Reduce Transparency is on. Liquid Glass has
/// no opacity control; Apple's fallback is a different material, not a dimmer
/// glass. The window-server shadow is derived from this view's alpha, so the
/// mask must stay rounded as the panel resizes.
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

    private     func updateMask() {
        wantsLayer = true
        layer?.mask = nil
        layer?.cornerRadius = PanelMetrics.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }
}

/// A borderless, non-activating panel that floats above the active app without
/// stealing keyboard focus or the Dock/menu bar highlight from the host application.
///
/// Default chrome is one `NSGlassEffectView` slab with the SwiftUI host as its
/// `contentView` — Apple's AppKit path. A slot-plus-subview sandwich painted
/// over the material and read as a white card. Reduce Transparency swaps the
/// slab for an opaque `RoundedPanelView` without recreating the host.
/// Depth comes from `NSWindow.hasShadow`.
@MainActor
final class FloatingPanel: NSPanel {
    private var hostedView: NSView?
    private var glassView: NSGlassEffectView?
    private var opaqueView: RoundedPanelView?
    private var usingOpaqueMaterial = false
    private var hasInstalledMaterial = false
    private var materialObserver: NSObjectProtocol?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = true
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        observeMaterial()
        syncAppearance()
    }

    deinit {
        if let materialObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(materialObserver)
        }
    }

    /// Seats the SwiftUI host as `NSGlassEffectView.contentView` (or on the
    /// opaque card). Call once after constructing the host.
    func attachHost(_ view: NSView) {
        hostedView = view
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = [.width, .height]
        hasInstalledMaterial = false
        installMaterial(in: nil)
    }

    /// Keep the AppKit backdrop in lockstep with SwiftUI. Snapshotting
    /// `controlBackgroundColor.cgColor` at init left a white frame in dark mode.
    func syncAppearance(with appearance: NSAppearance = NSApp.effectiveAppearance) {
        self.appearance = appearance
        appearance.performAsCurrentDrawingAppearance { [self] in
            if usingOpaqueMaterial {
                backgroundColor = BeruColor.canvasNSColor
                opaqueView?.refreshColors()
            } else {
                backgroundColor = .clear
            }
        }
    }

    /// Rebuilds chrome when Reduce Transparency flips. The SwiftUI host stays;
    /// only the window material around it changes.
    func installMaterial() {
        installMaterial(in: nil)
    }

    private func installMaterial(in rect: NSRect?) {
        let wantOpaque = AccessibilityPreferences.shared.reduceTransparency
        if hasInstalledMaterial, wantOpaque == usingOpaqueMaterial { return }
        hasInstalledMaterial = true

        hostedView?.removeFromSuperview()
        glassView?.contentView = nil
        glassView = nil
        opaqueView = nil

        guard let host = hostedView else { return }

        let bounds = rect ?? contentView?.bounds ?? contentRect(forFrameRect: frame)
        if wantOpaque {
            let card = RoundedPanelView(frame: bounds)
            card.wantsLayer = true
            card.layer?.cornerRadius = PanelMetrics.cornerRadius
            card.layer?.cornerCurve = .continuous
            card.autoresizingMask = [.width, .height]
            opaqueView = card
            contentView = card
            isOpaque = true
            usingOpaqueMaterial = true
            host.frame = card.bounds
            card.addSubview(host)
        } else {
            let glass = NSGlassEffectView(frame: bounds)
            glass.cornerRadius = PanelMetrics.cornerRadius
            glass.style = .regular
            glass.clipsToBounds = true
            glass.autoresizingMask = [.width, .height]
            glassView = glass
            contentView = glass
            isOpaque = false
            usingOpaqueMaterial = false
            host.frame = glass.bounds
            glass.contentView = host
        }
        syncAppearance()
        invalidateShadow()
    }

    private func observeMaterial() {
        materialObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.installMaterial() }
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
