import XCTest
@testable import Beru

/// `Sources/App/` had no tests, which is one of the two places the regressions
/// this refactor was prompted by actually landed. `reset` and `dismiss` clear
/// roughly twenty properties each and are the easiest thing in the app to
/// extend and forget: every new piece of per-invocation state has to be added
/// to both, and a miss leaks the previous invocation's content into the next.
@MainActor
final class AppStateTests: XCTestCase {

    /// Fills every per-invocation property so a clear that misses one is visible.
    private func populated() -> AppState {
        let state = AppState()
        state.capturedText = "captured"
        state.capturedElement = nil
        state.hostBundleID = "com.apple.mail"
        state.hostAppName = "Mail"
        state.clipboardText = "clipboard"
        state.includeClipboard = true
        state.describeInstruction = "make it shorter"
        state.truncationNotice = true
        state.vaultNoteID = "note-1"
        state.isQuickSearch = true
        state.copiedFeedback = true
        state.pinnedFeedback = true
        state.replacedFeedback = "Replaced in Mail"
        state.setResult(.done("result"), for: EnhancementAction.enhanceID)
        state.savings[EnhancementAction.enhanceID] = TokenSavings(input: "aaa", output: "b")
        state.diffs[EnhancementAction.enhanceID] = [.equal("x")]
        state.rationales[EnhancementAction.enhanceID] = "because"
        state.heavyRewriteNotices.insert(EnhancementAction.enhanceID)
        state.restyledNotices.insert(EnhancementAction.enhanceID)
        state.cleanNotices.insert(EnhancementAction.enhanceID)
        state.errorProviders[EnhancementAction.enhanceID] = .ollama
        state.errorNeedsModelSetup.insert(EnhancementAction.enhanceID)
        return state
    }

    private func assertContentCleared(_ state: AppState, _ message: String = "") {
        XCTAssertTrue(state.results.isEmpty, "results \(message)")
        XCTAssertTrue(state.savings.isEmpty, "savings \(message)")
        XCTAssertTrue(state.diffs.isEmpty, "diffs \(message)")
        XCTAssertTrue(state.rationales.isEmpty, "rationales \(message)")
        XCTAssertTrue(state.contextApplications.isEmpty, "contextApplications \(message)")
        XCTAssertTrue(state.heavyRewriteNotices.isEmpty, "heavyRewriteNotices \(message)")
        XCTAssertTrue(state.restyledNotices.isEmpty, "restyledNotices \(message)")
        XCTAssertTrue(state.cleanNotices.isEmpty, "cleanNotices \(message)")
        XCTAssertTrue(state.errorProviders.isEmpty, "errorProviders \(message)")
        XCTAssertTrue(state.errorNeedsModelSetup.isEmpty, "errorNeedsModelSetup \(message)")
        XCTAssertNil(state.clipboardText, "clipboardText \(message)")
        XCTAssertFalse(state.includeClipboard, "includeClipboard \(message)")
        XCTAssertEqual(state.describeInstruction, "", "describeInstruction \(message)")
        XCTAssertFalse(state.truncationNotice, "truncationNotice \(message)")
        XCTAssertNil(state.vaultNoteID, "vaultNoteID \(message)")
        XCTAssertNil(state.capturedElement, "capturedElement \(message)")
    }

    func testResetClearsEveryPieceOfPreviousInvocationContent() {
        let state = populated()
        state.reset(withCapturedText: "fresh capture")
        assertContentCleared(state, "must not survive reset")
        XCTAssertEqual(state.capturedText, "fresh capture")
        XCTAssertNil(state.hostBundleID)
        XCTAssertNil(state.hostAppName)
        XCTAssertFalse(state.isQuickSearch)
        XCTAssertFalse(state.copiedFeedback)
        XCTAssertFalse(state.pinnedFeedback)
        XCTAssertNil(state.replacedFeedback)
    }

    func testDismissClearsContentWithoutRebuildingTheView() {
        let state = populated()
        let sessionBefore = state.panelSessionID
        state.dismiss()
        assertContentCleared(state, "must not survive dismiss")
        XCTAssertEqual(state.capturedText, "")
        XCTAssertFalse(state.isPanelVisible)
        // Regenerating the session id mid fade-out would rebuild the hierarchy
        // while it is animating out.
        XCTAssertEqual(state.panelSessionID, sessionBefore, "dismiss must not change panelSessionID")
        XCTAssertNil(state.replacedFeedback)
    }

    func testResetIssuesNewSessionAndInvocationIdentity() {
        let state = AppState()
        let session = state.panelSessionID
        let invocation = state.invocationID
        state.reset(withCapturedText: "text")
        XCTAssertNotEqual(state.panelSessionID, session)
        XCTAssertNotEqual(state.invocationID, invocation)
    }

    func testResetCancelsInFlightStreams() {
        let state = AppState()
        let task = Task { try? await Task.sleep(for: .seconds(60)); return }
        state.registerStreamTask(task, for: EnhancementAction.enhanceID)
        state.reset(withCapturedText: "text")
        XCTAssertTrue(task.isCancelled)
    }

    func testRegisteringASecondTaskCancelsTheFirstForThatAction() {
        let state = AppState()
        let first = Task { try? await Task.sleep(for: .seconds(60)); return }
        state.registerStreamTask(first, for: EnhancementAction.enhanceID)
        state.registerStreamTask(Task {}, for: EnhancementAction.enhanceID)
        XCTAssertTrue(first.isCancelled)
    }

    func testResultStateDefaultsToIdleAndHasStartedTracksIt() {
        let state = AppState()
        XCTAssertEqual(state.resultState(for: EnhancementAction.enhanceID), .idle)
        XCTAssertFalse(state.hasStarted(EnhancementAction.enhanceID))
        state.setResult(.loading, for: EnhancementAction.enhanceID)
        XCTAssertTrue(state.hasStarted(EnhancementAction.enhanceID))
    }

    func testSelectingQuickSearchSetsTheFlagAndOtherActionsClearIt() {
        let state = AppState()
        state.selectAction(EnhancementAction.searchID)
        XCTAssertTrue(state.isQuickSearch)
        state.selectAction(EnhancementAction.enhanceID)
        XCTAssertFalse(state.isQuickSearch)
    }
}

final class OutcomeCopyTests: XCTestCase {
    func testReplaceNamesTheHost() {
        XCTAssertEqual(
            OutcomeCopy.replaceToast(hostAppName: "Cursor", isVault: false, isInsert: false),
            "Replaced in Cursor"
        )
    }

    func testInsertUsesInserted() {
        XCTAssertEqual(
            OutcomeCopy.replaceToast(hostAppName: "Mail", isVault: false, isInsert: true),
            "Inserted in Mail"
        )
    }

    func testVaultApplyDoesNotUseTheHost() {
        XCTAssertEqual(
            OutcomeCopy.replaceToast(hostAppName: "Cursor", isVault: true, isInsert: false),
            "Applied to note"
        )
    }

    func testMissingHostFallsBackToMac() {
        XCTAssertEqual(
            OutcomeCopy.replaceToast(hostAppName: nil, isVault: false, isInsert: false),
            "Replaced in Mac"
        )
        XCTAssertEqual(
            OutcomeCopy.replaceToast(hostAppName: "  ", isVault: false, isInsert: false),
            "Replaced in Mac"
        )
    }
}

@MainActor
final class VaultApplyTrailTests: XCTestCase {
    func testCompleteReplaceRevealsTheVaultNoteAfterDismiss() async {
        let state = AppState()
        state.vaultNoteID = "note-xyz"
        var dismissed = false
        var revealed: String?
        let engine = PanelEngine(appState: state) { dismissed = true }
        engine.onRevealVaultNote = { revealed = $0 }
        engine.replace(text: "applied body")
        engine.replaceToastTask?.cancel()
        await engine.completeReplace()
        XCTAssertTrue(dismissed)
        XCTAssertEqual(revealed, "note-xyz")
        XCTAssertNil(engine.pendingReplaceVaultNoteID)
    }

    func testHostReplaceDoesNotStashAVaultNoteID() {
        let state = AppState()
        state.vaultNoteID = nil
        let engine = PanelEngine(appState: state) {}
        engine.replace(text: "host body")
        XCTAssertNil(engine.pendingReplaceVaultNoteID)
        XCTAssertFalse(engine.pendingReplaceIsVault)
        engine.resetForNewInvocation()
    }
}
