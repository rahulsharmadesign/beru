import Foundation

/// Character-based token estimation.
///
/// There is no tokenizer on device, and the streaming endpoints this app uses
/// don't return usage counts, so every number derived from here is an estimate
/// and is labelled as one wherever it is shown.
enum TokenEstimate {
    /// Average characters per token for Latin-script prose under a BPE
    /// tokenizer. Measured across GPT/Claude-family tokenizers, which cluster
    /// between 3.5 and 4.0 for ordinary English.
    private static let charactersPerToken = 3.7

    /// Tokenizers never merge across whitespace, so each whitespace-separated
    /// chunk costs at least one token — that floor is what keeps short-word
    /// text (lists, code, chat) from being under-counted by a flat chars/4.
    /// CJK runs the other way at roughly one token per character, so those
    /// scalars are counted separately instead of being folded into the ratio.
    static func tokens(in text: String) -> Int {
        var total = 0
        for chunk in text.split(whereSeparator: \.isWhitespace) {
            var wide = 0
            var narrow = 0
            for character in chunk {
                if character.isWideScript { wide += 1 } else { narrow += 1 }
            }
            let narrowTokens = narrow == 0
                ? 0
                : max(1, Int((Double(narrow) / charactersPerToken).rounded()))
            total += narrowTokens + wide
        }
        return total
    }
}

private extension Character {
    /// Scripts that tokenize at roughly one token per character.
    var isWideScript: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x3040...0x30FF,   // Hiragana, Katakana
             0x3400...0x4DBF,   // CJK unified extension A
             0x4E00...0x9FFF,   // CJK unified
             0xAC00...0xD7AF,   // Hangul syllables
             0xF900...0xFAFF:   // CJK compatibility
            return true
        default:
            return false
        }
    }
}
