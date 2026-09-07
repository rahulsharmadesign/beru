import SwiftUI

// Shared motion vocabulary. The panel window owns the spring recipe (see
// PanelController); these are the SwiftUI-side durations every component
// shares: a quick ease for color and fill changes, the pill pop curve for
// scale, and a hover ease. All collapse under Reduce Motion.

/// Step-change cross-fade shared by multi-step surfaces (onboarding).
enum BeruMotion {
    static let stepCrossfade: TimeInterval = 0.22
}

private struct BeruEase: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Bool
    var duration: TimeInterval

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeOut(duration: duration), value: value)
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

    /// Eases focus rings and glows.
    func beruFocusEase(_ isFocused: Bool) -> some View {
        modifier(BeruEase(value: isFocused, duration: 0.15))
    }
}
