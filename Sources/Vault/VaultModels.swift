import Foundation

/// A markdown note in the local vault.
struct VaultNote: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = "note-\(UUID().uuidString)",
        title: String = "Untitled",
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// First non-empty line of the body, for list subtitles.
    var preview: String {
        for line in body.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Empty"
    }
}

/// A pinned link or saved panel result, stored alongside notes.
struct VaultPin: Identifiable, Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case link
        case run
    }

    var id: String
    var kind: Kind
    var title: String
    /// Absolute URL for link pins.
    var url: String?
    /// Saved result / snippet text for run pins.
    var body: String?
    var sourceNoteID: String?
    var actionID: String?
    var createdAt: Date

    init(
        id: String = "pin-\(UUID().uuidString)",
        kind: Kind,
        title: String,
        url: String? = nil,
        body: String? = nil,
        sourceNoteID: String? = nil,
        actionID: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.url = url
        self.body = body
        self.sourceNoteID = sourceNoteID
        self.actionID = actionID
        self.createdAt = createdAt
    }
}
