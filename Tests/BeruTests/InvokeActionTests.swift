import XCTest
@testable import Beru

@MainActor
final class InvokeActionTests: XCTestCase {
    private let chrome = HostApp.Info(bundleID: "com.google.Chrome", name: "Google Chrome")
    private let cursor = HostApp.Info(bundleID: "com.anysphere.cursor", name: "Cursor")
    private let slack = HostApp.Info(bundleID: "com.tinyspeck.slackmacgap", name: "Slack")
    private let mail = HostApp.Info(bundleID: "com.apple.mail", name: "Mail")

    func testHotkeyWithoutCaptureOpensAISearchEverywhere() {
        for host in [nil, chrome, cursor, slack] {
            XCTAssertEqual(
                AppCoordinator.initialActionID(
                    openOnSearch: false, needsSetup: false, host: host,
                    hasCapture: false, source: "hotkey"
                ),
                EnhancementAction.searchID,
                host?.name ?? "no host"
            )
        }
    }

    func testUnconfiguredInstallStaysOnAISearch() {
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: true, host: cursor,
                hasCapture: true, isEditableField: true, source: "hotkey"
            ),
            EnhancementAction.searchID
        )
    }

    func testDictateOrMenuInvokeOpensAISearch() {
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: true, needsSetup: false, host: chrome,
                hasCapture: true, source: "hotkey"
            ),
            EnhancementAction.searchID
        )
    }

    func testSelectionInLLMToolOpensEnhancePrompt() {
        let hosts = [
            HostApp.Info(bundleID: "com.anysphere.cursor", name: "Cursor"),
            HostApp.Info(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
            HostApp.Info(bundleID: "com.anthropic.claudefordesktop", name: "Claude"),
            HostApp.Info(bundleID: "com.openai.chat", name: "ChatGPT"),
            HostApp.Info(bundleID: "cn.moonshot.kimi", name: "Kimi")
        ]
        for host in hosts {
            // With and without a readable editable-field role: Electron's AX
            // tree is thin, so the role read must not be required.
            for isEditable in [true, false] {
                XCTAssertEqual(
                    AppCoordinator.initialActionID(
                        openOnSearch: false, needsSetup: false, host: host,
                        hasCapture: true, isEditableField: isEditable,
                        capturedText: "write a parser", source: "hotkey"
                    ),
                    EnhancementAction.enhanceID,
                    "\(host.name ?? host.bundleID) editable=\(isEditable)"
                )
            }
        }
    }

    func testSelectionInAnyOtherEditableFieldOpensGrammar() {
        for host in [chrome, .init(bundleID: "com.apple.Notes", name: "Notes")] {
            XCTAssertEqual(
                AppCoordinator.initialActionID(
                    openOnSearch: false, needsSetup: false, host: host,
                    hasCapture: true, isEditableField: true, capturedText: "some draft text",
                    source: "hotkey"
                ),
                EnhancementAction.grammarID,
                host.name ?? host.bundleID
            )
        }
    }

    /// A draft you are writing is correction material even inside a chat or
    /// mail app — the editable-field check must win over the chat-app rule.
    func testOwnDraftInChatAndMailAppsOpensGrammar() {
        for host in [slack, mail] {
            XCTAssertEqual(
                AppCoordinator.initialActionID(
                    openOnSearch: false, needsSetup: false, host: host,
                    hasCapture: true, isEditableField: true, capturedText: "my half-written draft",
                    source: "hotkey"
                ),
                EnhancementAction.grammarID,
                host.name ?? host.bundleID
            )
        }
    }

    /// A received message selected in a chat or mail app is reply material.
    func testReceivedMessageSelectionInChatAndMailAppsOpensSmartReply() {
        for host in [slack, mail] {
            XCTAssertEqual(
                AppCoordinator.initialActionID(
                    openOnSearch: false, needsSetup: false, host: host,
                    hasCapture: true, capturedText: "Long received message",
                    source: "hotkey"
                ),
                EnhancementAction.replyID,
                host.name ?? host.bundleID
            )
        }
    }

    /// Web selections land on Enhance Prompt whatever their length. Only an
    /// Instagram / YouTube / X context routes to Smart Reply.
    func testGenericWebSelectionAlwaysOpensEnhancePrompt() {
        let comment = String(repeating: "Is this still available? ", count: 5)
        XCTAssertTrue(comment.count <= 280)
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: false, host: chrome,
                hasCapture: true, capturedText: comment, source: "hotkey"
            ),
            EnhancementAction.enhanceID
        )
        let article = String(repeating: "word ", count: 80)
        XCTAssertGreaterThan(article.count, 280)
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: false, host: chrome,
                hasCapture: true, capturedText: article, source: "hotkey"
            ),
            EnhancementAction.enhanceID
        )
    }

    func testSocialFeedSelectionOpensSmartReply() {
        // In the browser, only the window title gives the feed away.
        let titles = [
            "(1) Home / X",
            "Elon Musk (@elonmusk) / X",
            "My Video - YouTube",
            "Instagram",
            "Priya Sharma on Instagram: \"sunset vibes\""
        ]
        for title in titles {
            XCTAssertEqual(
                AppCoordinator.initialActionID(
                    openOnSearch: false, needsSetup: false, host: chrome,
                    hasCapture: true, capturedText: "a long comment worth answering",
                    source: "hotkey", windowTitle: title
                ),
                EnhancementAction.replyID,
                title
            )
        }
        // And inside the native apps themselves.
        let hosts = [
            HostApp.Info(bundleID: "com.burbn.instagram", name: "Instagram"),
            HostApp.Info(bundleID: "com.google.YouTube", name: "YouTube")
        ]
        for host in hosts {
            XCTAssertEqual(
                AppCoordinator.initialActionID(
                    openOnSearch: false, needsSetup: false, host: host,
                    hasCapture: true, capturedText: "any comment", source: "hotkey"
                ),
                EnhancementAction.replyID,
                host.name ?? host.bundleID
            )
        }
        // A draft composed there still gets corrected, not answered.
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: false, host: hosts[0],
                hasCapture: true, isEditableField: true, capturedText: "my comment draft",
                source: "hotkey"
            ),
            EnhancementAction.grammarID
        )
        // An unrelated page whose content mentions YouTube stays on Summarize.
        XCTAssertFalse(
            AppCoordinator.isSocialFeedSelection(bundleID: "com.apple.Notes", windowTitle: nil)
        )
    }

    func testClipboardAndVaultSourcesStayOnAISearch() {
        for source in ["clipboard", "vault"] {
            XCTAssertEqual(
                AppCoordinator.initialActionID(
                    openOnSearch: false, needsSetup: false, host: nil,
                    hasCapture: true, capturedText: "pasted text", source: source
                ),
                EnhancementAction.searchID,
                source
            )
        }
    }

    /// A hotkey invoke whose selection needed the Cmd-C fallback leaves no
    /// pinned element and arrives with a nil source; it must still route as a
    /// hotkey, not as a clipboard paste. A generic page routes to Summarize.
    func testNilSourceRoutesLikeHotkeyNotClipboard() {
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: false, host: chrome,
                hasCapture: true, capturedText: "Is this still available?", source: nil
            ),
            EnhancementAction.enhanceID
        )
    }

    func testCommunicationPrefixMatchingStaysConservative() {
        XCTAssertTrue(AppCoordinator.isCommunicationApp("com.tinyspeck.slackmacgap"))
        // "chat" must not catch ChatGPT.
        XCTAssertFalse(AppCoordinator.isCommunicationApp("com.openai.chat"))
        XCTAssertTrue(
            AppCoordinator.isSocialFeedSelection(bundleID: "com.burbn.instagram", windowTitle: nil)
        )
        // "x" must not match every title containing the letter.
        XCTAssertFalse(
            AppCoordinator.isSocialFeedSelection(
                bundleID: "com.google.Chrome",
                windowTitle: "Fixing proxy settings - Docs"
            )
        )
        XCTAssertTrue(
            AppCoordinator.isSocialFeedSelection(bundleID: nil, windowTitle: "Home / X")
        )
        XCTAssertFalse(AppCoordinator.isSocialFeedSelection(bundleID: nil, windowTitle: nil))
    }
}

/// The outcome strip must survive a Regenerate without unmounting: tearing
/// it down shrinks the chrome, bounces the composer to the middle for a few
/// milliseconds, then regrows everything when the answer lands.
@MainActor
final class ReloadFooterTests: XCTestCase {
    private let actionID = "action-unknown-test"

    private func engine(on state: AppState) -> PanelEngine {
        PanelEngine(appState: state, onDismiss: {})
    }

    func testShowsFooterForDoneOrReloadingOnly() {
        let state = AppState()
        XCTAssertFalse(state.showsFooter(for: actionID))
        state.setResult(.loading, for: actionID)
        XCTAssertFalse(state.showsFooter(for: actionID))
        state.reloadingActions.insert(actionID)
        XCTAssertTrue(state.showsFooter(for: actionID))
        state.setResult(.done("new"), for: actionID)
        XCTAssertTrue(state.showsFooter(for: actionID))
        XCTAssertTrue(state.reloadingActions.isEmpty, "a terminal state clears the reload flag")
    }

    func testErrorAndIdleClearReloadingAndHideTheFooter() {
        for terminal: ResultState in [.error("boom"), .idle] {
            let state = AppState()
            state.reloadingActions.insert(actionID)
            state.setResult(terminal, for: actionID)
            XCTAssertTrue(state.reloadingActions.isEmpty)
            XCTAssertFalse(state.showsFooter(for: actionID))
        }
    }

    func testResetAndDismissClearReloading() {
        let resetState = AppState()
        resetState.reloadingActions.insert(actionID)
        resetState.reset(withCapturedText: "")
        XCTAssertTrue(resetState.reloadingActions.isEmpty)

        let dismissedState = AppState()
        dismissedState.reloadingActions.insert(actionID)
        dismissedState.dismiss()
        XCTAssertTrue(dismissedState.reloadingActions.isEmpty)
    }

    func testRetryWhileStreamingIsANoOp() {
        let state = AppState()
        let engine = engine(on: state)
        state.setResult(.loading, for: actionID)
        engine.retry(actionID: actionID)
        XCTAssertTrue(state.reloadingActions.isEmpty)
        XCTAssertTrue(engine.attempts.isEmpty, "no run may start under the live one")
    }

    func testRetryFromDoneMarksReloadingWithoutStartingUnknownRuns() {
        let state = AppState()
        let engine = engine(on: state)
        state.setResult(.done("old"), for: actionID)
        engine.retry(actionID: actionID)
        XCTAssertEqual(state.reloadingActions, [actionID])
        XCTAssertTrue(engine.attempts.isEmpty, "an unknown action must not start a run")
        XCTAssertTrue(state.showsFooter(for: actionID))
    }

    func testRowTabsHaveNoFooter() {
        let state = AppState()
        state.setResult(.done("old"), for: EnhancementAction.searchID)
        XCTAssertFalse(state.showsFooter(for: EnhancementAction.searchID))
        state.setResult(.done("old"), for: EnhancementAction.grammarID)
        XCTAssertFalse(
            state.showsFooter(for: EnhancementAction.grammarID),
            "rows own every outcome; the strip is gone"
        )
        state.setResult(.done("old"), for: EnhancementAction.replyID)
        XCTAssertFalse(state.showsFooter(for: EnhancementAction.replyID))
    }

    func testGrammarReplyShellMountsOnlyForRowlessInfo() {
        let state = AppState()
        state.setResult(.done("old"), for: EnhancementAction.grammarID)
        state.replacedFeedback = "Replaced in Notes"
        XCTAssertTrue(
            state.showsFooter(for: EnhancementAction.grammarID),
            "the write-back toast has no row home"
        )
        state.replacedFeedback = nil
        XCTAssertFalse(state.showsFooter(for: EnhancementAction.grammarID))
    }
}
