import XCTest
@testable import Beru

/// The reader turns an event log into the sessions a person recognises, so the
/// tests are written in those terms: one press of the hotkey is one row,
/// whatever the model did in between.
final class UsageLogReaderTests: XCTestCase {
    private func event(
        _ kind: UsageEventKind,
        invocation: UUID,
        seq: Int,
        ts: String = "2026-08-03T07:19:44.729Z",
        actionID: String? = nil,
        actionName: String? = nil,
        inputText: String? = nil,
        outputText: String? = nil,
        rationale: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        savedTokens: Int? = nil,
        errorMessage: String? = nil,
        hostAppName: String? = nil,
        model: String? = nil
    ) -> UsageEvent {
        var e = UsageEvent(invocationID: invocation, kind: kind)
        e.seq = seq
        e.ts = ts
        e.actionID = actionID
        e.actionName = actionName
        e.inputText = inputText
        e.outputText = outputText
        e.rationale = rationale
        e.inputTokens = inputTokens
        e.outputTokens = outputTokens
        e.savedTokens = savedTokens
        e.errorMessage = errorMessage
        e.hostAppName = hostAppName
        e.model = model
        return e
    }

    // MARK: - Grouping

    /// The whole point of the reader. A regenerate-then-replace session writes
    /// seven events; listing it as seven rows would show the same piece of work
    /// three times over.
    func testOneSessionBecomesOneRunHoweverManyEvents() {
        let id = UUID()
        let events = [
            event(.invoked, invocation: id, seq: 1, inputText: "fix this pls", hostAppName: "Cursor"),
            event(.generationStarted, invocation: id, seq: 2, actionID: "enhance", model: "qwen3:8b"),
            event(.generationFinished, invocation: id, seq: 3, outputText: "First attempt."),
            event(.generationStarted, invocation: id, seq: 4, actionID: "enhance"),
            event(.generationFinished, invocation: id, seq: 5, outputText: "Second attempt."),
            event(.replaced, invocation: id, seq: 6, actionID: "enhance")
        ]

        let runs = UsageLogReader.group(events)
        XCTAssertEqual(runs.count, 1)
        let run = try? XCTUnwrap(runs.first)
        XCTAssertEqual(run?.inputText, "fix this pls")
        XCTAssertEqual(run?.hostAppName, "Cursor")
        XCTAssertEqual(run?.model, "qwen3:8b")
        // The text the user kept is the last one produced, not the first.
        XCTAssertEqual(run?.outputText, "Second attempt.")
        XCTAssertEqual(run?.generationCount, 2)
        XCTAssertEqual(run?.outcome, .replaced)
    }

    /// Full text appears once per stage by design — input on `invoked`, output
    /// on `generationFinished` — so a reader that looks at only one event finds
    /// half a run.
    func testFieldsAreCollectedFromTheStageThatCarriesThem() {
        let id = UUID()
        let runs = UsageLogReader.group([
            event(.invoked, invocation: id, seq: 1, inputText: "the original"),
            event(.generationStarted, invocation: id, seq: 2, actionID: "enhance", model: "qwen3:8b"),
            event(.generationFinished, invocation: id, seq: 3,
                  outputText: "the result", rationale: "Cut the hedging."),
            event(.copied, invocation: id, seq: 4)
        ])
        XCTAssertEqual(runs.first?.inputText, "the original")
        XCTAssertEqual(runs.first?.outputText, "the result")
        XCTAssertEqual(runs.first?.rationale, "Cut the hedging.")
        XCTAssertEqual(runs.first?.model, "qwen3:8b")
    }

    func testRunsAreNewestFirst() {
        let (a, b, c) = (UUID(), UUID(), UUID())
        let runs = UsageLogReader.group([
            event(.invoked, invocation: a, seq: 1, ts: "2026-08-01T10:00:00.000Z"),
            event(.invoked, invocation: b, seq: 2, ts: "2026-08-03T10:00:00.000Z"),
            event(.invoked, invocation: c, seq: 3, ts: "2026-08-02T10:00:00.000Z")
        ])
        XCTAssertEqual(runs.map(\.id), [b, c, a])
    }

    /// `seq` exists because two events can share a millisecond. Ordering by
    /// timestamp alone would occasionally pick the wrong "last" result.
    func testOrderWithinASessionUsesSeqNotTimestamp() {
        let id = UUID()
        let stamp = "2026-08-03T07:19:44.729Z"
        let runs = UsageLogReader.group([
            event(.generationFinished, invocation: id, seq: 9, ts: stamp, outputText: "last"),
            event(.invoked, invocation: id, seq: 1, ts: stamp, inputText: "in"),
            event(.generationFinished, invocation: id, seq: 5, ts: stamp, outputText: "first")
        ])
        XCTAssertEqual(runs.first?.outputText, "last")
    }

    // MARK: - Outcomes

    func testTerminalEventDecidesTheOutcome() {
        let cases: [(UsageEventKind, UsageRun.Outcome)] = [
            (.replaced, .replaced),
            (.copied, .copied),
            (.dismissed, .dismissed),
            (.generationCancelled, .cancelled),
            (.emptySelection, .emptySelection)
        ]
        for (kind, expected) in cases {
            let id = UUID()
            let runs = UsageLogReader.group([
                event(.invoked, invocation: id, seq: 1),
                event(kind, invocation: id, seq: 2)
            ])
            XCTAssertEqual(runs.first?.outcome, expected, "for \(kind)")
        }
    }

    func testFailureCarriesItsMessage() {
        let id = UUID()
        let runs = UsageLogReader.group([
            event(.invoked, invocation: id, seq: 1),
            event(.generationFailed, invocation: id, seq: 2, errorMessage: "Invalid API key")
        ])
        XCTAssertEqual(runs.first?.outcome, .failed("Invalid API key"))
    }

    /// There is no click-outside dismissal, so a session with no terminal event
    /// means the panel was abandoned. Reporting that as "dismissed" would
    /// invent a decision the user never made.
    func testSessionWithNoTerminalEventIsAbandonedNotDismissed() {
        let id = UUID()
        let runs = UsageLogReader.group([
            event(.invoked, invocation: id, seq: 1, inputText: "left open"),
            event(.generationStarted, invocation: id, seq: 2),
            event(.generationFinished, invocation: id, seq: 3, outputText: "never taken")
        ])
        XCTAssertEqual(runs.first?.outcome, .abandoned)
        XCTAssertNotEqual(runs.first?.outcome, .dismissed)
        XCTAssertFalse(runs.first?.outcome.wasAccepted ?? true)
    }

    /// Only Replace and Copy credit the savings total, and the list's
    /// "accepted only" filter has to agree with that rule.
    func testOnlyReplaceAndCopyCountAsAccepted() {
        XCTAssertTrue(UsageRun.Outcome.replaced.wasAccepted)
        XCTAssertTrue(UsageRun.Outcome.copied.wasAccepted)
        for outcome: UsageRun.Outcome in [.dismissed, .cancelled, .abandoned, .emptySelection, .failed(nil)] {
            XCTAssertFalse(outcome.wasAccepted, "\(outcome) must not count as accepted")
        }
    }

    /// Tokens are recorded on the accepted event for the result the user took.
    /// When a later generation also finished, its numbers are not the ones that
    /// were credited.
    func testTokensComeFromTheAcceptedResultWhenThereIsOne() {
        let id = UUID()
        let runs = UsageLogReader.group([
            event(.invoked, invocation: id, seq: 1),
            event(.generationFinished, invocation: id, seq: 2,
                  inputTokens: 100, outputTokens: 90, savedTokens: 10),
            event(.replaced, invocation: id, seq: 3,
                  inputTokens: 100, outputTokens: 60, savedTokens: 40)
        ])
        XCTAssertEqual(runs.first?.savedTokens, 40)
        XCTAssertEqual(runs.first?.outputTokens, 60)
    }

    /// A result that grew is stored and shown as a negative saving rather than
    /// clamped, so the reader must not coerce it.
    func testGrowthSurvivesAsANegativeSaving() {
        let id = UUID()
        let runs = UsageLogReader.group([
            event(.invoked, invocation: id, seq: 1),
            event(.replaced, invocation: id, seq: 2, savedTokens: -34)
        ])
        XCTAssertEqual(runs.first?.savedTokens, -34)
    }

    // MARK: - Decoding

    /// The writer appends to a live file, so a read can land mid-append. One
    /// half-written line must not cost the rest of the day.
    func testAPartialTrailingLineDoesNotDiscardTheFile() {
        let id = UUID()
        let good = try! JSONEncoder().encode(event(.invoked, invocation: id, seq: 1, inputText: "kept"))
        var data = good
        data.append(UInt8(ascii: "\n"))
        data.append(contentsOf: Data(#"{"invocationID":"F4C5EA6F-0359-451"#.utf8))

        let events = UsageLogReader.decodeEvents(from: data)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.inputText, "kept")
    }

    func testGarbageLinesAreSkippedIndividually() {
        let id = UUID()
        let encoder = JSONEncoder()
        var data = Data()
        data.append(contentsOf: Data("not json at all\n".utf8))
        data.append(try! encoder.encode(event(.invoked, invocation: id, seq: 1, inputText: "first")))
        data.append(UInt8(ascii: "\n"))
        data.append(contentsOf: Data("{}\n".utf8))
        data.append(try! encoder.encode(event(.copied, invocation: id, seq: 2)))
        data.append(UInt8(ascii: "\n"))

        let events = UsageLogReader.decodeEvents(from: data)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(UsageLogReader.group(events).first?.outcome, .copied)
    }

    /// Every field added since v1 is optional precisely so an older reader
    /// survives a newer line. That guarantee is worth a test, because it is
    /// only true while nothing required is added.
    func testALineFromANewerSchemaStillParses() {
        let future = """
        {"schema":9,"id":"1B4E28BA-2FA1-11D2-883F-0016D3CCA427",\
        "invocationID":"F4C5EA6F-0359-451D-8C3B-DCB67D5B3F4F","seq":3,\
        "ts":"2026-08-03T07:19:44.729Z","kind":"invoked","inputText":"hello",\
        "somethingInvented":{"nested":true},"anotherNewField":42}
        """
        let events = UsageLogReader.decodeEvents(from: Data(future.utf8))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.inputText, "hello")
    }

    /// An unknown `kind` is the one thing that cannot be ignored, since the
    /// enum drives outcome. Losing the line is correct; losing the file is not.
    func testAnUnknownEventKindLosesOnlyThatLine() {
        let id = UUID()
        var data = try! JSONEncoder().encode(event(.invoked, invocation: id, seq: 1, inputText: "kept"))
        data.append(UInt8(ascii: "\n"))
        data.append(contentsOf: Data("""
        {"id":"1B4E28BA-2FA1-11D2-883F-0016D3CCA427",\
        "invocationID":"\(id.uuidString)","seq":2,"ts":"2026-08-03T07:19:44.729Z",\
        "kind":"teleported"}
        """.utf8))

        let events = UsageLogReader.decodeEvents(from: data)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.inputText, "kept")
    }

    func testTimestampsParseWithAndWithoutFractionalSeconds() {
        XCTAssertNotNil(UsageLogReader.parseTimestamp("2026-08-03T07:19:44.729Z"))
        XCTAssertNotNil(UsageLogReader.parseTimestamp("2026-08-03T07:19:44Z"))
        XCTAssertNil(UsageLogReader.parseTimestamp("last Tuesday"))
    }

    /// An unparseable timestamp sorts to the bottom rather than crashing or
    /// jumping to the top of the list.
    func testAnUnreadableTimestampSortsOldest() {
        let (good, bad) = (UUID(), UUID())
        let runs = UsageLogReader.group([
            event(.invoked, invocation: bad, seq: 1, ts: "nonsense"),
            event(.invoked, invocation: good, seq: 2, ts: "2026-08-03T07:19:44.729Z")
        ])
        XCTAssertEqual(runs.map(\.id), [good, bad])
    }

    /// Leading blank lines and indentation are dropped: a list row showing an
    /// empty first line, or one indented off the edge, reads as a broken entry.
    func testSummaryLineIsTheFirstMeaningfulLine() {
        let id = UUID()
        let runs = UsageLogReader.group([
            event(.invoked, invocation: id, seq: 1, inputText: "\n\n  first line\nsecond line")
        ])
        XCTAssertEqual(runs.first?.summaryLine, "first line")
    }
}
