import CryptoKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.rahul.beru", category: "history")

/// Appends usage events to daily JSON Lines files. An actor so the file handle
/// is owned by exactly one isolation domain, and so writes never touch the
/// main thread.
actor UsageLogWriter {
    struct Stats: Sendable {
        var entryCount: Int
        var totalBytes: Int
        var oldestDate: Date?
        var isDisabledForSession: Bool
        var lastErrorDescription: String?
    }

    static let shared = UsageLogWriter(directory: UsageLogWriter.defaultDirectory)

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Beru/history", isDirectory: true)
    }

    private let directory: URL
    private var handle: FileHandle?
    private var openDay: String?
    private var consecutiveFailures = 0
    private var isDisabledForSession = false
    private var lastErrorDescription: String?

    /// Stops writing after this many consecutive failures, so a full disk
    /// doesn't produce an error per keystroke for the rest of the session.
    private static let failureLimit = 5

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    init(directory: URL) {
        self.directory = directory
    }

    /// First 8 bytes of SHA-256 as hex. Enough to correlate a terminal event
    /// with the generation that produced its text, without storing the text
    /// a second time.
    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func append(_ event: UsageEvent) {
        guard !isDisabledForSession else { return }
        do {
            let data = try encoder.encode(event)
            // A newline inside any string field would split one event across
            // two lines and corrupt the file; JSON escaping guarantees it
            // cannot, and this assertion documents the dependency.
            precondition(!data.contains(0x0A), "Encoded event must not contain a raw newline")
            var line = data
            line.append(0x0A)

            let handle = try handleForToday()
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            consecutiveFailures = 0
        } catch {
            consecutiveFailures += 1
            lastErrorDescription = error.localizedDescription
            if consecutiveFailures >= Self.failureLimit {
                isDisabledForSession = true
                logger.error("usage history disabled after repeated write failures")
            }
        }
    }

    private func dayStamp(_ date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func handleForToday() throws -> FileHandle {
        let today = dayStamp()
        if let handle, openDay == today { return handle }

        try? handle?.close()
        handle = nil

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let url = directory.appendingPathComponent("usage-\(today).jsonl")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(
                atPath: url.path,
                contents: nil,
                attributes: [.posixPermissions: 0o600]
            )
        }
        let opened = try FileHandle(forWritingTo: url)
        handle = opened
        openDay = today
        return opened
    }

    private func logFiles() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        )) ?? []
        return contents.filter { $0.pathExtension == "jsonl" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func stats() -> Stats {
        var bytes = 0
        var lines = 0
        var oldest: Date?
        for url in logFiles() {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            bytes += values?.fileSize ?? 0
            if let modified = values?.contentModificationDate {
                oldest = min(oldest ?? modified, modified)
            }
            if let data = try? Data(contentsOf: url) {
                lines += data.reduce(0) { $1 == 0x0A ? $0 + 1 : $0 }
            }
        }
        return Stats(
            entryCount: lines,
            totalBytes: bytes,
            oldestDate: oldest,
            isDisabledForSession: isDisabledForSession,
            lastErrorDescription: lastErrorDescription
        )
    }

    /// Deletes whole day-files that fall outside the retention window or push
    /// the directory past its size cap, oldest first.
    func enforceRetention(retentionDays: Int, maxBytes: Int) {
        let files = logFiles()
        guard !files.isEmpty else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())
        var survivors: [(URL, Int)] = []
        for url in files {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = values?.fileSize ?? 0
            if let cutoff, let modified = values?.contentModificationDate, modified < cutoff {
                remove(url)
                continue
            }
            survivors.append((url, size))
        }

        var total = survivors.reduce(0) { $0 + $1.1 }
        var index = 0
        while total > maxBytes, index < survivors.count - 1 {
            remove(survivors[index].0)
            total -= survivors[index].1
            index += 1
        }
    }

    private func remove(_ url: URL) {
        if url.lastPathComponent == "usage-\(dayStamp()).jsonl" {
            try? handle?.close()
            handle = nil
            openDay = nil
        }
        try? FileManager.default.removeItem(at: url)
    }

    func clearAll() {
        try? handle?.close()
        handle = nil
        openDay = nil
        for url in logFiles() {
            try? FileManager.default.removeItem(at: url)
        }
        isDisabledForSession = false
        consecutiveFailures = 0
        lastErrorDescription = nil
    }

    /// Concatenates every day-file for export.
    func exportAll() -> Data {
        var output = Data()
        for url in logFiles() {
            if let data = try? Data(contentsOf: url) { output.append(data) }
        }
        return output
    }

    nonisolated var directoryURL: URL { directory }
}
