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

/// Grammar row votes teach the row's kind even when another row is selected;
/// the footer (nil kind) keeps voting the selection.
@MainActor
final class GrammarRowVoteTests: XCTestCase {
    private var settings: SettingsStore { SettingsStore.shared }

    /// The vote path writes the shared profile and the usage log — both
    /// restored afterwards so one test cannot bias another run.
    private func isolated(_ run: () -> Void) {
        let savedProfile = settings.interactionProfile
        let savedLogging = settings.usageLoggingEnabled
        settings.usageLoggingEnabled = false
        settings.interactionProfile = InteractionProfile()
        run()
        settings.interactionProfile = savedProfile
        settings.usageLoggingEnabled = savedLogging
    }

    func testRowLikeTeachesRowKindNotSelection() {
        isolated {
            let state = AppState()
            state.selectedGrammarKind = .corrected
            let engine = PanelEngine(appState: state, onDismiss: {})
            engine.recordResultVote(
                actionID: EnhancementAction.grammarID,
                liked: true,
                text: "tight body",
                grammarKind: .tighter
            )
            XCTAssertEqual(settings.interactionProfile.lastGrammarKind, GrammarKind.tighter.rawValue)
        }
    }

    func testRowDislikeClearsOnlyTheRowKindMatch() {
        isolated {
            var stored = settings.interactionProfile
            stored.lastGrammarKind = GrammarKind.tighter.rawValue
            settings.interactionProfile = stored
            let state = AppState()
            state.selectedGrammarKind = .corrected
            let engine = PanelEngine(appState: state, onDismiss: {})
            engine.recordResultVote(
                actionID: EnhancementAction.grammarID,
                liked: false,
                text: "clear body",
                grammarKind: .clearer
            )
            XCTAssertEqual(
                settings.interactionProfile.lastGrammarKind,
                GrammarKind.tighter.rawValue,
                "disliking Clearer must not clear the stored Tighter preference"
            )
            engine.recordResultVote(
                actionID: EnhancementAction.grammarID,
                liked: false,
                text: "tight body",
                grammarKind: .tighter
            )
            XCTAssertNil(settings.interactionProfile.lastGrammarKind)
        }
    }

    func testNilKindVotesTheSelectionAsBefore() {
        isolated {
            let state = AppState()
            state.selectedGrammarKind = .clearer
            let engine = PanelEngine(appState: state, onDismiss: {})
            engine.recordResultVote(actionID: EnhancementAction.grammarID, liked: true, text: "clear body")
            XCTAssertEqual(settings.interactionProfile.lastGrammarKind, GrammarKind.clearer.rawValue)
        }
    }

    func testGrammarVoteClearsOnResetAndDismiss() {
        let resetState = AppState()
        resetState.grammarVote[.tighter] = true
        resetState.reset(withCapturedText: "")
        XCTAssertTrue(resetState.grammarVote.isEmpty)

        let dismissedState = AppState()
        dismissedState.grammarVote[.clearer] = false
        dismissedState.dismiss()
        XCTAssertTrue(dismissedState.grammarVote.isEmpty)
    }
}

/// Reply row votes teach the row's tone even when another is selected;
/// the footer (nil tone) keeps voting the selection.
@MainActor
final class ReplyRowVoteTests: XCTestCase {
    private var settings: SettingsStore { SettingsStore.shared }

    private func isolated(_ run: () -> Void) {
        let savedProfile = settings.interactionProfile
        let savedLogging = settings.usageLoggingEnabled
        settings.usageLoggingEnabled = false
        settings.interactionProfile = InteractionProfile()
        run()
        settings.interactionProfile = savedProfile
        settings.usageLoggingEnabled = savedLogging
    }

    func testRowLikeTeachesRowToneNotSelection() {
        isolated {
            let state = AppState()
            state.selectedReplyTone = .formal
            let engine = PanelEngine(appState: state, onDismiss: {})
            engine.recordResultVote(
                actionID: EnhancementAction.replyID,
                liked: true,
                text: "funny body",
                replyTone: .funny
            )
            XCTAssertEqual(settings.interactionProfile.lastReplyTone, ReplyTone.funny.rawValue)
        }
    }

    func testRowDislikeClearsOnlyTheRowToneMatch() {
        isolated {
            var stored = settings.interactionProfile
            stored.lastReplyTone = ReplyTone.funny.rawValue
            settings.interactionProfile = stored
            let state = AppState()
            state.selectedReplyTone = .formal
            let engine = PanelEngine(appState: state, onDismiss: {})
            engine.recordResultVote(
                actionID: EnhancementAction.replyID,
                liked: false,
                text: "casual body",
                replyTone: .casual
            )
            XCTAssertEqual(settings.interactionProfile.lastReplyTone, ReplyTone.funny.rawValue)
            engine.recordResultVote(
                actionID: EnhancementAction.replyID,
                liked: false,
                text: "funny body",
                replyTone: .funny
            )
            XCTAssertNil(settings.interactionProfile.lastReplyTone)
        }
    }

    func testReplyVoteAndPinFlashClearOnResetAndDismiss() {
        let resetState = AppState()
        resetState.replyVote[.witty] = true
        resetState.pinnedRow = ReplyTone.witty.rawValue
        resetState.reset(withCapturedText: "")
        XCTAssertTrue(resetState.replyVote.isEmpty)
        XCTAssertNil(resetState.pinnedRow)

        let dismissedState = AppState()
        dismissedState.replyVote[.sharp] = false
        dismissedState.pinnedRow = "some-turn-id"
        dismissedState.dismiss()
        XCTAssertTrue(dismissedState.replyVote.isEmpty)
        XCTAssertNil(dismissedState.pinnedRow)
    }
}
