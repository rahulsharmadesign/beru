import XCTest
@testable import Beru

final class OutputQualityTests: XCTestCase {
    private let taggedReplies = """
    <reply tone="formal">Yes. I will send the Q3 deck by Friday.</reply>
    <reply tone="casual">Yep — Q3 deck lands Friday.</reply>
    <reply tone="funny">Friday for the deck, Thursday for any DPA drama.</reply>
    <reply tone="professional">I'll have the Q3 deck to you by Friday.</reply>
    <reply tone="witty">Friday's the deck; Thursday is the confession window.</reply>
    <reply tone="sharp">Q3 deck by Friday.</reply>
    """

    private let taggedGrammar = """
    <grammar kind="corrected">There are three things we need to discuss before the meeting tomorrow.</grammar>
    <grammar kind="clearer">There are three things we need to discuss before tomorrow's meeting.</grammar>
    <grammar kind="tighter">There are three things to discuss before tomorrow's meeting.</grammar>
    """

    private func evaluate(
        actionID: String,
        raw: String,
        source: String,
        selectedReplyTone: ReplyTone = .formal,
        preferredGrammarKind: GrammarKind? = nil,
        canRetry: Bool
    ) -> OutputQuality.Decision {
        OutputQuality.evaluate(
            actionID: actionID,
            raw: raw,
            source: source,
            selectedReplyTone: selectedReplyTone,
            preferredGrammarKind: preferredGrammarKind,
            canRetry: canRetry
        )
    }

    // MARK: - Reply accepted body

    func testReplyPublishesSelectedBodyNotTaggedBlob() {
        let decision = evaluate(
            actionID: EnhancementAction.replyID,
            raw: taggedReplies,
            source: "Priya — can you send the Q3 deck by Friday?",
            selectedReplyTone: .sharp,
            canRetry: true
        )
        XCTAssertEqual(decision.outcome, .publish)
        XCTAssertEqual(decision.text, "Q3 deck by Friday.")
        XCTAssertFalse(decision.text.contains("<reply"))
        XCTAssertEqual(decision.replySuggestions.count, 6)
        XCTAssertEqual(decision.selectedReplyTone, .sharp)
    }

    func testReplyFallsBackToFirstKeptToneWhenSelectionMissing() {
        let decision = evaluate(
            actionID: EnhancementAction.replyID,
            raw: taggedReplies,
            source: "Priya — can you send the Q3 deck by Friday?",
            selectedReplyTone: .formal,
            canRetry: false
        )
        XCTAssertEqual(decision.selectedReplyTone, .formal)
        XCTAssertEqual(decision.text, "Yes. I will send the Q3 deck by Friday.")
    }

    func testReplyUntaggedRetriesOnce() {
        let decision = evaluate(
            actionID: EnhancementAction.replyID,
            raw: "Just a plain reply without tags.",
            source: "Can you send the deck by Friday?",
            canRetry: true
        )
        XCTAssertEqual(
            decision.outcome,
            .retry(previousResult: nil, hint: OutputQuality.parseHint)
        )
    }

    func testReplyUntaggedPublishesFallbackWhenRetryIsSpent() {
        let decision = evaluate(
            actionID: EnhancementAction.replyID,
            raw: "Just a plain reply without tags.",
            source: "Can you send the deck by Friday?",
            canRetry: false
        )
        XCTAssertEqual(decision.outcome, .publish)
        XCTAssertEqual(decision.text, "Just a plain reply without tags.")
        XCTAssertEqual(decision.replySuggestions.first?.tone, .formal)
        XCTAssertFalse(decision.text.contains("<reply"))
    }

    func testReplyDropsWrongLanguageTones() {
        let raw = """
        <reply tone="formal">Sure — the deck will be with you on Friday.</reply>
        <reply tone="casual">Obrigado pelo feedback de ontem.</reply>
        <reply tone="funny">Deck Friday, DPA Thursday.</reply>
        <reply tone="professional">I'll send the deck by Friday.</reply>
        <reply tone="witty">Friday for the deck.</reply>
        <reply tone="sharp">Deck by Friday.</reply>
        """
        let decision = evaluate(
            actionID: EnhancementAction.replyID,
            raw: raw,
            source: "Can you send the deck by Friday?",
            selectedReplyTone: .casual,
            canRetry: false
        )
        XCTAssertEqual(decision.outcome, .publish)
        XCTAssertFalse(decision.replySuggestions.contains(where: { $0.tone == .casual }))
        XCTAssertEqual(decision.selectedReplyTone, .formal)
        XCTAssertEqual(decision.text, "Sure — the deck will be with you on Friday.")
    }

    func testReplyAllWrongLanguageRetriesThenRejects() {
        let raw = """
        <reply tone="formal">Obrigado pelo feedback de ontem sobre o material.</reply>
        <reply tone="casual">Obrigado pelo feedback de ontem sobre o material.</reply>
        <reply tone="funny">Obrigado pelo feedback de ontem sobre o material.</reply>
        <reply tone="professional">Obrigado pelo feedback de ontem sobre o material.</reply>
        <reply tone="witty">Obrigado pelo feedback de ontem sobre o material.</reply>
        <reply tone="sharp">Obrigado pelo feedback de ontem sobre o material.</reply>
        """
        let source = "Can you send the deck by Friday?"
        let retry = evaluate(
            actionID: EnhancementAction.replyID,
            raw: raw,
            source: source,
            canRetry: true
        )
        XCTAssertEqual(
            retry.outcome,
            .retry(previousResult: nil, hint: OutputQuality.replyLanguageHint)
        )
        let reject = evaluate(
            actionID: EnhancementAction.replyID,
            raw: raw,
            source: source,
            canRetry: false
        )
        XCTAssertEqual(reject.outcome, .reject(message: OutputQuality.languageMessage))
    }

    // MARK: - Grammar

    func testGrammarPublishesPreferredKindBody() {
        let decision = evaluate(
            actionID: EnhancementAction.grammarID,
            raw: taggedGrammar,
            source: "their are three thing we need to discus before the meting tommorow",
            preferredGrammarKind: .tighter,
            canRetry: true
        )
        XCTAssertEqual(decision.outcome, .publish)
        XCTAssertEqual(decision.selectedGrammarKind, .tighter)
        XCTAssertEqual(decision.text, "There are three things to discuss before tomorrow's meeting.")
        XCTAssertEqual(decision.grammarSuggestions.count, 3)
    }

    func testGrammarUntaggedRetriesOnce() {
        let decision = evaluate(
            actionID: EnhancementAction.grammarID,
            raw: "He doesn't know whether it's right.",
            source: "he dont know weather its right",
            canRetry: true
        )
        XCTAssertEqual(
            decision.outcome,
            .retry(previousResult: nil, hint: OutputQuality.parseHint)
        )
    }

    func testGrammarParaphraseRetriesThenRevertsCorrectedToSource() {
        let original = "One housekeeping note: your clipboard is empty. My backup of it captured nothing at that moment, so there was nothing to put back."
        let revised = "One housekeeping reminder: your clipboard contains no data. My attempt to back it up found nothing at that time, meaning there was nothing to restore."
        let raw = """
        <grammar kind="corrected">\(revised)</grammar>
        <grammar kind="clearer">\(revised)</grammar>
        <grammar kind="tighter">\(revised)</grammar>
        """
        let retry = evaluate(
            actionID: EnhancementAction.grammarID,
            raw: raw,
            source: original,
            canRetry: true
        )
        XCTAssertEqual(
            retry.outcome,
            .retry(previousResult: revised, hint: nil)
        )
        let reverted = evaluate(
            actionID: EnhancementAction.grammarID,
            raw: raw,
            source: original,
            canRetry: false
        )
        XCTAssertEqual(reverted.outcome, .publish)
        XCTAssertEqual(reverted.selectedGrammarKind, .corrected)
        XCTAssertEqual(reverted.text, original)
        XCTAssertEqual(
            reverted.grammarSuggestions.first(where: { $0.kind == .corrected })?.body,
            original
        )
        XCTAssertNil(reverted.grammarSuggestions.first(where: { $0.kind == .clearer }))
        XCTAssertNil(reverted.grammarSuggestions.first(where: { $0.kind == .tighter }))
    }

    func testGrammarCorrectionIsNotTreatedAsParaphrase() {
        let original = "their are three thing we need to discus before the meting tommorow"
        let decision = evaluate(
            actionID: EnhancementAction.grammarID,
            raw: taggedGrammar,
            source: original,
            canRetry: true
        )
        XCTAssertEqual(decision.outcome, .publish)
        XCTAssertTrue(decision.text.contains("There are three things"))
    }

    // MARK: - Unchanged transform

    func testSummarizeUnchangedRetriesThenRejects() {
        let source = "We met Tuesday. Priya will own billing. Launch slips to May 12."
        let retry = evaluate(
            actionID: EnhancementAction.summarizeID,
            raw: source,
            source: source,
            canRetry: true
        )
        XCTAssertEqual(retry.outcome, .retry(previousResult: source, hint: nil))
        let reject = evaluate(
            actionID: EnhancementAction.summarizeID,
            raw: source,
            source: source,
            canRetry: false
        )
        XCTAssertEqual(reject.outcome, .reject(message: OutputQuality.unchangedMessage))
    }

    func testSummarizeWhitespaceOnlyDifferenceCountsAsUnchanged() {
        let source = "We met Tuesday.\nPriya owns billing."
        let raw = "We met Tuesday. Priya owns billing."
        XCTAssertTrue(OutputQuality.isUnchanged(source: source, output: raw))
        let decision = evaluate(
            actionID: EnhancementAction.explainID,
            raw: raw,
            source: source,
            canRetry: false
        )
        XCTAssertEqual(decision.outcome, .reject(message: OutputQuality.unchangedMessage))
    }

    func testSummarizeDifferentTextPublishes() {
        let decision = evaluate(
            actionID: EnhancementAction.summarizeID,
            raw: "- Met Tuesday\n- Priya owns billing",
            source: "We met Tuesday. Priya will own billing. Launch slips to May 12.",
            canRetry: true
        )
        XCTAssertEqual(decision.outcome, .publish)
        XCTAssertTrue(decision.text.contains("Priya"))
    }

    func testEnhanceUnchangedStillPublishes() {
        let source = "write a poem about the sea"
        let decision = evaluate(
            actionID: EnhancementAction.enhanceID,
            raw: source,
            source: source,
            canRetry: true
        )
        XCTAssertEqual(decision.outcome, .publish)
        XCTAssertEqual(decision.text, source)
    }

    func testGrammarUnchangedStillPublishes() {
        let source = "The meeting is at 3 PM tomorrow."
        let raw = """
        <grammar kind="corrected">\(source)</grammar>
        <grammar kind="clearer">\(source)</grammar>
        <grammar kind="tighter">\(source)</grammar>
        """
        let decision = evaluate(
            actionID: EnhancementAction.grammarID,
            raw: raw,
            source: source,
            canRetry: true
        )
        XCTAssertEqual(decision.outcome, .publish)
        XCTAssertEqual(decision.text, source)
    }

    func testRejectsUnchangedOnlyOnTransformVerbs() {
        XCTAssertTrue(EnhancementAction.rejectsUnchangedOutput(EnhancementAction.summarizeID))
        XCTAssertTrue(EnhancementAction.rejectsUnchangedOutput(EnhancementAction.explainID))
        XCTAssertTrue(EnhancementAction.rejectsUnchangedOutput(EnhancementAction.describeID))
        XCTAssertFalse(EnhancementAction.rejectsUnchangedOutput(EnhancementAction.enhanceID))
        XCTAssertFalse(EnhancementAction.rejectsUnchangedOutput(EnhancementAction.grammarID))
        XCTAssertFalse(EnhancementAction.rejectsUnchangedOutput(EnhancementAction.replyID))
    }
}
