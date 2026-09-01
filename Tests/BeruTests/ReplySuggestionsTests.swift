import XCTest
@testable import Beru

final class ReplySuggestionsTests: XCTestCase {
    private let tagged = """
    preamble
    <reply tone="formal">Yes. I will send it Friday.</reply>
    <reply tone="casual">Yep — Friday works.</reply>
    <reply tone="funny">Friday it is. The deck, not my weekend.</reply>
    <reply tone="professional">I'll send the deck by Friday.</reply>
    <reply tone="witty">Friday works. Thursday gets the bad news if any.</reply>
    <reply tone="sharp">Deck by Friday.</reply>
    """

    func testParseHappyPathYieldsSixTonesInOrder() {
        let parsed = ReplySuggestions.parse(tagged)
        XCTAssertEqual(parsed.map(\.tone), ReplyTone.allCases)
        XCTAssertEqual(parsed.first?.body, "Yes. I will send it Friday.")
        XCTAssertEqual(parsed.last?.body, "Deck by Friday.")
    }

    func testMissingTonesAreDroppedNotInvented() {
        let raw = """
        <reply tone="formal">Formal body.</reply>
        <reply tone="sharp">Sharp body.</reply>
        """
        let parsed = ReplySuggestions.parse(raw)
        XCTAssertEqual(parsed.map(\.tone), [.formal, .sharp])
        XCTAssertEqual(parsed.map(\.body), ["Formal body.", "Sharp body."])
    }

    func testUnknownToneIsIgnored() {
        let raw = """
        <reply tone="roast">Nope.</reply>
        <reply tone="casual">Hi.</reply>
        """
        let parsed = ReplySuggestions.parse(raw)
        XCTAssertEqual(parsed.map(\.tone), [.casual])
        XCTAssertEqual(parsed.first?.body, "Hi.")
    }

    func testDuplicateToneKeepsTheFirstBody() {
        let raw = """
        <reply tone="formal">First.</reply>
        <reply tone="formal">Second.</reply>
        """
        let parsed = ReplySuggestions.parse(raw)
        XCTAssertEqual(parsed, [ReplySuggestion(tone: .formal, body: "First.")])
    }

    func testMalformedMarkupFallsBackToRawText() {
        let parsed = ReplySuggestions.parse("Just a plain reply without tags.")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.tone, .formal)
        XCTAssertEqual(parsed.first?.body, "Just a plain reply without tags.")
    }

    func testEmptyInputParsesToNothing() {
        XCTAssertTrue(ReplySuggestions.parse("   \n").isEmpty)
    }

    func testStripsFencesAndQuotesFromABody() {
        let raw = """
        <reply tone="casual">
        ```
        "Hello there."
        ```
        </reply>
        """
        XCTAssertEqual(ReplySuggestions.parse(raw).first?.body, "Hello there.")
    }

    func testSelectedBodyPrefersMatchingToneThenFirst() {
        let suggestions = [
            ReplySuggestion(tone: .casual, body: "casual"),
            ReplySuggestion(tone: .sharp, body: "sharp")
        ]
        XCTAssertEqual(ReplySuggestions.body(in: suggestions, matching: .sharp), "sharp")
        XCTAssertEqual(ReplySuggestions.body(in: suggestions, matching: .formal), "casual")
    }

    func testPromptCatalogListsEveryTone() {
        XCTAssertEqual(ReplyTone.allCases.count, 6)
        for tone in ReplyTone.allCases {
            XCTAssertTrue(Prompts.reply.contains("tone=\"\(tone.rawValue)\""), tone.rawValue)
            XCTAssertTrue(ReplyTone.promptCatalog.contains(tone.rawValue), tone.rawValue)
        }
        XCTAssertTrue(Prompts.reply.contains("Output ONLY"))
        XCTAssertTrue(Prompts.reply.contains("concrete detail"))
        XCTAssertTrue(Prompts.reply.contains("Sounds good"))
        XCTAssertTrue(Prompts.reply.contains("Humour belongs only in the Funny and Witty tones"))
        XCTAssertFalse(Prompts.reply.contains("Where the tone allows, be humorous"))
        XCTAssertTrue(ReplyTone.formal.job.lowercased().contains("no humour"))
        XCTAssertTrue(ReplyTone.funny.job.lowercased().contains("content"))
        XCTAssertTrue(ReplyTone.witty.job.lowercased().contains("dry observation"))
    }

    func testReplyTemperatureIsHigherThanEnhanceAndGrammarStaysZero() {
        XCTAssertEqual(ProviderTuning.temperature(for: .enhance), 0.3)
        XCTAssertEqual(
            ProviderTuning.temperature(for: .enhance, actionID: EnhancementAction.replyID),
            ProviderTuning.replyTemperature
        )
        XCTAssertEqual(ProviderTuning.temperature(for: .grammar), 0.0)
        XCTAssertEqual(
            ProviderTuning.temperature(for: .grammar, actionID: EnhancementAction.grammarID),
            0.0
        )
    }

    @MainActor
    func testAcceptedTextUsesTheSelectedCardNotTheTaggedBlob() {
        let state = AppState()
        state.selectAction(EnhancementAction.replyID)
        state.setResult(.done("<reply tone=\"formal\">ALL TAGS</reply>"), for: EnhancementAction.replyID)
        state.replySuggestions = [
            ReplySuggestion(tone: .formal, body: "Formal pick"),
            ReplySuggestion(tone: .witty, body: "Witty pick")
        ]
        state.selectedReplyTone = .witty
        XCTAssertEqual(state.acceptedText(), "Witty pick")

        state.selectAction(EnhancementAction.grammarID)
        state.setResult(.done("corrected"), for: EnhancementAction.grammarID)
        XCTAssertEqual(state.acceptedText(), "corrected")
    }
}
