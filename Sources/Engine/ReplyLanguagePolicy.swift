import Foundation
import NaturalLanguage

/// Script the incoming message was written in. Smart Reply must match this,
/// not just the semantic language — Roman Hinglish must not become Devanagari.
enum ReplyScript: Equatable, Sendable {
    case latin
    case devanagari
    case arabic
    case cjk
    case other

    var label: String {
        switch self {
        case .latin: return "Roman/Latin script"
        case .devanagari: return "Devanagari script"
        case .arabic: return "Arabic script"
        case .cjk: return "CJK script"
        case .other: return "the same script as the message"
        }
    }
}

struct ReplyLanguagePolicy: Equatable, Sendable {
    var script: ReplyScript
    /// BCP-47 language the recognizer saw, when confident enough to matter.
    var dominantLanguageCode: String?
    /// Latin script with a non-English dominant language — Hinglish, Tanglish, etc.
    var isCodeMixed: Bool

    static func analyze(_ text: String) -> ReplyLanguagePolicy {
        var counts: [ReplyScript: Int] = [:]
        var letterCount = 0
        for scalar in text.unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { continue }
            letterCount += 1
            let bucket = classify(scalar)
            counts[bucket, default: 0] += 1
        }

        let script: ReplyScript
        if letterCount == 0 {
            script = .latin
        } else if let top = counts.max(by: { $0.value < $1.value }), top.value * 2 >= letterCount {
            script = top.key
        } else {
            script = .other
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let dominant = recognizer.dominantLanguage
        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
        let code = dominant?.rawValue
        let isCodeMixed = Self.isCodeMixedLatin(
            script: script,
            dominant: dominant,
            hypotheses: hypotheses
        )

        return ReplyLanguagePolicy(
            script: script,
            dominantLanguageCode: code,
            isCodeMixed: isCodeMixed
        )
    }

    /// Appended to the Smart Reply system prompt so the model matches script and
    /// register, not just the semantic language.
    var promptBlock: String {
        var lines = [
            "LANGUAGE AND SCRIPT",
            "The incoming message uses \(script.label)."
        ]
        if isCodeMixed, let code = dominantLanguageCode {
            lines.append(
                "It is code-mixed (\(Self.displayName(for: code)) in Roman/Latin script). "
                    + "Write all six replies in the same Roman/Latin register as the message — Hinglish stays Hinglish."
            )
        } else if script == .latin, dominantLanguageCode == "de" {
            lines.append("Write all six replies in German using Roman/Latin script, matching the message.")
        } else if script == .latin {
            lines.append(
                "Write all six replies in the same language as the message, using Roman/Latin script."
            )
        } else {
            lines.append("Write all six replies in \(script.label), matching the message's language and register.")
        }
        lines.append(
            "Every reply must use the SAME language and script as the incoming message and as each other. "
                + "Do not mix languages across the six replies. "
                + "Do not translate into German, English-only, Devanagari, or any language the message did not use."
        )
        return lines.joined(separator: "\n")
    }

    /// True when a single reply body uses the wrong language or script.
    func bodyViolatesPolicy(_ body: String) -> Bool {
        if outputViolatesScript(body) { return true }
        guard let dominant = Self.dominantLanguage(for: body),
              dominant != .undetermined
        else { return false }
        let label = dominant.rawValue

        // Roman code-mixed input: the recognizer's label for the INPUT itself
        // is noise (Roman Hinglish reads as "de" or "id"), so there is no
        // trusted expected language to match against. Tolerate English, the
        // Indic family, and the languages such text is routinely confused
        // with; flag confident drift into anything else.
        if isCodeMixed {
            return !Self.codeMixedAllowedCodes.contains(label)
        }

        // An Indic language in its own script keeps its whole family plus
        // English; anything else is drift.
        if Self.indicLanguageCodes.contains(dominantLanguageCode ?? "") {
            return !(label == dominantLanguageCode || label == "en"
                || Self.indicLanguageCodes.contains(label))
        }

        // Plain input: the label is trustworthy, so the reply must match the
        // input's language, whatever it was — Portuguese back on an English
        // message is as wrong as German. An English reply to a non-English
        // message stays unflagged: English is the model's usual fallback.
        guard let expected = dominantLanguageCode.flatMap({ NLLanguage(rawValue: $0) }),
              expected != .undetermined,
              label != expected.rawValue
        else { return false }
        return dominant != .english
    }

    /// Languages a Roman-script code-mixed message may come back as without
    /// counting as drift: English, the Indic family, and the languages
    /// romanized Indic text reliably misclassifies as.
    private static let codeMixedAllowedCodes: Set<String> = {
        var codes = indicLanguageCodes
        codes.insert("en")
        codes.formUnion(["id", "ms", "tl", "tr", "ro", "nl", "sw", "da", "nb", "sv"])
        return codes
    }()

    /// True when the six replies disagree with each other or with the input.
    static func repliesViolatePolicy(
        _ suggestions: [ReplySuggestion],
        input policy: ReplyLanguagePolicy
    ) -> Bool {
        guard !suggestions.isEmpty else { return false }
        if suggestions.contains(where: { policy.bodyViolatesPolicy($0.body) }) { return true }
        let codes = suggestions.compactMap { dominantLanguageCode($0.body) }
        let meaningful = Set(codes.filter { $0 != "und" })
        return meaningful.count > 1
    }

    static func dominantLanguage(for text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage
    }

    static func dominantLanguageCode(_ text: String) -> String? {
        dominantLanguage(for: text)?.rawValue
    }

    /// Legacy name used by script-only checks.
    func outputViolatesScript(_ output: String) -> Bool {
        switch script {
        case .latin:
            return Self.containsDevanagari(output) || Self.containsArabic(output)
        case .devanagari:
            return Self.latinLetterRatio(in: output) > 0.6
        case .arabic:
            return Self.latinLetterRatio(in: output) > 0.6
        case .cjk, .other:
            return false
        }
    }

    private static func isCodeMixedLatin(
        script: ReplyScript,
        dominant: NLLanguage?,
        hypotheses: [NLLanguage: Double]
    ) -> Bool {
        guard script == .latin else { return false }
        if let dominant, dominant != .english, dominant != .undetermined { return true }
        let englishScore = hypotheses[.english] ?? 0
        let indicScore = hypotheses.filter { indicLanguageCodes.contains($0.key.rawValue) }
            .values.max() ?? 0
        // Hinglish often scores as English because of Latin "post/share" tokens.
        return indicScore > 0.05 && englishScore < 0.98
    }

    private static let indicLanguageCodes: Set<String> = [
        "hi", "mr", "bn", "ta", "te", "ur", "gu", "kn", "ml", "pa"
    ]

    private static func classify(_ scalar: Unicode.Scalar) -> ReplyScript {
        let value = scalar.value
        if (0x0900...0x097F).contains(value) || (0xA8E0...0xA8FF).contains(value) {
            return .devanagari
        }
        if (0x0600...0x06FF).contains(value) || (0x0750...0x077F).contains(value)
            || (0x08A0...0x08FF).contains(value) {
            return .arabic
        }
        if (0x4E00...0x9FFF).contains(value) || (0x3040...0x30FF).contains(value)
            || (0xAC00...0xD7AF).contains(value) {
            return .cjk
        }
        if CharacterSet.letters.contains(scalar) { return .latin }
        return .other
    }

    static func containsDevanagari(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
    }

    static func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value)
        }
    }

    private static func latinLetterRatio(in text: String) -> Double {
        var latin = 0
        var letters = 0
        for scalar in text.unicodeScalars {
            guard CharacterSet.letters.contains(scalar) else { continue }
            letters += 1
            if classify(scalar) == .latin { latin += 1 }
        }
        guard letters > 0 else { return 0 }
        return Double(latin) / Double(letters)
    }

    private static func displayName(for code: String) -> String {
        switch code {
        case "hi": return "Hindi"
        case "ur": return "Urdu"
        case "ta": return "Tamil"
        case "te": return "Telugu"
        case "mr": return "Marathi"
        case "bn": return "Bengali"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "pt": return "Portuguese"
        default: return code
        }
    }
}
