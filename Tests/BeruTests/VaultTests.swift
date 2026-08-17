import XCTest
@testable import Beru

final class VaultTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("beru-vault-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testNoteCodecRoundTrip() {
        let original = VaultNote(
            id: "note-abc",
            title: #"Quotes "and" slashes \ ok"#,
            body: "# Hello\n\nBody line",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let encoded = VaultNoteCodec.encode(original)
        let decoded = VaultNoteCodec.decode(from: encoded, fallbackID: "fallback")
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.body, original.body)
        XCTAssertEqual(
            decoded.createdAt.timeIntervalSince1970,
            original.createdAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testCodecFallsBackWithoutFrontmatter() {
        let note = VaultNoteCodec.decode(from: "# Draft\n\ncontent", fallbackID: "note-file")
        XCTAssertEqual(note.id, "note-file")
        XCTAssertEqual(note.title, "Draft")
        XCTAssertTrue(note.body.contains("content"))
    }

    @MainActor
    func testStoreCreateUpdateDelete() async throws {
        let suite = "beru.vault.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = VaultStore(defaults: defaults, rootURL: tempRoot)
        let note = store.createNote(title: "One", body: "Alpha")
        XCTAssertEqual(store.notes.count, 1)

        var edited = note
        edited.body = "Beta"
        store.updateNote(edited)
        // Debounced persist — wait for the write.
        try await Task.sleep(for: .milliseconds(400))
        store.reload()
        XCTAssertEqual(store.note(id: note.id)?.body, "Beta")

        store.deleteNote(id: note.id)
        store.reload()
        XCTAssertTrue(store.notes.isEmpty)
    }

    @MainActor
    func testNoteFilesAreOwnerReadableOnly() throws {
        let suite = "beru.vault.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = VaultStore(defaults: defaults, rootURL: tempRoot)
        let note = store.createNote(title: "Secret", body: "classified")
        let url = store.notesDirectoryURL.appendingPathComponent("\(note.id).md")
        let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual((mode?.uint16Value ?? 0) & 0o777, 0o600)
    }

    @MainActor
    func testPinResultAndLink() {
        let suite = "beru.vault.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = VaultStore(defaults: defaults, rootURL: tempRoot)
        store.pinResult(title: "Saved", body: "hello world", actionID: "enhance")
        store.addLinkPin(title: "Docs", url: "https://example.com")
        XCTAssertEqual(store.pins.count, 2)
        store.reload()
        XCTAssertEqual(store.pins.count, 2)
        XCTAssertEqual(store.pins.filter { $0.kind == .link }.count, 1)
    }

    @MainActor
    func testApplyResultWritesNote() {
        let suite = "beru.vault.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = VaultStore(defaults: defaults, rootURL: tempRoot)
        let note = store.createNote(title: "Untitled", body: "draft")
        store.applyResult("# Shipped\n\nImproved", toNoteID: note.id)
        XCTAssertEqual(store.note(id: note.id)?.body, "# Shipped\n\nImproved")
        XCTAssertEqual(store.note(id: note.id)?.title, "Shipped")
    }

    /// Security: an id read from imported frontmatter becomes a filename, so it
    /// must never be able to escape the notes directory. A crafted archive could
    /// otherwise write an arbitrary file anywhere the user can write (zip-slip).
    func testSanitizeNoteIDRejectsPathTraversal() {
        // Normal ids pass through untouched.
        XCTAssertEqual(VaultArchive.sanitizeNoteID("note-abc"), "note-abc")
        XCTAssertEqual(VaultArchive.sanitizeNoteID("note-abc_def"), "note-abc_def")

        // Parent-dir walks are neutralised: the traversal string never survives,
        // and is replaced with a safe id rather than kept.
        XCTAssertNotEqual(
            VaultArchive.sanitizeNoteID("../../../tmp/evil"),
            "../../../tmp/evil"
        )
        XCTAssertNotEqual(VaultArchive.sanitizeNoteID(".."), "../..")

        // Path separators and dotfiles are rejected.
        XCTAssertFalse(VaultArchive.sanitizeNoteID("a/b").contains("/"))
        XCTAssertFalse(VaultArchive.sanitizeNoteID("a\\b").contains("\\"))
        XCTAssertFalse(VaultArchive.sanitizeNoteID(".hidden").hasPrefix("."))

        // A rejected id is replaced with a fresh UUID-shaped note id, which is
        // a safe filename.
        let safe = VaultArchive.sanitizeNoteID("../../../etc/passwd")
        XCTAssertTrue(safe.hasPrefix("note-"))
        XCTAssertFalse(safe.contains("."))
    }

    /// Import must never write a note outside the vault's notes directory, even
    /// when the archive's frontmatter names a traversing filename.
    @MainActor
    func testImportNeutralisesTraversalNoteID() throws {
        let source = tempRoot.appendingPathComponent("malicious", isDirectory: true)
        let destRoot = tempRoot.appendingPathComponent("dest-safe", isDirectory: true)
        let notes = source.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destRoot.appendingPathComponent("notes"), withIntermediateDirectories: true)

        // A note whose frontmatter claims a traversing id, so a naive import
        // would write it outside the vault root.
        let malicious = """
        ---
        id: ../../../beru-pwned
        title: "bad"
        created: \(ISO8601DateFormatter().string(from: Date()))
        updated: \(ISO8601DateFormatter().string(from: Date()))
        ---

        pwned
        """
        try malicious.write(
            to: notes.appendingPathComponent("import.md"),
            atomically: true,
            encoding: .utf8
        )

        let zipURL = tempRoot.appendingPathComponent("malicious.zip")
        try VaultArchive.export(root: source, to: zipURL)
        _ = try VaultArchive.importZip(from: zipURL, into: destRoot)

        // The traversal target must not exist.
        let escapeTarget = tempRoot.appendingPathComponent("beru-pwned.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: escapeTarget.path))

        // The note landed safely inside the vault's notes directory.
        let notesDir = destRoot.appendingPathComponent("notes")
        let files = try FileManager.default.contentsOfDirectory(atPath: notesDir.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertFalse(files[0].contains(".."))
    }

    func testArchiveExportImport() throws {
        let source = tempRoot.appendingPathComponent("source", isDirectory: true)
        let destRoot = tempRoot.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: source.appendingPathComponent("notes"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destRoot.appendingPathComponent("notes"), withIntermediateDirectories: true)

        let note = VaultNote(id: "note-export", title: "Export me", body: "body")
        try VaultNoteCodec.encode(note).write(
            to: source.appendingPathComponent("notes/note-export.md"),
            atomically: true,
            encoding: .utf8
        )
        let pin = VaultPin(kind: .link, title: "Site", url: "https://example.com")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([pin]).write(to: source.appendingPathComponent("pins.json"))

        let zipURL = tempRoot.appendingPathComponent("vault.zip")
        try VaultArchive.export(root: source, to: zipURL)
        let summary = try VaultArchive.importZip(from: zipURL, into: destRoot)
        XCTAssertEqual(summary.notes, 1)
        XCTAssertEqual(summary.pins, 1)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destRoot.appendingPathComponent("notes/note-export.md").path
            )
        )
    }
}
