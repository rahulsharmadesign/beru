import Foundation

/// Grammar returns three bodies in one call. The result field shows the
/// selected one; Corrected is the default copy-edit.
enum GrammarKind: String, CaseIterable, Identifiable, Equatable, Sendable {
    case corrected
    case clearer
    case tighter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .corrected: return "Corrected"
        case .clearer: return "Clearer"
        case .tighter: return "Tighter"
        }
    }

    static var promptCatalog: String {
        """
        - corrected: copy-edit only. Preserve meaning, tone, voice, and sentence order. Fix every error. A misspelled or ungrammatical word MUST be replaced with the correct word in the same place — never left as-is, and never deleted without putting the correction there. Do not restyle, paraphrase, or swap a correct word for a synonym. Helper words grammar requires (a, the, 's, not, doesn't) may be added or removed. Do not add new sentences, drop existing ones, or change their order. Return the document verbatim only when it already has no spelling, grammar, or punctuation errors.
        - clearer: optional light rephrase of the corrected document only — not a second copy-edit. Same meaning, easier to read. If the corrected document is already clear, repeat it verbatim.
        - tighter: optional shorter rephrase of the corrected document only — not a second copy-edit. Same meaning, fewer words. If the corrected document is already tight, repeat it verbatim.
        """
    }

    static var promptTagSkeleton: String {
        allCases.map { "<grammar kind=\"\($0.rawValue)\">...</grammar>" }.joined(separator: "\n")
    }
}

struct GrammarSuggestion: Equatable, Identifiable, Sendable {
    var kind: GrammarKind
    var body: String
    var id: GrammarKind { kind }
}

enum GrammarSuggestions {
    static func parse(_ raw: String) -> [GrammarSuggestion] {
        let pattern = #"<grammar\s+kind="([^"]+)">([\s\S]*?)</grammar>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return fallback(raw)
        }
        let ns = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        var byKind: [GrammarKind: String] = [:]
        for match in matches {
            guard match.numberOfRanges == 3,
                  let kindRange = Range(match.range(at: 1), in: raw),
                  let bodyRange = Range(match.range(at: 2), in: raw),
                  let kind = GrammarKind(rawValue: String(raw[kindRange]).lowercased())
            else { continue }
            guard byKind[kind] == nil else { continue }
            let body = cleaned(String(raw[bodyRange]))
            guard !body.isEmpty else { continue }
            byKind[kind] = body
        }
        let ordered = GrammarKind.allCases.compactMap { kind -> GrammarSuggestion? in
            guard let body = byKind[kind] else { return nil }
            return GrammarSuggestion(kind: kind, body: body)
        }
        return ordered.isEmpty ? fallback(raw) : ordered
    }

    static func body(in suggestions: [GrammarSuggestion], matching kind: GrammarKind) -> String? {
        suggestions.first(where: { $0.kind == kind })?.body ?? suggestions.first?.body
    }

    private static func fallback(_ raw: String) -> [GrammarSuggestion] {
        let body = cleaned(raw)
        guard !body.isEmpty else { return [] }
        return [GrammarSuggestion(kind: .corrected, body: body)]
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
