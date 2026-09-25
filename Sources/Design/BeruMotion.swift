import SwiftUI

// Shared motion vocabulary. The panel window owns the spring recipe (see
// PanelController); these are the SwiftUI-side durations every component
// shares: a quick ease for color and fill changes, the pill pop curve for
// scale, and a hover ease. All collapse under Reduce Motion.

/// Step-change cross-fade shared by multi-step surfaces (onboarding).
enum BeruMotion {
    static let stepCrossfade: TimeInterval = 0.22
    /// Tab highlight travel. Matches Animate UI TabsContents:
    /// spring stiffness 300, damping 32, bounce 0.
    static let tabSwitch: TimeInterval = 0.32
    /// Critically damped so the pill glides with no overshoot. Do not use a
    /// bouncy spring — that is the traveling-pill regression.
    static var tabSwitchAnimation: Animation {
        .spring(response: tabSwitch, dampingFraction: 1.0)
    }
    /// One streamed word. Matches the print cadence of the typewriter.
    static let typewriterWord: TimeInterval = 0.055
    /// Caret blink. Off the typical 8pt rhythm on purpose — a cursor beat.
    static let typewriterCaret: TimeInterval = 0.53
}

/// Hover reported by an outer AppKit hit target (`PanelHitCapsule`) when the
/// visible control itself has `allowsHitTesting(false)` and cannot see the
/// pointer. Inner chrome reads this so hover fill still paints.
private struct BeruParentHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var beruParentHovered: Bool {
        get { self[BeruParentHoveredKey.self] }
        set { self[BeruParentHoveredKey.self] = newValue }
    }
}

private struct BeruEase: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Bool
    let animation: Animation

    init(value: Bool, duration: TimeInterval, inOut: Bool = false) {
        self.value = value
        self.animation = inOut
            ? .easeInOut(duration: duration)
            : .easeOut(duration: duration)
    }

    init(value: Bool, animation: Animation) {
        self.value = value
        self.animation = animation
    }

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Eases hover-driven fill changes so they glide instead of snap.
    func beruHoverEase(_ isHovered: Bool) -> some View {
        modifier(BeruEase(value: isHovered, duration: 0.12))
    }

    /// Chip selection + highlight travel. Scoped to the chip so the panel
    /// window does not animate its height on a tab change.
    func beruTabSwitchEase(_ isSelected: Bool) -> some View {
        modifier(BeruEase(value: isSelected, animation: BeruMotion.tabSwitchAnimation))
    }

    /// Eases focus rings and glows.
    func beruFocusEase(_ isFocused: Bool) -> some View {
        modifier(BeruEase(value: isFocused, duration: 0.15))
    }
}
