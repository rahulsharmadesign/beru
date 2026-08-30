import XCTest
@testable import Beru

final class ActionRegistryTests: XCTestCase {
    @MainActor
    func testEnhanceActionMapsToEnhanceRoleAndPrompt() {
        let action = ActionRegistry.shared.action(withID: EnhancementAction.enhanceID)
        XCTAssertEqual(action?.role, .enhance)
        XCTAssertEqual(action?.systemPrompt, Prompts.enhance)
    }

    @MainActor
    func testGrammarActionMapsToGrammarRoleAndPrompt() {
        let action = ActionRegistry.shared.action(withID: EnhancementAction.grammarID)
        XCTAssertEqual(action?.role, .grammar)
        XCTAssertEqual(action?.systemPrompt, Prompts.grammar)
    }

    @MainActor
    func testBuiltInsComeFirstAndGrammarIsPrimary() {
        let ordered = ActionRegistry.ordered([.grammar, .enhance], by: [])
        XCTAssertEqual(ordered.first?.id, EnhancementAction.grammarID)
        XCTAssertEqual(ordered.dropFirst().first?.id, EnhancementAction.enhanceID)
    }

    @MainActor
    func testBuiltInDisplayNamesAreGrammarAndEnhancePrompt() {
        XCTAssertEqual(EnhancementAction.grammar.name, "Grammar")
        XCTAssertEqual(EnhancementAction.enhance.name, "Enhance Prompt")
        XCTAssertEqual(ActionRegistry.shared.action(withID: EnhancementAction.grammarID)?.name, "Grammar")
        XCTAssertEqual(ActionRegistry.shared.action(withID: EnhancementAction.enhanceID)?.name, "Enhance Prompt")
    }

    @MainActor
    func testVerbSkillsAreSeeded() {
        let ids = Set(ActionRegistry.shared.allActions.map(\.id))
        XCTAssertTrue(ids.contains(EnhancementAction.replyID))
        XCTAssertTrue(ids.contains(EnhancementAction.summarizeID))
        XCTAssertTrue(ids.contains(EnhancementAction.explainID))
        XCTAssertEqual(
            EnhancementAction.starterVerbActions.first { $0.id == EnhancementAction.replyID }?.name,
            "Smart Reply"
        )
    }

    func testVerbPromptsExistAndSkipTargetFragment() {
        for action in EnhancementAction.starterVerbActions {
            let prompt = EnhancementAction.resolvedSystemPrompt(for: action)
            XCTAssertFalse(prompt.isEmpty)
            XCTAssertTrue(prompt.contains("Output ONLY"))
            XCTAssertFalse(
                Prompts.targetApplies(
                    actionID: action.id, role: action.role, usesBuiltInPrompt: action.isBuiltIn
                )
            )
        }
        // Each verb must state a distinct job so models don't collapse them.
        XCTAssertTrue(Prompts.reply.contains("reply"))
        XCTAssertTrue(Prompts.summarize.localizedCaseInsensitiveContains("summar"))
        XCTAssertTrue(Prompts.explain.localizedCaseInsensitiveContains("explain"))
        XCTAssertTrue(Prompts.enhance.contains("prompt"))
    }

    func testUserMessageKeepsClipboardOutsideTextMarkers() {
        let message = Prompts.userMessage(capturedText: "selection body", clipboardText: "pasteboard body")
        XCTAssertTrue(message.contains("\(Prompts.textOpenTag)\nselection body\n\(Prompts.textCloseTag)"))
        XCTAssertTrue(message.contains("\(Prompts.clipboardOpenTag)\npasteboard body\n\(Prompts.clipboardCloseTag)"))
        let textRange = message.range(of: "\(Prompts.textOpenTag)\nselection body\n\(Prompts.textCloseTag)")!
        let clipRange = message.range(of: Prompts.clipboardOpenTag)!
        XCTAssertLessThan(textRange.upperBound, clipRange.lowerBound)
        XCTAssertFalse(message[textRange].contains("pasteboard body"))
    }

    func testUserMessageOmitsClipboardWhenNil() {
        let message = Prompts.userMessage(capturedText: "only selection")
        XCTAssertFalse(message.contains(Prompts.clipboardOpenTag))
    }

    @MainActor
    func testOrderedHonorsSavedChipOrderAndKeepsUnknownsAtEnd() {
        let grammar = EnhancementAction.grammar
        let enhance = EnhancementAction.enhance
        let reply = EnhancementAction.starterVerbActions[0]
        let ordered = ActionRegistry.ordered(
            [grammar, enhance, reply],
            by: [reply.id, grammar.id]
        )
        XCTAssertEqual(ordered.map(\.id), [reply.id, grammar.id, enhance.id])
    }

    @MainActor
    func testEmptyOrderKeepsBuiltInsFirst() {
        let grammar = EnhancementAction.grammar
        let enhance = EnhancementAction.enhance
        let ordered = ActionRegistry.ordered([grammar, enhance], by: [])
        XCTAssertEqual(ordered.map(\.id), [grammar.id, enhance.id])
    }

    func testAdditionalInstructionIsAppendedNotANewAction() {
        let extra = Prompts.additionalInstruction("make it shorter")
        XCTAssertTrue(extra.contains("make it shorter"))
        XCTAssertTrue(extra.contains("Additional instruction"))
    }

    @MainActor
    func testDescribeIsNotARegistryAction() {
        // The describe chip is rendered by the view. Adding it to the registry
        // would shift the Cmd-2..9 mapping and change branch order in
        // PanelEngine.start, which resolves describe before any lookup.
        XCTAssertNil(ActionRegistry.shared.action(withID: EnhancementAction.describeID))
        XCTAssertFalse(ActionRegistry.shared.allActions.contains { $0.id == EnhancementAction.describeID })
    }

    @MainActor
    func testSearchIsNotARegistryAction() {
        XCTAssertNil(ActionRegistry.shared.action(withID: EnhancementAction.searchID))
        XCTAssertFalse(ActionRegistry.shared.allActions.contains { $0.id == EnhancementAction.searchID })
        XCTAssertEqual(EnhancementAction.search.name, "AI Search")
        XCTAssertFalse(EnhancementAction.showsInlineDiff(for: EnhancementAction.searchID))
        XCTAssertTrue(EnhancementAction.allowsEmptyCapture(EnhancementAction.searchID))
        XCTAssertFalse(EnhancementAction.allowsEmptyCapture(EnhancementAction.grammarID))
        let grammar = EnhancementAction.emptyCaptureCopy(actionID: EnhancementAction.grammarID)
        XCTAssertEqual(grammar.title, "No text selected")
        XCTAssertTrue(grammar.subtitle.contains("Highlight text"))
        XCTAssertTrue(grammar.subtitle.contains("AI Search"))
        XCTAssertFalse(grammar.subtitle.localizedCaseInsensitiveContains("ask instead"))
        let search = EnhancementAction.emptyCaptureCopy(actionID: EnhancementAction.searchID)
        XCTAssertEqual(search.title, "Ask a question")
        XCTAssertTrue(search.subtitle.contains("Type below"))

        XCTAssertEqual(
            EnhancementAction.composerPlaceholder(
                actionID: EnhancementAction.grammarID, hasCapture: false, isQuickSearch: false
            ),
            "Highlight text first"
        )
        XCTAssertEqual(
            EnhancementAction.composerPlaceholder(
                actionID: EnhancementAction.searchID, hasCapture: false, isQuickSearch: false
            ),
            "Ask anything — no selection needed"
        )
        XCTAssertEqual(
            EnhancementAction.composerPlaceholder(
                actionID: EnhancementAction.describeID, hasCapture: false, isQuickSearch: false
            ),
            "Type what you want Beru to do"
        )
        XCTAssertTrue(
            EnhancementAction.composerPlaceholder(
                actionID: EnhancementAction.grammarID, hasCapture: true, isQuickSearch: false
            ).contains("keep my tone")
        )

        XCTAssertEqual(
            EnhancementAction.resolvedName(actionID: EnhancementAction.searchID, registryName: nil),
            "AI Search"
        )
        XCTAssertEqual(
            EnhancementAction.resolvedName(actionID: EnhancementAction.enhanceID, registryName: nil),
            "Enhance Prompt"
        )
        XCTAssertEqual(
            EnhancementAction.resolvedName(actionID: "custom-1", registryName: "For my VP"),
            "For my VP"
        )
        XCTAssertEqual(
            EnhancementAction.contextSummary(actionName: "Enhance Prompt", hostAppName: "Cursor", characterCount: 0),
            "Enhance Prompt · Cursor"
        )
        XCTAssertEqual(
            EnhancementAction.contextSummary(actionName: "Grammar", hostAppName: "Cursor", characterCount: 240),
            "Grammar · Cursor · 240 characters"
        )
        XCTAssertEqual(
            EnhancementAction.contextSummary(actionName: "AI Search", hostAppName: nil, characterCount: 0),
            "AI Search · Mac"
        )
        XCTAssertFalse(
            EnhancementAction.contextSummary(actionName: "Grammar", hostAppName: "Mail", characterCount: 0)
                .contains("No text selected")
        )
    }

    @MainActor
    func testCustomActionRoundTrip() {
        let registry = ActionRegistry.shared
        let before = registry.customActions.count
        registry.addCustom(name: "Test VP Tone", icon: "person", systemPrompt: "Rewrite for a VP.")
        XCTAssertEqual(registry.customActions.count, before + 1)

        let added = registry.customActions.last
        XCTAssertEqual(added?.name, "Test VP Tone")
        XCTAssertEqual(added?.role, .enhance)
        XCTAssertFalse(added?.isBuiltIn ?? true)

        if let id = added?.id {
            registry.removeCustom(id: id)
        }
        XCTAssertEqual(registry.customActions.count, before)
    }

    func testEnhancePromptDefinesStructuredIntentPreservingOutput() {
        let prompt = Prompts.enhance
        for requirement in [
            "PRESERVE INTENT",
            "MAKE THE REQUEST ACTIONABLE",
            "QUALITY",
            "OUTPUT SHAPE",
            "Task:",
            "Context:",
            "Requirements:",
            "Constraints:",
            "Deliverable:"
        ] {
            XCTAssertTrue(prompt.contains(requirement), "Missing Enhance prompt requirement: \(requirement)")
        }
        XCTAssertTrue(prompt.contains("Do not invent requirements"))
        XCTAssertTrue(prompt.contains("Omit empty sections"))
        XCTAssertTrue(prompt.contains("Output ONLY"))
        XCTAssertTrue(prompt.contains("one short natural-language prompt"))
        XCTAssertTrue(prompt.contains("Why i am getting this error"))
    }

    func testPromptsContainOutputOnlyRule() {
        XCTAssertTrue(Prompts.enhance.contains("Output ONLY"))
        XCTAssertTrue(Prompts.grammar.contains("Output ONLY"))
        XCTAssertTrue(Prompts.reply.contains("Output ONLY"))
        XCTAssertTrue(Prompts.summarize.contains("Output ONLY"))
        XCTAssertTrue(Prompts.explain.contains("Output ONLY"))
        XCTAssertTrue(Prompts.toneRewrite(description: "friendly").contains("Output ONLY"))
        XCTAssertTrue(Prompts.describeChange(instruction: "make it shorter").contains("Output ONLY"))
    }
}
