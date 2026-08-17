import XCTest
@testable import Beru

/// Grammar may only replace a word with a corrected spelling of it. These tests
/// separate a correction from a reword, and are calibrated on the real reported
/// case — a paraphrase that came back *longer* than the input, which the previous
/// length-based check missed entirely.
final class ParaphraseDetectionTests: XCTestCase {
    private func score(_ original: String, _ revised: String) -> Double {
        WordDiff.paraphraseScore(WordDiff.diff(original: original, revised: revised))
    }

    private func flagged(_ original: String, _ revised: String) -> Bool {
        score(original, revised) > PanelEngine.grammarParaphraseCeiling
    }

    // MARK: - Real corrections are not flagged

    func testMisspellingFixesAreNotFlagged() {
        XCTAssertFalse(flagged(
            "their are three thing we need to discus before the meting tommorow, i will send you the agenda later",
            "There are three things we need to discuss before the meeting tomorrow; I will send you the agenda later."
        ))
    }

    func testClassicCopyEditIsNotFlagged() {
        XCTAssertFalse(flagged(
            "we recieved you're order, it will ship monday",
            "We received your order; it will ship Monday."
        ))
    }

    func testSingleTypoIsNotFlagged() {
        XCTAssertFalse(flagged("helo wrold", "hello world"))
    }

    func testCaseOnlyFixIsNotFlagged() {
        XCTAssertFalse(flagged("i went home", "I went home"))
    }

    func testPunctuationOnlyFixIsNotFlagged() {
        XCTAssertFalse(flagged("Ship it monday, please", "Ship it Monday; please"))
    }

    func testUnchangedTextScoresZero() {
        XCTAssertEqual(score("nothing to fix here", "nothing to fix here"), 0)
    }

    // MARK: - Rewording is flagged

    func testTheReportedParaphraseIsFlagged() {
        // Every substitution here is a synonym swap, and the result is LONGER
        // than the input — the case the old length check could not see.
        let original = "One housekeeping note: your clipboard is empty. My backup of it captured nothing at that moment, so there was nothing to put back."
        let revised = "One housekeeping reminder: your clipboard contains no data. My attempt to back it up found nothing at that time, meaning there was nothing to restore."
        XCTAssertTrue(flagged(original, revised))
        XCTAssertGreaterThan(score(original, revised), 0.8)
    }

    func testSynonymSwapIsFlagged() {
        XCTAssertTrue(flagged("send the note at that moment", "send the reminder at that time"))
    }

    func testDeletedContentIsFlagged() {
        // Grammar must never remove content.
        XCTAssertTrue(flagged("Please send the report and the invoice today", "Please send the report today"))
    }

    func testAddedContentIsFlagged() {
        XCTAssertTrue(flagged("Send the report", "Send the report at your earliest convenience"))
    }

    // MARK: - Threshold sanity

    func testCeilingSitsBetweenCorrectionAndRewordClusters() {
        let correction = score(
            "their are three thing we need to discus before the meting tommorow",
            "There are three things we need to discuss before the meeting tomorrow"
        )
        let reword = score("send the note at that moment", "send the reminder at that time")
        XCTAssertLessThan(correction, PanelEngine.grammarParaphraseCeiling)
        XCTAssertGreaterThan(reword, PanelEngine.grammarParaphraseCeiling)
    }
}

/// Regenerate must not ask Grammar for different wording — that instruction is
/// what turned the corrector into a paraphraser in the reported case.
final class RegenerateScopeTests: XCTestCase {
    func testRewriteRegenerateAsksForSomethingDifferent() {
        let suffix = Prompts.regenerateSuffix(previous: "prior text")
        XCTAssertTrue(suffix.contains("DIFFERENT"))
        XCTAssertTrue(suffix.contains("prior text"))
    }

    func testGrammarRecheckForbidsRewording() {
        let suffix = Prompts.recheckSuffix(previous: "prior text")
        XCTAssertTrue(suffix.contains("prior text"))
        // Must not ask for a different version...
        XCTAssertFalse(suffix.contains("DIFFERENT"))
        XCTAssertFalse(suffix.lowercased().contains("noticeably different"))
        // ...and must say an unchanged document is acceptable.
        XCTAssertTrue(suffix.lowercased().contains("synonym"))
        XCTAssertTrue(suffix.lowercased().contains("unchanged"))
    }
}
