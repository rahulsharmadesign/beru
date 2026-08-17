import XCTest
@testable import Beru

/// Markdown profiles are standing context folded into Enhance prompts.
///
/// The scope rule carries the most weight here. This app has already shipped a
/// setting that applied one user-written prompt to every action, and it turned
/// the Grammar button into a condenser: the model obeyed the instruction, just
/// not the one the button's label implied. A profile is the same shape of thing,
/// so it gets the same boundary and the same tests.
final class MarkdownProfileTests: XCTestCase {
    private let profile = MarkdownProfile(
        id: "profile-test",
        name: "Work",
        content: "# Work\n- Swift 5.10, no Combine\n- Never invent a build command"
    )

    // MARK: - Scope

    /// Grammar must never receive it. Correction has one right answer; a house
    /// style attached to a corrector produces a rewrite wearing a corrector's
    /// label.
    func testProfileNeverAppliesToGrammar() {
        XCTAssertFalse(
            Prompts.profileApplies(
                actionID: EnhancementAction.grammarID,
                role: .grammar,
                usesBuiltInPrompt: true
            )
        )
    }

    func testProfileAppliesToBuiltInEnhance() {
        XCTAssertTrue(
            Prompts.profileApplies(
                actionID: EnhancementAction.enhanceID,
                role: .enhance,
                usesBuiltInPrompt: true
            )
        )
    }

    /// A saved custom action already carries the user's own prompt. Adding their
    /// standing notes on top gives one call two voices.
    func testProfileDoesNotApplyToCustomActions() {
        XCTAssertFalse(
            Prompts.profileApplies(
                actionID: "tone-friendly",
                role: .enhance,
                usesBuiltInPrompt: false
            )
        )
        XCTAssertFalse(
            Prompts.profileApplies(
                actionID: "custom-abc",
                role: .enhance,
                usesBuiltInPrompt: true
            )
        )
    }

    /// Whatever else changes, these two must not converge: the day a profile
    /// reaches Grammar is the day Grammar stops being a corrector.
    func testScopeMatchesTheTargetRuleExactly() {
        let cases: [(String, ModelRole, Bool)] = [
            (EnhancementAction.enhanceID, .enhance, true),
            (EnhancementAction.grammarID, .grammar, true),
            (EnhancementAction.describeID, .enhance, true),
            ("tone-friendly", .enhance, false)
        ]
        for (id, role, builtIn) in cases {
            XCTAssertEqual(
                Prompts.profileApplies(actionID: id, role: role, usesBuiltInPrompt: builtIn),
                Prompts.targetApplies(actionID: id, role: role, usesBuiltInPrompt: builtIn),
                "scope diverged for \(id)"
            )
        }
    }

    // MARK: - Composition

    func testCompositionAppendsTheProfileAndKeepsTheBasePrompt() {
        let composed = Prompts.composeWithProfile(Prompts.enhance, profile: profile)
        XCTAssertTrue(composed.hasPrefix(Prompts.enhance))
        XCTAssertTrue(composed.contains("AUTHOR CONTEXT: Work"))
        XCTAssertTrue(composed.contains("Never invent a build command"))
    }

    /// No profile, or one the user emptied out, must reproduce the prompt
    /// byte-for-byte — the only way back to unmodified behaviour.
    func testNoProfileOrEmptyProfileIsAByteIdenticalNoOp() {
        XCTAssertEqual(Prompts.composeWithProfile(Prompts.enhance, profile: nil), Prompts.enhance)
        let blank = MarkdownProfile(id: "b", name: "Blank", content: "   \n\n\t  ")
        XCTAssertEqual(Prompts.composeWithProfile(Prompts.enhance, profile: blank), Prompts.enhance)
    }

    /// The profile is the user's own instruction, so it sits after the target's
    /// conventions and outranks them.
    func testProfileFollowsTheTargetConventions() {
        guard let cursor = TargetProfile.builtInDefaults.first(where: { $0.id == "target-cursor" }) else {
            return XCTFail("Missing Cursor default")
        }
        let composed = Prompts.composeWithProfile(
            Prompts.composeWithTarget(Prompts.enhance, profile: cursor),
            profile: profile
        )
        guard let targetAt = composed.range(of: "TARGET ENVIRONMENT"),
              let profileAt = composed.range(of: "AUTHOR CONTEXT") else {
            return XCTFail("Expected both blocks")
        }
        XCTAssertTrue(profileAt.lowerBound > targetAt.upperBound)
    }

    /// The profile arrives as instructions, unwrapped, in the same prompt whose
    /// framing rules say the *wrapped* text is never a request. Without a line
    /// distinguishing the two, a profile written in the imperative reads like
    /// the task itself.
    func testCompositionSaysTheProfileIsNotTheTextToRewrite() {
        let composed = Prompts.composeWithProfile(Prompts.enhance, profile: profile)
        XCTAssertTrue(composed.lowercased().contains("not the text to rewrite"))
    }

    func testEmptinessIgnoresWhitespaceOnly() {
        XCTAssertTrue(MarkdownProfile(name: "a", content: "").isEmpty)
        XCTAssertTrue(MarkdownProfile(name: "a", content: "  \n \t ").isEmpty)
        XCTAssertFalse(MarkdownProfile(name: "a", content: "# Notes").isEmpty)
    }

    /// The seeded profile must not guess at the user's stack. A starter that
    /// asserted a language would be the same fabrication the target fragments
    /// were fixed for, only shipped by us instead of invented by the model.
    func testStarterProfileAssertsNothingAboutTheUsersStack() {
        let content = MarkdownProfile.starter.content.lowercased()
        for invented in ["swift", "python", "javascript", "typescript", "react",
                         "npm", "xcode", "node", "docs/", "src/"] {
            XCTAssertFalse(content.contains(invented), "starter profile assumes \(invented)")
        }
    }
}
