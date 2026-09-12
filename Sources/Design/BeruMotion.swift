import SwiftUI

// Shared motion vocabulary. The panel window owns the spring recipe (see
// PanelController); these are the SwiftUI-side durations every component
// shares: a quick ease for color and fill changes, the pill pop curve for
// scale, and a hover ease. All collapse under Reduce Motion.

/// Step-change cross-fade shared by multi-step surfaces (onboarding).
enum BeruMotion {
    static let stepCrossfade: TimeInterval = 0.22
    /// Panel tab selection dissolve. 0.5s on purpose — a gentle switch, not a snap.
    static let tabSwitch: TimeInterval = 0.5
    /// One streamed word. Matches the print cadence of the typewriter.
    static let typewriterWord: TimeInterval = 0.055
    /// Last-word blur settle.
    static let typewriterBlur: TimeInterval = 0.15
    /// Caret blink. Off the typical 8pt rhythm on purpose — a cursor beat.
    static let typewriterCaret: TimeInterval = 0.53
}

private struct BeruEase: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Bool
    var duration: TimeInterval
    var inOut: Bool = false

    func body(content: Content) -> some View {
        let anim: Animation = inOut
            ? .easeInOut(duration: duration)
            : .easeOut(duration: duration)
        content.animation(reduceMotion ? nil : anim, value: value)
    }
}

extension View {
    /// Eases hover-driven fill changes so they glide instead of snap.
    func beruHoverEase(_ isHovered: Bool) -> some View {
        modifier(BeruEase(value: isHovered, duration: 0.12))
    }

    /// Eases selection color melts (accent washes, borders) to match the
    /// panel chips' cross-fade.
    func beruColorEase(_ value: Bool) -> some View {
        modifier(BeruEase(value: value, duration: 0.25))
    }

    /// Chip selection dissolve. Scoped to the chip so the panel window
    /// does not animate its height on a tab change.
    func beruTabSwitchEase(_ isSelected: Bool) -> some View {
        modifier(BeruEase(value: isSelected, duration: BeruMotion.tabSwitch, inOut: true))
    }

    /// Eases focus rings and glows.
    func beruFocusEase(_ isFocused: Bool) -> some View {
        modifier(BeruEase(value: isFocused, duration: 0.15))
    }
}
