import Foundation
import os.log

private let logger = Logger(subsystem: "com.rahul.beru", category: "history-reader")

/// Reads the JSON Lines history back into sessions.
///
/// The counterpart to `UsageLogWriter`, and deliberately a separate actor: the
/// writer owns an open file handle for appends and must never block, while this
/// walks whole files and can take its time. Sharing one actor would let a
/// dashboard scroll stall a panel's logging.
///
/// Reads newest day-file first and stops once it has enough sessions, so
/// opening the dashboard costs one file rather than the whole directory — which
/// the retention settings allow to reach 200 MB.
actor UsageLogReader {
    static let shared = UsageLogReader(directory: UsageLogWriter.defaultDirectory)

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    private let decoder = JSONDecoder()

    /// `Date.ISO8601FormatStyle` rather than `ISO8601DateFormatter`: the
    /// formatter is a reference type and not `Sendable`, so holding one in a
    /// static is shared mutable state across isolation domains — a warning today
    /// and an error under Swift 6. The format style is a value type.
    private static let fractionalStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plainStyle = Date.ISO8601FormatStyle()

    /// Fractional seconds are always written, but a hand-edited or externally
    /// generated line need not have them, and losing a whole run over its
    /// timestamp would lose real history.
    static func parseTimestamp(_ text: String) -> Date? {
        if let date = try? Date(text, strategy: fractionalStyle) { return date }
        return try? Date(text, strategy: plainStyle)
    }

    /// Day-files, newest first. The name carries the date, so this needs no
    /// filesystem attributes and stays correct if files are copied around.
    private func dayFiles() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return contents
            .filter { $0.lastPathComponent.hasPrefix("usage-") && $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// Newest `limit` sessions.
    ///
    /// `limit` counts sessions, not lines, so it keeps reading files until it
    /// has that many. A day-file is always consumed whole: a session cannot
    /// span files except across midnight, and truncating one mid-way would drop
    /// the terminal event and mislabel the run as abandoned.
    func recentRuns(limit: Int = 200) -> [UsageRun] {
        var events: [UsageEvent] = []
        var runs: [UsageRun] = []

        for file in dayFiles() {
            events.append(contentsOf: decodeEvents(in: file))
            runs = Self.group(events)
            if runs.count >= limit { break }
        }
        return Array(runs.prefix(limit))
    }

    /// Every session, oldest file included. Used by search, which cannot stop
    /// early without risking a false "no results".
    func allRuns() -> [UsageRun] {
        let events = dayFiles().flatMap { decodeEvents(in: $0) }
        return Self.group(events)
    }

    private func decodeEvents(in file: URL) -> [UsageEvent] {
        guard let data = try? Data(contentsOf: file) else {
            logger.notice("could not read a history file")
            return []
        }
        return Self.decodeEvents(from: data, decoder: decoder)
    }

    /// Parses a JSON Lines blob, skipping anything unreadable.
    ///
    /// A partial trailing line is expected rather than exceptional: the writer
    /// appends to a live file, so a read that lands mid-append sees half a line.
    /// One bad line must never cost the rest of the day's history.
    static func decodeEvents(from data: Data, decoder: JSONDecoder = JSONDecoder()) -> [UsageEvent] {
        var events: [UsageEvent] = []
        var skipped = 0
        for line in data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true) {
            guard let event = try? decoder.decode(UsageEvent.self, from: Data(line)) else {
                skipped += 1
                continue
            }
            events.append(event)
        }
        if skipped > 0 {
            logger.notice("skipped \(skipped) unreadable history lines")
        }
        return events
    }

    /// Folds events into sessions, newest first.
    ///
    /// Pure and static so it can be tested against fabricated event streams
    /// without touching the filesystem.
    static func group(_ events: [UsageEvent]) -> [UsageRun] {
        var byInvocation: [UUID: [UsageEvent]] = [:]
        for event in events {
            byInvocation[event.invocationID, default: []].append(event)
        }

        let runs = byInvocation.values.compactMap { session -> UsageRun? in
            // `seq` is a process-wide monotonic counter, so it orders events
            // correctly even when two share a timestamp. It restarts each
            // launch, but a session never spans launches.
            build(from: session.sorted { $0.seq < $1.seq })
        }
        return runs.sorted { $0.startedAt > $1.startedAt }
    }

    private static func build(from session: [UsageEvent]) -> UsageRun? {
        guard let first = session.first else { return nil }

        let invoked = session.first { $0.kind == .invoked }
        let finishes = session.filter { $0.kind == .generationFinished }
        let starts = session.filter { $0.kind == .generationStarted }
        let terminal = session.last { isTerminal($0.kind) }

        // Prefer the accepted result: when the user replaced or copied, that is
        // the generation that mattered, even if a later one also finished.
        let accepted = session.last { $0.kind == .replaced || $0.kind == .copied }
        let result = finishes.last

        let outcome: UsageRun.Outcome
        switch terminal?.kind {
        case .replaced: outcome = .replaced
        case .copied: outcome = .copied
        case .dismissed: outcome = .dismissed
        case .generationCancelled: outcome = .cancelled
        case .generationFailed: outcome = .failed(terminal?.errorMessage)
        case .emptySelection: outcome = .emptySelection
        default: outcome = .abandoned
        }

        // The full text appears once per stage by design, so each field is
        // taken from the event that carries it rather than from any one event.
        let text = invoked?.inputText ?? ""
        let source = accepted ?? result

        // Take the last event that actually carried each field, not the last
        // event outright. Not every generation records every one — a second
        // pass can omit the model — and reading `starts.last?.model` blanks a
        // value an earlier event had.
        return UsageRun(
            id: first.invocationID,
            startedAt: parseTimestamp(first.ts) ?? .distantPast,
            hostAppName: invoked?.hostAppName ?? session.compactMap(\.hostAppName).last,
            hostBundleID: invoked?.hostBundleID ?? session.compactMap(\.hostBundleID).last,
            targetID: invoked?.targetID ?? session.compactMap(\.targetID).last,
            actionID: source?.actionID ?? starts.compactMap(\.actionID).last,
            actionName: source?.actionName ?? starts.compactMap(\.actionName).last,
            model: starts.compactMap(\.model).last,
            providerKind: starts.compactMap(\.providerKind).last,
            inputText: text,
            outputText: result?.outputText,
            rationale: finishes.compactMap(\.rationale).last,
            instruction: session.compactMap(\.instruction).last,
            inputTokens: source?.inputTokens ?? result?.inputTokens,
            outputTokens: source?.outputTokens ?? result?.outputTokens,
            savedTokens: source?.savedTokens ?? result?.savedTokens,
            outcome: outcome,
            generationCount: starts.count,
            totalMs: result?.totalMs,
            truncated: invoked?.truncated ?? false
        )
    }

    private static func isTerminal(_ kind: UsageEventKind) -> Bool {
        switch kind {
        case .replaced, .copied, .dismissed, .generationCancelled, .generationFailed, .emptySelection:
            return true
        case .invoked, .generationStarted, .generationFinished:
            return false
        }
    }
}
