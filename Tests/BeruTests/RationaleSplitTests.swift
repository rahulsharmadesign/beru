import XCTest
@testable import Beru

/// The rationale must never survive into the result: `PanelView.performReplace`
/// pastes the result verbatim into the user's document, so a leak here ends up
/// in somebody's Slack message.
@MainActor
final class RationaleSplitTests: XCTestCase {
    func testSplitsResultFromRationale() {
        let (result, rationale) = PanelEngine.splitRationale(
            "Ship it by Friday.\n<why>Cut the hedge — leading with the ask is direct.</why>"
        )
        XCTAssertEqual(result, "Ship it by Friday.")
        XCTAssertEqual(rationale, "Cut the hedge — leading with the ask is direct.")
    }

    func testTextWithoutATagIsUntouched() {
        let (result, rationale) = PanelEngine.splitRationale("Ship it by Friday.")
        XCTAssertEqual(result, "Ship it by Friday.")
        XCTAssertNil(rationale)
    }

    func testUnterminatedTagStillSplits() {
        // A cancelled or token-capped stream can stop mid-rationale. The markup
        // must not end up in the result even then.
        let (result, rationale) = PanelEngine.splitRationale("Ship it by Friday.\n<why>Cut the hed")
        XCTAssertEqual(result, "Ship it by Friday.")
        XCTAssertEqual(rationale, "Cut the hed")
        XCTAssertFalse(result.contains("<why"))
    }

    func testEmptyRationaleSectionIsTreatedAsAbsent() {
        let (result, rationale) = PanelEngine.splitRationale("Ship it.\n<why>\n</why>")
        XCTAssertEqual(result, "Ship it.")
        XCTAssertNil(rationale)
    }

    func testTagMidBodySplitsAtTheFirstOccurrence() {
        // Whatever follows the first tag is explanation, even if the model
        // rambles on afterwards.
        let (result, rationale) = PanelEngine.splitRationale("A<why>first</why> tail <why>second</why>")
        XCTAssertEqual(result, "A")
        XCTAssertEqual(rationale, "first")
        XCTAssertFalse(result.contains("<why"))
    }

    func testTrailingContentAfterCloseTagIsDiscarded() {
        let (result, rationale) = PanelEngine.splitRationale("Body.\n<why>Reason.</why>\nStray commentary.")
        XCTAssertEqual(result, "Body.")
        XCTAssertEqual(rationale, "Reason.")
    }

    // MARK: - Streaming

    func testStreamingHidesTheRationaleOnceItStarts() {
        XCTAssertEqual(
            PanelEngine.visibleWhileStreaming("Ship it by Friday.\n<why>Cut the hed"),
            "Ship it by Friday.\n"
        )
    }

    func testStreamingHidesAPartialOpeningTag() {
        // Without this the user watches "<wh" appear and then vanish.
        for partial in ["<", "<w", "<wh", "<why"] {
            XCTAssertEqual(
                PanelEngine.visibleWhileStreaming("Ship it." + partial),
                "Ship it.",
                "failed for partial \(partial)"
            )
        }
    }

    func testStreamingLeavesOrdinaryTextAlone() {
        XCTAssertEqual(PanelEngine.visibleWhileStreaming("Ship it by Friday."), "Ship it by Friday.")
    }

    func testStreamingKeepsAnUnrelatedTrailingAngleBracket() {
        // "5 < 6" ends in a real character, not a partial tag prefix.
        XCTAssertEqual(PanelEngine.visibleWhileStreaming("5 < 6"), "5 < 6")
    }

    // MARK: - Interaction with wrapping strippers

    func testSplittingBeforeStrippingRecoversAFencedResult() {
        // strippedWrapping matches on prefix AND suffix, so a trailing rationale
        // block hides the closing fence from it. This is why the engine splits
        // first.
        let raw = "```\nShip it.\n```\n<why>Trimmed the preamble.</why>"
        let (body, rationale) = PanelEngine.splitRationale(raw)
        XCTAssertEqual(PanelEngine.strippedWrapping(body), "Ship it.")
        XCTAssertEqual(rationale, "Trimmed the preamble.")

        // And the wrong order leaves the fence in place, which is the bug the
        // ordering prevents.
        XCTAssertTrue(PanelEngine.strippedWrapping(raw).contains("```"))
    }
}

final class RationaleTokenBudgetTests: XCTestCase {
    func testRationaleAddsHeadroomOnTop() {
        let input = "short message"
        for role in [ModelRole.enhance, .grammar] {
            let without = ProviderTuning.maxTokens(for: role, input: input)
            let with = ProviderTuning.maxTokens(for: role, input: input, expectsRationale: true)
            XCTAssertEqual(with, without + ProviderTuning.rationaleHeadroom, "failed for \(role)")
        }
    }

    func testShortGrammarInputClearsTheOldFloor() {
        // The regression this guards: a 30-character message plus an explanation
        // used to be capped at grammar's 500-token floor and truncated.
        let tokens = ProviderTuning.maxTokens(for: .grammar, input: "helo wrold", expectsRationale: true)
        XCTAssertGreaterThan(tokens, 500)
    }

    func testDefaultIsUnchangedFromBeforeTheFeature() {
        XCTAssertEqual(ProviderTuning.maxTokens(for: .grammar, input: "hi"), 500)
        XCTAssertEqual(ProviderTuning.maxTokens(for: .enhance, input: "hi"), 1500)
    }

    func testCeilingStillAppliesToTheBaseBudget() {
        let huge = String(repeating: "word ", count: 4000)
        XCTAssertEqual(ProviderTuning.maxTokens(for: .enhance, input: huge), 4000)
        XCTAssertEqual(
            ProviderTuning.maxTokens(for: .enhance, input: huge, expectsRationale: true),
            4000 + ProviderTuning.rationaleHeadroom
        )
    }
}

/// The explanation request must never reach the Grammar prompt.
///
/// Measured against qwen3:8b with the real prompts: appending it makes the model
/// return the input unchanged and describe corrections it did not make. Correction
/// is precision work; the diff is Grammar's teaching signal instead.
final class RationaleScopeTests: XCTestCase {
    func testComposeWithRationaleIsANoOpWhenDisabled() {
        XCTAssertEqual(
            Prompts.composeWithRationale(Prompts.grammar, enabled: false),
            Prompts.grammar
        )
    }

    func testComposeWithRationaleAppendsWhenEnabled() {
        let composed = Prompts.composeWithRationale(Prompts.enhance, enabled: true)
        XCTAssertTrue(composed.hasPrefix(Prompts.enhance))
        XCTAssertTrue(composed.contains(Prompts.rationaleOpenTag))
    }

    func testTheGrammarPromptItselfNeverMentionsTheTags() {
        // If this ever fails, the correction task and the explanation task have
        // been merged again and Grammar will start echoing its input.
        XCTAssertFalse(Prompts.grammar.contains(Prompts.rationaleOpenTag))
        XCTAssertFalse(Prompts.grammar.contains("<why"))
    }

    func testRationaleFragmentIsSeparableFromAnyBasePrompt() {
        // The engine composes base + fragment; nothing else may look like the
        // fragment's opening line, or history replay cannot split them apart.
        for base in [Prompts.grammar, Prompts.enhance] {
            let composed = Prompts.composeWithRationale(base, enabled: true)
            let occurrences = composed.components(separatedBy: "After the output, append a section").count - 1
            XCTAssertEqual(occurrences, 1)
        }
    }
}
