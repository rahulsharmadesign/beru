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

/// Pin links are opened with `NSWorkspace`, so only http(s) is allowed.
enum VaultLink {
    static func normalizedURL(from raw: String) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") {
            value = "https://\(value)"
        }
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

/// Notes write; Pins is the scrapboard. Same Vault page, two modes.
enum VaultPane: String, CaseIterable, Identifiable {
    case notes
    case pins

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: return "Notes"
        case .pins: return "Pins"
        }
    }
}

/// Last selected vault note, pin, and pane, so leaving the page does not dump you.
enum VaultSelectionMemory {
    static let key = "vaultSelectedNoteID"
    static let pinKey = "vaultSelectedPinID"
    static let paneKey = "vaultSelectedPane"

    static func persist(_ id: String?, defaults: UserDefaults = .standard) {
        persistValue(id, key: key, defaults: defaults)
    }

    static func restoredID(from notes: [VaultNote], defaults: UserDefaults = .standard) -> String? {
        restoredValue(key: key, among: notes.map(\.id), defaults: defaults)
    }

    static func persistPin(_ id: String?, defaults: UserDefaults = .standard) {
        persistValue(id, key: pinKey, defaults: defaults)
    }

    static func restoredPinID(from pins: [VaultPin], defaults: UserDefaults = .standard) -> String? {
        restoredValue(key: pinKey, among: pins.map(\.id), defaults: defaults)
    }

    static func persistPane(_ pane: VaultPane, defaults: UserDefaults = .standard) {
        defaults.set(pane.rawValue, forKey: paneKey)
    }

    static func restoredPane(defaults: UserDefaults = .standard) -> VaultPane {
        VaultPane(rawValue: defaults.string(forKey: paneKey) ?? "") ?? .notes
    }

    private static func persistValue(_ id: String?, key: String, defaults: UserDefaults) {
        if let id {
            defaults.set(id, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func restoredValue(key: String, among ids: [String], defaults: UserDefaults) -> String? {
        guard let id = defaults.string(forKey: key), ids.contains(id) else { return nil }
        return id
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
