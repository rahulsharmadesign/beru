import Foundation

/// Fixed tones for Smart Reply. One model call emits all six; the panel
/// picks among them. Raw values match the `tone="…"` attribute in the prompt.
enum ReplyTone: String, CaseIterable, Identifiable, Equatable, Sendable {
    case formal
    case casual
    case funny
    case professional
    case witty
    case sharp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .formal: return "Formal"
        case .casual: return "Casual"
        case .funny: return "Funny"
        case .professional: return "Professional"
        case .witty: return "Witty"
        case .sharp: return "Sharp"
        }
    }

    var job: String {
        switch self {
        case .formal: return "Polite, complete sentences. No humour"
        case .casual: return "Conversational, warm. No jokes"
        case .funny: return "Playful and genuinely amusing, still sendable. Humour comes from the content — a callback or understatement — never a bolted-on joke"
        case .professional: return "Work-ready, no fluff, no humour"
        case .witty: return "One dry observation about the actual point, then the answer"
        case .sharp: return "Direct, pointed. No humour"
        }
    }

    /// Catalog the model is told to emit. Kept here so the prompt and parser
    /// cannot drift on tone names.
    static var promptCatalog: String {
        allCases.map { "- \($0.rawValue): \($0.job)." }.joined(separator: "\n")
    }

    static var promptTagSkeleton: String {
        allCases.map { "<reply tone=\"\($0.rawValue)\">...</reply>" }.joined(separator: "\n")
    }
}

struct ReplySuggestion: Equatable, Identifiable, Sendable {
    var tone: ReplyTone
    var body: String
    var id: ReplyTone { tone }
}

enum ReplySuggestions {
    /// Extracts tagged replies. Missing tones are dropped. Duplicate tones keep
    /// the first body. If no tags parse, the trimmed raw text becomes a single
    /// Formal fallback so Insert/Copy still have something to send.
    static func parse(_ raw: String) -> [ReplySuggestion] {
        let pattern = #"<reply\s+tone="([^"]+)">([\s\S]*?)</reply>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return fallback(raw)
        }
        let ns = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        var byTone: [ReplyTone: String] = [:]
        for match in matches {
            guard match.numberOfRanges == 3,
                  let toneRange = Range(match.range(at: 1), in: raw),
                  let bodyRange = Range(match.range(at: 2), in: raw),
                  let tone = ReplyTone(rawValue: String(raw[toneRange]).lowercased())
            else { continue }
            guard byTone[tone] == nil else { continue }
            let body = cleaned(String(raw[bodyRange]))
            guard !body.isEmpty else { continue }
            byTone[tone] = body
        }
        let ordered = ReplyTone.allCases.compactMap { tone -> ReplySuggestion? in
            guard let body = byTone[tone] else { return nil }
            return ReplySuggestion(tone: tone, body: body)
        }
        return ordered.isEmpty ? fallback(raw) : ordered
    }

    static func body(in suggestions: [ReplySuggestion], matching tone: ReplyTone) -> String? {
        suggestions.first(where: { $0.tone == tone })?.body ?? suggestions.first?.body
    }

    private static func fallback(_ raw: String) -> [ReplySuggestion] {
        let body = cleaned(raw)
        guard !body.isEmpty else { return [] }
        return [ReplySuggestion(tone: .formal, body: body)]
    }

    private static func cleaned(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if lines.first?.hasPrefix("```") == true { lines.removeFirst() }
            if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
                lines.removeLast()
            }
            text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.count >= 2 {
            let first = text.first
            let last = text.last
            if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }
}
