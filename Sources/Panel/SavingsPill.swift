import SwiftUI

/// Per-run token accounting, shown on the outcome strip once a result lands.
///
/// Deliberately quiet. It sits to the left of Replace as a side note, not as a
/// badge competing with the result text — this is a number you glance at, and
/// the panel is on screen for a couple of seconds at a time.
///
/// Legibility is not left to chance. The panel floats over arbitrary content, so
/// the frosted backdrop behind this pill can be anything from white paper to
/// black. Both the pill's surface and its text therefore derive from the app's
/// own appearance, never from the backdrop: an earlier version filled the capsule
/// at 12% opacity and coloured `±0` with `.secondary`, which rendered dark grey
/// on dark grey over a black backdrop and was effectively invisible.
struct SavingsPill: View {
    let savings: TokenSavings

    @Environment(\.colorScheme) private var colorScheme

    /// An opaque-enough surface that whatever is behind the glass cannot bleed
    /// through far enough to swallow 11pt text.
    private var surface: Color {
        BrandColors.canvas.opacity(0.9)
    }

    /// Hand-picked per appearance rather than using `.green` / `.orange`, whose
    /// system values are bright enough that 11pt text over a light surface falls
    /// well short of a readable contrast ratio.
    private var accent: Color {
        switch (savings.direction, colorScheme) {
        case (.leaner, .dark): return Color(red: 0.44, green: 0.86, blue: 0.54)
        case (.leaner, _): return Color(red: 0.07, green: 0.42, blue: 0.18)
        case (.longer, .dark): return Color(red: 1.00, green: 0.74, blue: 0.38)
        case (.longer, _): return Color(red: 0.56, green: 0.32, blue: 0.02)
        case (.unchanged, _): return .primary
        }
    }

    private var icon: String {
        switch savings.direction {
        case .leaner: return "arrow-down-right"
        case .longer: return "arrow-up-right"
        case .unchanged: return "equal"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            BeruIcon(name: icon, size: 9, strokeWidth: 2.5)
            Text(savings.shortLabel)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                // The label is a single string like "−38 tok". Without this the
                // footer's HStack can squeeze the Text below its natural width,
                // wrapping "+7" and "tok" onto separate lines.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            meter
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(surface)
                .overlay(Capsule().fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.10)))
        )
        // Never let the footer's other controls compress this pill below its
        // intrinsic width; it always keeps room for the number and "tok".
        .layoutPriority(1)
        .help(savings.detail)
        .accessibilityElement()
        .accessibilityLabel(savings.detail)
    }

    /// How much of the original the result still takes up. Overflows to a full
    /// bar when the result grew, which reads correctly: the track is the input,
    /// and the fill has run out of room.
    private var meter: some View {
        Capsule()
            .fill(accent.opacity(0.25))
            .frame(width: 20, height: 3)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(accent)
                    .frame(width: max(2, 20 * savings.outputShare), height: 3)
            }
    }
}
