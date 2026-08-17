import XCTest
@testable import Beru

final class UsageLogTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("beru-history-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    private func lines(in directory: URL) throws -> [String] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.flatMap { url -> [String] in
            try String(contentsOf: url, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
        }
    }

    func testEventWithEmbeddedNewlinesStaysOnOneLine() async throws {
        let writer = UsageLogWriter(directory: tempDirectory)
        var event = UsageEvent(invocationID: UUID(), kind: .invoked)
        event.inputText = "line one\nline two\r\nline three"
        event.seq = 1
        await writer.append(event)

        let written = try lines(in: tempDirectory)
        XCTAssertEqual(written.count, 1, "Embedded newlines must not split the record")
        let decoded = try JSONDecoder().decode(UsageEvent.self, from: Data(written[0].utf8))
        XCTAssertEqual(decoded.inputText, "line one\nline two\r\nline three")
    }

    func testAppendsPreserveOrder() async throws {
        let writer = UsageLogWriter(directory: tempDirectory)
        let invocation = UUID()
        for index in 1...3 {
            var event = UsageEvent(invocationID: invocation, kind: .generationStarted)
            event.seq = index
            await writer.append(event)
        }
        let decoded = try lines(in: tempDirectory).map {
            try JSONDecoder().decode(UsageEvent.self, from: Data($0.utf8))
        }
        XCTAssertEqual(decoded.map(\.seq), [1, 2, 3])
        XCTAssertEqual(Set(decoded.map(\.invocationID)), [invocation])
    }

    func testStatsAndClear() async throws {
        let writer = UsageLogWriter(directory: tempDirectory)
        for index in 1...4 {
            var event = UsageEvent(invocationID: UUID(), kind: .copied)
            event.seq = index
            await writer.append(event)
        }
        var stats = await writer.stats()
        XCTAssertEqual(stats.entryCount, 4)
        XCTAssertGreaterThan(stats.totalBytes, 0)

        await writer.clearAll()
        stats = await writer.stats()
        XCTAssertEqual(stats.entryCount, 0)
    }

    func testRetentionDeletesFilesOlderThanWindow() async throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let stale = tempDirectory.appendingPathComponent("usage-2020-01-01.jsonl")
        try Data("{}\n".utf8).write(to: stale)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_577_836_800)],
            ofItemAtPath: stale.path
        )

        let writer = UsageLogWriter(directory: tempDirectory)
        var fresh = UsageEvent(invocationID: UUID(), kind: .invoked)
        fresh.seq = 1
        await writer.append(fresh)

        await writer.enforceRetention(retentionDays: 90, maxBytes: 200_000_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        let remaining = try lines(in: tempDirectory)
        XCTAssertEqual(remaining.count, 1)
    }

    func testDigestIsStableAndShort() {
        let a = UsageLogWriter.digest("hello world")
        XCTAssertEqual(a, UsageLogWriter.digest("hello world"))
        XCTAssertNotEqual(a, UsageLogWriter.digest("hello worlds"))
        XCTAssertEqual(a.count, 16)
    }

    func testRecordedEventNeverCarriesSecrets() async throws {
        // The schema has no field for credentials; this locks that in against
        // a future field being added carelessly.
        let writer = UsageLogWriter(directory: tempDirectory)
        var event = UsageEvent(invocationID: UUID(), kind: .generationStarted)
        event.systemPrompt = Prompts.grammar
        event.model = "qwen3:8b"
        event.providerKind = "ollama"
        event.seq = 1
        await writer.append(event)

        let blob = try lines(in: tempDirectory).joined()
        for secret in ["sk-ant-", "x-api-key", "Bearer ", "Authorization"] {
            XCTAssertFalse(blob.contains(secret), "History must never contain \(secret)")
        }
    }
}
