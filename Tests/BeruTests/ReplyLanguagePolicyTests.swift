import XCTest
@testable import Beru

final class ReplyLanguagePolicyTests: XCTestCase {
    private let hinglish = """
    Aap bahut acchi post share karti ho style bahut achcha lagta hai, no faltu kich pich 😇
    """

    func testRomanHinglishIsLatinScriptAndCodeMixed() {
        let policy = ReplyLanguagePolicy.analyze(hinglish)
        XCTAssertEqual(policy.script, .latin)
        XCTAssertTrue(policy.isCodeMixed, "Expected Hinglish to read as code-mixed Latin")
    }

    func testRomanHinglishPromptMentionsLatinAndCodeMix() {
        let block = ReplyLanguagePolicy.analyze(hinglish).promptBlock
        XCTAssertTrue(block.contains("Roman/Latin script"))
        XCTAssertTrue(block.contains("code-mixed"))
        XCTAssertTrue(block.contains("Do not mix languages"))
        XCTAssertFalse(block.contains("Devanagari script"))
    }

    func testEnglishIsLatinNotCodeMixed() {
        let policy = ReplyLanguagePolicy.analyze("Can you send the deck by Friday?")
        XCTAssertEqual(policy.script, .latin)
        XCTAssertFalse(policy.isCodeMixed)
        XCTAssertTrue(policy.promptBlock.contains("English"))
    }

    func testDevanagariInputAllowsDevanagariOutput() {
        let hindi = "धन्यवाद, बहुत अच्छी पोस्ट है।"
        let policy = ReplyLanguagePolicy.analyze(hindi)
        XCTAssertEqual(policy.script, .devanagari)
        XCTAssertTrue(policy.promptBlock.contains("Devanagari"))
        XCTAssertFalse(policy.outputViolatesScript("आपका धन्यवाद"))
    }

    func testLatinInputFlagsDevanagariOutput() {
        let policy = ReplyLanguagePolicy.analyze(hinglish)
        let devanagariReply = "धन्यवाद, मैं आपके सराहना की सराहना करती हूँ।"
        XCTAssertTrue(policy.bodyViolatesPolicy(devanagariReply))
        XCTAssertFalse(policy.bodyViolatesPolicy("Thanks yaar, agla topic bata dena."))
    }

    func testGermanReplyViolatesHinglishInput() {
        let policy = ReplyLanguagePolicy.analyze(hinglish)
        XCTAssertTrue(policy.bodyViolatesPolicy("Vielen Dank für das Kompliment!"))
    }

    func testEnglishInputFlagsAnyWrongLanguageNotJustAFew() {
        let policy = ReplyLanguagePolicy.analyze("Can you send the deck by Friday?")
        XCTAssertTrue(policy.bodyViolatesPolicy("Obrigado pelo feedback de ontem."))
        XCTAssertTrue(policy.bodyViolatesPolicy("Спасибо, посмотрим отчёт в пятницу."))
        XCTAssertFalse(policy.bodyViolatesPolicy("Sure — the deck will be with you on Friday."))
    }

    func testIndicScriptInputFlagsEuropeanDrift() {
        let policy = ReplyLanguagePolicy.analyze("धन्यवाद, बहुत अच्छी पोस्ट है।")
        XCTAssertTrue(policy.bodyViolatesPolicy("Gracias por compartir la publicación."))
        XCTAssertFalse(policy.bodyViolatesPolicy("आपका धन्यवाद, अगली पोस्ट भी देखूंगा।"))
    }

    func testMixedLanguagesAcrossRepliesIsFlagged() {
        let policy = ReplyLanguagePolicy.analyze(hinglish)
        let mixed = [
            ReplySuggestion(tone: .formal, body: "Vielen Dank für das Kompliment!"),
            ReplySuggestion(tone: .professional, body: "I appreciate your feedback on the post.")
        ]
        XCTAssertTrue(ReplyLanguagePolicy.repliesViolatePolicy(mixed, input: policy))
    }

    func testLanguageBlockRequiresOneLanguageAcrossSix() {
        let block = ReplyLanguagePolicy.analyze(hinglish).promptBlock
        XCTAssertTrue(block.contains("SAME language"))
        XCTAssertTrue(block.contains("Do not mix languages"))
    }

    func testComposeWithReplyLanguageAppendsBlock() {
        let policy = ReplyLanguagePolicy.analyze(hinglish)
        let composed = Prompts.composeWithReplyLanguage(Prompts.reply, policy: policy)
        XCTAssertTrue(composed.hasPrefix(Prompts.reply))
        XCTAssertTrue(composed.contains("LANGUAGE AND SCRIPT"))
    }

    func testComposeWithReplyLanguageNoOpsWhenNil() {
        XCTAssertEqual(
            Prompts.composeWithReplyLanguage(Prompts.reply, policy: nil),
            Prompts.reply
        )
    }

    func testReplyPromptIncludesHinglishFewShot() {
        XCTAssertTrue(Prompts.reply.contains("Aap bahut acchi post"))
        XCTAssertTrue(Prompts.reply.contains("script"))
    }
}
