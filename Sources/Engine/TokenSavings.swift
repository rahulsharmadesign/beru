import Foundation

/// What one run cost and what it returned, in estimated tokens.
///
/// The point of the number: a refined prompt is usually shorter than what you
/// typed, so every future paste of it into an AI costs fewer tokens. Savings
/// can be negative — Enhance sometimes has to add structure — and the UI says
/// so rather than clamping to zero and implying a win that didn't happen.
struct TokenSavings: Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int

    init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    init(input: String, output: String) {
        self.init(
            inputTokens: TokenEstimate.tokens(in: input),
            outputTokens: TokenEstimate.tokens(in: output)
        )
    }

    /// Positive when the result is leaner than the input.
    var savedTokens: Int { inputTokens - outputTokens }

    /// Signed fraction of the input that was saved, e.g. 0.31 for 31% leaner.
    var ratio: Double {
        guard inputTokens > 0 else { return 0 }
        return Double(savedTokens) / Double(inputTokens)
    }

    /// How much of the input the result still occupies, clamped to 0...1 for
    /// use as a meter fill.
    var outputShare: Double {
        guard inputTokens > 0 else { return 1 }
        return min(1, max(0, Double(outputTokens) / Double(inputTokens)))
    }

    enum Direction { case leaner, longer, unchanged }

    var direction: Direction {
        if savedTokens > 0 { return .leaner }
        if savedTokens < 0 { return .longer }
        return .unchanged
    }

    /// Percent magnitude, unsigned — the direction is carried by the sign glyph
    /// and the colour, so repeating it here would read as a double negative.
    var percent: Int { Int((abs(ratio) * 100).rounded()) }

    /// Footer-pill text. U+2212 minus, not a hyphen, so it aligns with digits.
    var shortLabel: String {
        switch direction {
        case .leaner: return "\u{2212}\(savedTokens) tok"
        case .longer: return "+\(-savedTokens) tok"
        case .unchanged: return "±0 tok"
        }
    }

    /// Tooltip and accessibility text. Spells out that it's an estimate.
    var detail: String {
        let counts = "≈\(inputTokens) tokens in, \(outputTokens) out"
        switch direction {
        case .leaner:
            return "\(counts) — about \(savedTokens) fewer (\(percent)% leaner) "
                + "every time you send this to an AI. Estimated."
        case .longer:
            return "\(counts) — about \(-savedTokens) more (\(percent)% longer) "
                + "than what you selected. Estimated."
        case .unchanged:
            return "\(counts) — same estimated length. Estimated."
        }
    }
}
