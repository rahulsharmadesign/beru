import AppKit
import Foundation
import Observation
import os.log
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "com.rahul.beru", category: "vault")

/// Local-first vault: markdown notes + pins on disk under a user-chosen folder.
///
/// Default lives in Application Support. Pointing the root at an iCloud Drive
/// or Dropbox folder is how "cloud" works — Beru never hosts the files.
@MainActor
@Observable
final class VaultStore {
    static let shared = VaultStore()

    private static let rootPathKey = "vaultRootPath"
    private static let pinsFileName = "pins.json"
    private static let notesDirectoryName = "notes"
    private static let markerFileName = ".beru-vault"

    private let defaults: UserDefaults
    private var saveTasks: [String: Task<Void, Never>] = [:]

    private(set) var rootURL: URL
    private(set) var notes: [VaultNote] = []
    private(set) var pins: [VaultPin] = []
    private(set) var statusMessage: String?

    func flashStatus(_ message: String) {
        statusMessage = message
    }

    /// Application Support default: `~/Library/Application Support/Beru/vault`.
    static var defaultRootURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("Beru/vault", isDirectory: true)
    }

    init(defaults: UserDefaults = .standard, rootURL: URL? = nil) {
        self.defaults = defaults
        if let rootURL {
            self.rootURL = rootURL
        } else if let stored = defaults.string(forKey: Self.rootPathKey), !stored.isEmpty {
            self.rootURL = URL(fileURLWithPath: stored, isDirectory: true)
        } else {
            self.rootURL = Self.defaultRootURL
        }
        ensureLayout()
        reload()
    }

    var notesDirectoryURL: URL {
        rootURL.appendingPathComponent(Self.notesDirectoryName, isDirectory: true)
    }

    var pinsFileURL: URL {
        rootURL.appendingPathComponent(Self.pinsFileName)
    }

    var isUsingDefaultRoot: Bool {
        rootURL.standardizedFileURL == Self.defaultRootURL.standardizedFileURL
    }

    func note(id: String) -> VaultNote? {
        notes.first { $0.id == id }
    }

    // MARK: - Path

    func setRoot(_ url: URL) {
        let standardized = url.standardizedFileURL
        guard standardized != rootURL.standardizedFileURL else { return }
        rootURL = standardized
        defaults.set(standardized.path, forKey: Self.rootPathKey)
        ensureLayout()
        reload()
        statusMessage = "Vault folder updated"
    }

    func resetToDefaultRoot() {
        defaults.removeObject(forKey: Self.rootPathKey)
        rootURL = Self.defaultRootURL
        ensureLayout()
        reload()
        statusMessage = "Using local Application Support vault"
    }

    func chooseRootFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.message = "Notes and pins are stored here. Pick an iCloud Drive or Dropbox folder to sync."
        panel.directoryURL = rootURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setRoot(url)
    }

    // MARK: - Reload

    func reload() {
        ensureLayout()
        notes = loadNotes().sorted { $0.updatedAt > $1.updatedAt }
        pins = loadPins().sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Notes

    @discardableResult
    func createNote(title: String = "Untitled", body: String = "") -> VaultNote {
        let note = VaultNote(title: title, body: body)
        notes.insert(note, at: 0)
        persistNoteImmediately(note)
        return note
    }

    func updateNote(_ note: VaultNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
        updated.updatedAt = .now
        notes[index] = updated
        notes.sort { $0.updatedAt > $1.updatedAt }
        schedulePersist(updated)
    }

    func deleteNote(id: String) {
        saveTasks[id]?.cancel()
        saveTasks[id] = nil
        notes.removeAll { $0.id == id }
        let url = noteFileURL(id: id)
        try? FileManager.default.removeItem(at: url)
    }

    func applyResult(_ text: String, toNoteID id: String) {
        guard var note = note(id: id) else { return }
        note.body = text
        if note.title == "Untitled" {
            let guess = VaultNote(title: "", body: text).preview
            if guess != "Empty" {
                let cleaned = guess.hasPrefix("#")
                    ? guess.drop(while: { $0 == "#" || $0 == " " })
                    : Substring(guess)
                let title = String(cleaned.prefix(80))
                if !title.isEmpty { note.title = title }
            }
        }
        updateNote(note)
        persistNoteImmediately(note)
        statusMessage = "Note updated"
    }

    // MARK: - Pins

    @discardableResult
    func addLinkPin(title: String, url: String) -> VaultPin {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let pin = VaultPin(
            kind: .link,
            title: trimmedTitle.isEmpty ? trimmedURL : trimmedTitle,
            url: trimmedURL
        )
        pins.insert(pin, at: 0)
        persistPins()
        return pin
    }

    @discardableResult
    func pinResult(
        title: String,
        body: String,
        actionID: String? = nil,
        noteID: String? = nil
    ) -> VaultPin {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = String(trimmed.prefix(72))
            .replacingOccurrences(of: "\n", with: " ")
        let pin = VaultPin(
            kind: .run,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (fallbackTitle.isEmpty ? "Pinned result" : fallbackTitle)
                : title,
            body: body,
            sourceNoteID: noteID,
            actionID: actionID
        )
        pins.insert(pin, at: 0)
        persistPins()
        statusMessage = "Pinned"
        return pin
    }

    func deletePin(id: String) {
        pins.removeAll { $0.id == id }
        persistPins()
    }

    // MARK: - Archive

    func exportZip() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "Beru-Vault-\(Self.dayStamp()).zip"
        panel.canCreateDirectories = true
        panel.title = "Export Vault"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try VaultArchive.export(root: rootURL, to: url)
            statusMessage = "Exported vault"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
            logger.error("vault export failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func importZip() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Import merges notes and pins into the current vault folder."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let summary = try VaultArchive.importZip(from: url, into: rootURL)
            reload()
            statusMessage = "Imported \(summary.notes) notes, \(summary.pins) pins"
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
            logger.error("vault import failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Persistence

    private func ensureLayout() {
        let fm = FileManager.default
        let privateAttrs: [FileAttributeKey: Any]? = isUsingDefaultRoot
            ? [.posixPermissions: 0o700]
            : nil
        try? fm.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: privateAttrs)
        try? fm.createDirectory(at: notesDirectoryURL, withIntermediateDirectories: true, attributes: privateAttrs)
        if isUsingDefaultRoot {
            try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)
            try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: notesDirectoryURL.path)
        }
        let marker = rootURL.appendingPathComponent(Self.markerFileName)
        if !fm.fileExists(atPath: marker.path) {
            try? "beru-vault-v1\n".write(to: marker, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: pinsFileURL.path) {
            try? "[]".write(to: pinsFileURL, atomically: true, encoding: .utf8)
            applyFilePermissions(pinsFileURL)
        }
    }

    private func applyFilePermissions(_ url: URL) {
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func noteFileURL(id: String) -> URL {
        notesDirectoryURL.appendingPathComponent("\(id).md")
    }

    private func loadNotes() -> [VaultNote] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: notesDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return files.compactMap { url -> VaultNote? in
            guard url.pathExtension.lowercased() == "md" else { return nil }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let fallback = url.deletingPathExtension().lastPathComponent
            return VaultNoteCodec.decode(from: text, fallbackID: fallback)
        }
    }

    private func loadPins() -> [VaultPin] {
        guard let data = try? Data(contentsOf: pinsFileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([VaultPin].self, from: data)) ?? []
    }

    private func schedulePersist(_ note: VaultNote) {
        saveTasks[note.id]?.cancel()
        let snapshot = note
        saveTasks[note.id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.persistNoteImmediately(snapshot)
            }
        }
    }

    private func persistNoteImmediately(_ note: VaultNote) {
        // Prefer the in-memory copy if the user kept typing past the debounce.
        let latest = notes.first(where: { $0.id == note.id }) ?? note
        let url = noteFileURL(id: latest.id)
        let text = VaultNoteCodec.encode(latest)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            applyFilePermissions(url)
        } catch {
            logger.error("failed to write note \(latest.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            statusMessage = "Couldn’t save note"
        }
    }

    private func persistPins() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(pins)
            try data.write(to: pinsFileURL, options: .atomic)
            applyFilePermissions(pinsFileURL)
        } catch {
            logger.error("failed to write pins: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Couldn’t save pins"
        }
    }

    private static func dayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
