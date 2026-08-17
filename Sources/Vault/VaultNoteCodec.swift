import Foundation

/// Encodes / decodes a vault note as markdown with a small YAML frontmatter block.
enum VaultNoteCodec {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterFallback: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func encode(_ note: VaultNote) -> String {
        let title = escapeYAML(note.title)
        let created = isoFormatter.string(from: note.createdAt)
        let updated = isoFormatter.string(from: note.updatedAt)
        // Body is concatenated so the template cannot inject a trailing newline
        // the user never typed.
        return """
        ---
        id: \(note.id)
        title: "\(title)"
        created: \(created)
        updated: \(updated)
        ---

        """ + note.body
    }

    static func decode(from text: String, fallbackID: String) -> VaultNote {
        guard text.hasPrefix("---\n") || text.hasPrefix("---\r\n") else {
            return VaultNote(id: fallbackID, title: titleGuess(from: text), body: text)
        }

        let remainder = text.dropFirst(4)
        guard let endRange = remainder.range(of: "\n---") else {
            return VaultNote(id: fallbackID, title: titleGuess(from: text), body: text)
        }

        let header = String(remainder[..<endRange.lowerBound])
        var body = String(remainder[endRange.upperBound...])
        // Closing fence ends at `---`; skip the newline that terminates that
        // line, then the blank separator line our encoder writes.
        body = dropLeadingLineBreak(body)
        body = dropLeadingLineBreak(body)

        let fields = parseFields(header)
        let id = fields["id"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackID
        let title = unquote(fields["title"] ?? "")
        let created = parseDate(fields["created"]) ?? .now
        let updated = parseDate(fields["updated"]) ?? created
        return VaultNote(
            id: id,
            title: title.isEmpty ? titleGuess(from: body) : title,
            body: body,
            createdAt: created,
            updatedAt: updated
        )
    }

    private static func dropLeadingLineBreak(_ text: String) -> String {
        if text.hasPrefix("\r\n") { return String(text.dropFirst(2)) }
        if text.hasPrefix("\n") { return String(text.dropFirst()) }
        return text
    }

    // MARK: - Helpers

    private static func parseFields(_ header: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in header.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            fields[key] = value
        }
        return fields
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return isoFormatter.date(from: raw) ?? isoFormatterFallback.date(from: raw)
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else {
            return value
        }
        let inner = String(value.dropFirst().dropLast())
        return inner
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func escapeYAML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func titleGuess(from body: String) -> String {
        var line = "Untitled"
        for candidate in body.split(whereSeparator: \.isNewline) {
            let trimmed = candidate.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                line = trimmed
                break
            }
        }
        let stripped = line.hasPrefix("#")
            ? line.drop(while: { $0 == "#" || $0 == " " })
            : Substring(line)
        let title = String(stripped.prefix(80))
        return title.isEmpty ? "Untitled" : title
    }
}
