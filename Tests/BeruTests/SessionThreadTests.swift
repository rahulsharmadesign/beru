import XCTest
@testable import Beru

@MainActor
final class SessionThreadTests: XCTestCase {
    private let thread = SessionThread.shared

    override func setUp() {
        super.setUp()
        thread.clear()
    }

    override func tearDown() {
        thread.clear()
        super.tearDown()
    }

    private func record(
        _ output: String,
        actionID: String = EnhancementAction.enhanceID,
        instruction: String = "",
        input: String = "some selected text",
        bundleID: String? = "com.apple.mail",
        at: Date = Date()
    ) {
        thread.record(
            actionID: actionID,
            actionName: "Enhance",
            instruction: instruction,
            input: input,
            output: output,
            bundleID: bundleID,
            at: at
        )
    }

    func testKeepsOnlyTheLastThreeTurns() {
        for i in 1...5 { record("output \(i)") }
        let turns = thread.turns(forBundleID: "com.apple.mail")
        XCTAssertEqual(turns.count, SessionThread.maxTurns)
        XCTAssertEqual(turns.map(\.output), ["output 3", "output 4", "output 5"])
    }

    func testTurnsAreScopedToTheAppTheyWereRecordedIn() {
        record("mail output", bundleID: "com.apple.mail")
        XCTAssertEqual(thread.turns(forBundleID: "com.apple.mail").count, 1)
        XCTAssertTrue(
            thread.turns(forBundleID: "com.apple.Terminal").isEmpty,
            "a thread must never be readable from another app"
        )
    }

    func testRecordingFromANewAppStartsAFreshConversation() {
        record("mail output", bundleID: "com.apple.mail")
        record("terminal output", bundleID: "com.apple.Terminal")
        let turns = thread.turns(forBundleID: "com.apple.Terminal")
        XCTAssertEqual(turns.map(\.output), ["terminal output"])
        XCTAssertTrue(thread.turns(forBundleID: "com.apple.mail").isEmpty)
    }

    func testHostChangeClearsTheThread() {
        record("mail output", bundleID: "com.apple.mail")
        thread.hostChanged(to: "com.apple.Terminal")
        XCTAssertTrue(thread.turns(forBundleID: "com.apple.Terminal").isEmpty)
        XCTAssertTrue(thread.turns(forBundleID: "com.apple.mail").isEmpty)
    }

    func testHostChangeToTheSameAppKeepsTheThread() {
        record("mail output", bundleID: "com.apple.mail")
        thread.hostChanged(to: "com.apple.mail")
        XCTAssertEqual(thread.turns(forBundleID: "com.apple.mail").count, 1)
    }

    func testTurnsExpireAfterTheIdleTimeout() {
        let stale = Date().addingTimeInterval(-(SessionThread.idleTimeout + 60))
        record("old output", at: stale)
        XCTAssertTrue(thread.turns(forBundleID: "com.apple.mail").isEmpty)
    }

    func testTurnsInsideTheIdleWindowSurvive() {
        let recent = Date().addingTimeInterval(-(SessionThread.idleTimeout - 60))
        record("recent output", at: recent)
        XCTAssertEqual(thread.turns(forBundleID: "com.apple.mail").count, 1)
    }

    func testGrammarIsNeverRecorded() {
        record("corrected text", actionID: EnhancementAction.grammarID)
        XCTAssertTrue(
            thread.turns(forBundleID: "com.apple.mail").isEmpty,
            "correction is mechanical; history can only pull it toward rewriting"
        )
    }

    func testCustomActionsAreNotRecorded() {
        record("output", actionID: "action-custom-1234")
        XCTAssertTrue(thread.turns(forBundleID: "com.apple.mail").isEmpty)
    }

    func testEnhanceDescribeAndSearchAreRecorded() {
        for id in [EnhancementAction.enhanceID, EnhancementAction.describeID, EnhancementAction.searchID] {
            thread.clear()
            record("output", actionID: id)
            XCTAssertEqual(thread.turns(forBundleID: "com.apple.mail").count, 1, "\(id) should be recorded")
        }
    }

    func testEmptyOutputIsNotATurn() {
        record("   \n  ")
        XCTAssertTrue(thread.turns(forBundleID: "com.apple.mail").isEmpty)
    }

    func testOutputIsTruncatedToBudget() {
        record(String(repeating: "word ", count: 500))
        let turn = thread.turns(forBundleID: "com.apple.mail").first
        XCTAssertNotNil(turn)
        XCTAssertLessThanOrEqual(turn!.output.count, SessionThread.outputCharBudget + 1)
        XCTAssertTrue(turn!.output.hasSuffix("…"))
    }

    func testInputDigestIsTruncatedToBudget() {
        record("output", input: String(repeating: "sentence ", count: 200))
        let turn = thread.turns(forBundleID: "com.apple.mail").first
        XCTAssertLessThanOrEqual(turn?.inputDigest.count ?? 0, SessionThread.inputDigestCharBudget + 1)
    }

    func testClipCollapsesNewlinesSoTheBlockStaysOneLinePerTurn() {
        XCTAssertEqual(SessionThread.clip("a\nb\nc", to: 100), "a b c")
    }

    // MARK: - The prompt layer

    func testEmptyThreadLeavesThePromptByteIdentical() {
        let system = "BASE PROMPT"
        XCTAssertEqual(Prompts.composeWithThread(system, turns: []), system)
    }

    func testComposedBlockNamesTheActionAndTheOutput() {
        record("the enhanced prompt", instruction: "make it shorter")
        let turns = thread.turns(forBundleID: "com.apple.mail")
        let composed = Prompts.composeWithThread("BASE", turns: turns)
        XCTAssertTrue(composed.hasPrefix("BASE"))
        XCTAssertTrue(composed.contains("RECENT TURNS IN THIS APP"))
        XCTAssertTrue(composed.contains("make it shorter"))
        XCTAssertTrue(composed.contains("the enhanced prompt"))
    }

    func testComposedBlockStaysInsideItsBudget() {
        for i in 1...SessionThread.maxTurns {
            record(String(repeating: "long output \(i) ", count: 200))
        }
        let turns = thread.turns(forBundleID: "com.apple.mail")
        let composed = Prompts.composeWithThread("BASE", turns: turns)
        let block = composed.replacingOccurrences(of: "BASE", with: "")
        // The budget covers the turn lines; the fixed heading is not user text.
        XCTAssertLessThan(block.count, SessionThread.blockCharBudget * 2)
    }

    func testTheMostRecentTurnSurvivesWhenTheBudgetIsSpent() {
        let long = String(repeating: "x", count: SessionThread.outputCharBudget)
        for i in 1...SessionThread.maxTurns { record("\(long)\(i)") }
        let turns = thread.turns(forBundleID: "com.apple.mail")
        let composed = Prompts.composeWithThread("BASE", turns: turns)
        XCTAssertTrue(
            composed.contains("1 turn(s) ago"),
            "the newest turn is the one a follow-up refers to and must never be dropped"
        )
    }

    func testThreadScopeMatchesWhatIsRecorded() {
        XCTAssertTrue(Prompts.threadApplies(actionID: EnhancementAction.enhanceID))
        XCTAssertTrue(Prompts.threadApplies(actionID: EnhancementAction.describeID))
        XCTAssertTrue(Prompts.threadApplies(actionID: EnhancementAction.searchID))
        XCTAssertFalse(Prompts.threadApplies(actionID: EnhancementAction.grammarID))
        XCTAssertFalse(Prompts.threadApplies(actionID: "action-custom-1234"))
    }
}
