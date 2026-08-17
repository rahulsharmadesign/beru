import XCTest
@testable import Beru

/// An inline diff only communicates while the two texts still share a skeleton.
/// Past that the renderer interleaves two unrelated documents word by word and the
/// result looks corrupted, so the diff is suppressed in favour of the plain text.
///
/// The thresholds here are calibrated from measured values, and these tests are
/// what stop the constant drifting back into either failure mode: too low and
/// rewrites render as garbage, too high and ordinary copy-edits lose their diff.
final class DiffLegibilityTests: XCTestCase {
    private func retention(_ original: String, _ revised: String) -> Double {
        WordDiff.retentionRatio(WordDiff.diff(original: original, revised: revised))
    }

    private func showsDiff(_ original: String, _ revised: String) -> Bool {
        retention(original, revised) >= PanelEngine.diffLegibilityFloor
    }

    // MARK: - Edits keep their diff

    func testSingleTypoKeepsItsDiff() {
        XCTAssertTrue(showsDiff("helo world", "hello world"))
    }

    func testShortGrammarPassKeepsItsDiff() {
        XCTAssertTrue(showsDiff(
            "send me teh report by friday pls",
            "Send me the report by Friday."
        ))
    }

    func testLongGrammarPassKeepsItsDiff() {
        XCTAssertTrue(showsDiff(
            "i was wondering if maybe you could possibly send over teh quarterly report when you get a chance thanks",
            "I was wondering if you could send over the quarterly report when you get a chance. Thanks."
        ))
    }

    func testToneRewriteKeepsItsDiff() {
        // The tightest real case — retains ~0.48, just above the floor.
        XCTAssertTrue(showsDiff(
            "send me the report by friday",
            "Could you please send me the report by Friday?"
        ))
    }

    func testIdenticalTextKeepsItsDiff() {
        XCTAssertTrue(showsDiff("unchanged text", "unchanged text"))
        XCTAssertEqual(retention("unchanged text", "unchanged text"), 1)
    }

    // MARK: - Rewrites drop it

    func testRewriteIntoStructuredPromptDropsTheDiff() {
        // The reported garbling: Enhance rewrote a rough request into a
        // Claude-targeted prompt with XML delimiters, sharing almost no wording
        // with the input, and the diff rendered as "Can<context>".
        XCTAssertFalse(showsDiff(
            "Can I need create a unique and different layout for a quiz in light mode.",
            """
            <context>
            I need a unique and different layout for a quiz in light mode.
            </context>
            <task>
            Create another surprise version in light mode for this quiz layout. The
            layout must be very unique and different from the image.
            </task>
            """
        ))
    }

    func testTotalRewriteDropsTheDiff() {
        XCTAssertFalse(showsDiff(
            "quick note about lunch",
            "Please confirm the venue for Thursday's review."
        ))
    }

    // MARK: - The metric itself

    func testRetentionIsZeroWhenNothingIsShared() {
        XCTAssertEqual(retention("aaaa", "bbbb"), 0)
    }

    func testEmptyRevisionIsTreatedAsFullyRetained() {
        // No text to show means no misleading diff to render.
        XCTAssertEqual(retention("anything", ""), 1)
    }

    func testDeletionsDoNotCountTowardsLength() {
        // Retention measures against what the user is reading, so a large
        // deletion alone must not depress it — the surviving text is intact.
        XCTAssertEqual(retention("keep this and drop all of that", "keep this"), 1, accuracy: 0.0001)
    }

    func testFloorSitsBetweenTheMeasuredEditAndRewriteClusters() {
        // Edits measured 0.478-0.800, rewrites 0.064-0.273.
        XCTAssertGreaterThan(PanelEngine.diffLegibilityFloor, 0.30)
        XCTAssertLessThan(PanelEngine.diffLegibilityFloor, 0.47)
    }

    // MARK: - Which actions show a diff

    func testTransformVerbsNeverShowInlineDiff() {
        XCTAssertFalse(EnhancementAction.showsInlineDiff(for: EnhancementAction.summarizeID))
        XCTAssertFalse(EnhancementAction.showsInlineDiff(for: EnhancementAction.replyID))
        XCTAssertFalse(EnhancementAction.showsInlineDiff(for: EnhancementAction.explainID))
        XCTAssertFalse(EnhancementAction.showsInlineDiff(for: EnhancementAction.describeID))
    }

    func testEditActionsKeepInlineDiff() {
        XCTAssertTrue(EnhancementAction.showsInlineDiff(for: EnhancementAction.grammarID))
        XCTAssertTrue(EnhancementAction.showsInlineDiff(for: EnhancementAction.enhanceID))
    }
}
