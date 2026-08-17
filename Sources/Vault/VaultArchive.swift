import Foundation

enum VaultArchiveError: LocalizedError {
    case dittoFailed(String)
    case unreadableArchive

    var errorDescription: String? {
        switch self {
        case .dittoFailed(let message): return message
        case .unreadableArchive: return "Couldn’t read that zip as a Beru vault."
        }
    }
}

/// Zip import/export via macOS `ditto` — no third-party archive dependency.
enum VaultArchive {
    struct ImportSummary: Equatable {
        var notes: Int
        var pins: Int
    }

    static func export(root: URL, to destination: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try runDitto(arguments: [
            "-c", "-k", "--sequesterRsrc", "--keepParent",
            root.path,
            destination.path
        ])
    }

    static func importZip(from archive: URL, into root: URL) throws -> ImportSummary {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory
            .appendingPathComponent("beru-vault-import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        try runDitto(arguments: ["-x", "-k", archive.path, staging.path])

        guard let sourceRoot = findVaultRoot(in: staging) else {
            throw VaultArchiveError.unreadableArchive
        }

        let notesDir = root.appendingPathComponent("notes", isDirectory: true)
        try fm.createDirectory(at: notesDir, withIntermediateDirectories: true)

        var notesImported = 0
        let sourceNotes = sourceRoot.appendingPathComponent("notes", isDirectory: true)
        if let files = try? fm.contentsOfDirectory(at: sourceNotes, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension.lowercased() == "md" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let fallback = file.deletingPathExtension().lastPathComponent
                var note = VaultNoteCodec.decode(from: text, fallbackID: fallback)
                // The id from imported frontmatter is the filename this gets
                // written under, so it is attacker-influenceable: a crafted
                // archive could name a note "../../../tmp/evil" and the write
                // would escape the vault's notes directory (zip-slip). Reject
                // anything that walks up or carries a path separator here,
                // before it ever reaches a filesystem call.
                note.id = Self.sanitizeNoteID(note.id)
                // Avoid overwriting an existing id when merging.
                if fm.fileExists(atPath: notesDir.appendingPathComponent("\(note.id).md").path) {
                    note.id = "note-\(UUID().uuidString)"
                }
                note.updatedAt = .now
                let encoded = VaultNoteCodec.encode(note)
                try encoded.write(
                    to: notesDir.appendingPathComponent("\(note.id).md"),
                    atomically: true,
                    encoding: .utf8
                )
                notesImported += 1
            }
        }

        var pinsImported = 0
        let sourcePins = sourceRoot.appendingPathComponent("pins.json")
        if let data = try? Data(contentsOf: sourcePins) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let incoming = try? decoder.decode([VaultPin].self, from: data) {
                let pinsURL = root.appendingPathComponent("pins.json")
                var existing: [VaultPin] = []
                if let existingData = try? Data(contentsOf: pinsURL) {
                    existing = (try? decoder.decode([VaultPin].self, from: existingData)) ?? []
                }
                var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
                for var pin in incoming {
                    if byID[pin.id] != nil {
                        pin.id = "pin-\(UUID().uuidString)"
                    }
                    byID[pin.id] = pin
                    pinsImported += 1
                }
                let merged = Array(byID.values).sorted { $0.createdAt > $1.createdAt }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(merged).write(to: pinsURL, options: .atomic)
            }
        }

        let marker = root.appendingPathComponent(".beru-vault")
        if !fm.fileExists(atPath: marker.path) {
            try "beru-vault-v1\n".write(to: marker, atomically: true, encoding: .utf8)
        }

        return ImportSummary(notes: notesImported, pins: pinsImported)
    }

    /// An id read from imported frontmatter becomes a filename, so it must not
    /// be able to escape the notes directory. Rejects anything containing a
    /// path separator or a parent-directory reference, and anything that could
    /// hide as a dotfile; an invalid id falls back to a fresh UUID.
    static func sanitizeNoteID(_ id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\:")
        let invalid = trimmed.isEmpty
            || trimmed.hasPrefix(".")
            || trimmed.contains("..")
            || trimmed.rangeOfCharacter(from: forbidden) != nil
        return invalid ? "note-\(UUID().uuidString)" : trimmed
    }

    /// Accepts either the extracted vault folder itself or a parent that contains it.
    private static func findVaultRoot(in staging: URL) -> URL? {
        let fm = FileManager.default
        let directNotes = staging.appendingPathComponent("notes", isDirectory: true)
        if fm.fileExists(atPath: directNotes.path) { return staging }

        guard let children = try? fm.contentsOfDirectory(
            at: staging,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return nil }

        for child in children {
            let notes = child.appendingPathComponent("notes", isDirectory: true)
            if fm.fileExists(atPath: notes.path) { return child }
        }
        return nil
    }

    private static func runDitto(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments
        let err = Pipe()
        process.standardError = err
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = err.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw VaultArchiveError.dittoFailed(message?.isEmpty == false ? message! : "ditto failed")
        }
    }
}
