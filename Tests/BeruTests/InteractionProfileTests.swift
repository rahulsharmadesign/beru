import XCTest
@testable import Beru

final class InteractionProfileTests: XCTestCase {
    func testEmptyProfileLeavesThePromptUnchanged() {
        let system = "BASE"
        XCTAssertEqual(
            Prompts.composeWithInteractionProfile(system, profile: InteractionProfile(), actionID: EnhancementAction.replyID),
            system
        )
        XCTAssertEqual(
            Prompts.composeWithInteractionProfile(system, profile: InteractionProfile(), actionID: EnhancementAction.enhanceID),
            system
        )
    }

    func testReplyBlockNamesTheAcceptedTone() {
        var profile = InteractionProfile()
        profile.recordAccepted(
            actionID: EnhancementAction.replyID,
            replyTone: .witty,
            grammarKind: nil,
            targetName: nil,
            instruction: nil
        )
        let composed = Prompts.composeWithInteractionProfile(
            "BASE",
            profile: profile,
            actionID: EnhancementAction.replyID
        )
        XCTAssertTrue(composed.contains("LEARNED PREFERENCES"))
        XCTAssertTrue(composed.contains("Witty"))
        XCTAssertTrue(composed.contains("Funny"))
    }

    func testEnhanceBlockIsAPriorNotAnOverride() {
        var profile = InteractionProfile()
        profile.recordAccepted(
            actionID: EnhancementAction.enhanceID,
            replyTone: nil,
            grammarKind: nil,
            targetName: "Cursor",
            instruction: "make it shorter"
        )
        let composed = Prompts.composeWithInteractionProfile(
            "BASE",
            profile: profile,
            actionID: EnhancementAction.enhanceID
        )
        XCTAssertTrue(composed.contains("Cursor"))
        XCTAssertTrue(composed.contains("not an override"))
        XCTAssertTrue(composed.contains("make it shorter"))
    }

    func testGrammarPromptNeverReceivesTheProfile() {
        var profile = InteractionProfile()
        profile.recordAccepted(
            actionID: EnhancementAction.replyID,
            replyTone: .funny,
            grammarKind: .tighter,
            targetName: "Cursor",
            instruction: "shorter"
        )
        XCTAssertEqual(
            Prompts.composeWithInteractionProfile(
                "GRAMMAR",
                profile: profile,
                actionID: EnhancementAction.grammarID
            ),
            "GRAMMAR"
        )
        XCTAssertFalse(
            Prompts.composeWithInteractionProfile(
                "GRAMMAR",
                profile: profile,
                actionID: EnhancementAction.grammarID
            ).contains("Funny")
        )
    }

    func testDismissDoesNotRecord() {
        var profile = InteractionProfile()
        profile.recordAccepted(
            actionID: EnhancementAction.replyID,
            replyTone: nil,
            grammarKind: nil,
            targetName: nil,
            instruction: nil
        )
        XCTAssertTrue(profile.isEmpty)
    }

    @MainActor
    func testSettingsPersistsAndClearsTheProfile() {
        let suite = "beru.tests.interaction.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = SettingsStore(defaults: defaults)
        store.recordAcceptedInteraction(
            actionID: EnhancementAction.replyID,
            replyTone: .witty,
            grammarKind: nil,
            targetName: nil,
            instruction: nil
        )
        XCTAssertFalse(store.interactionProfile.isEmpty)
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.interactionProfile.lastReplyTone, ReplyTone.witty.rawValue)
        reloaded.clearInteractionProfile()
        XCTAssertTrue(reloaded.interactionProfile.isEmpty)
        defaults.removePersistentDomain(forName: suite)
    }
}
