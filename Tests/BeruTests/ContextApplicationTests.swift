import XCTest
@testable import Beru

final class ContextApplicationTests: XCTestCase {
    func testEmptyContextIsByteIdenticalNoOp() {
        XCTAssertEqual(Prompts.composeWithContext(Prompts.enhance, context: .empty), Prompts.enhance)
    }

    func testApplicationAssemblesWorkspacePlaybookRulesAndGlossary() {
        let workspace = ContextWorkspace(id: "workspace", name: "Acme", memory: "The customer uses the Pro plan.")
        let playbook = ContextPlaybook(id: "playbook", name: "Support", instructions: "Be direct and kind.")
        let rule = ContextRule(id: "rule", name: "No invention", instruction: "Do not invent refunds.")
        let term = GlossaryTerm(id: "term", preferred: "Beru", aliases: "beru app", note: "Always capitalize")
        let application = ContextApplication(workspace: workspace, playbook: playbook, rules: [rule], glossary: [term])
        let block = application.instructionBlock
        XCTAssertTrue(block.contains("WORKSPACE (Acme)"))
        XCTAssertTrue(block.contains("PLAYBOOK (Support)"))
        XCTAssertTrue(block.contains("Do not invent refunds."))
        XCTAssertTrue(block.contains("Prefer 'Beru'"))
    }

    func testRulesRespectScopeEnablementAndContent() {
        XCTAssertTrue(ContextRule(name: "global", instruction: "x").applies(actionID: "enhance", targetID: "generic"))
        XCTAssertTrue(ContextRule(name: "action", instruction: "x", scope: .action, actionID: "enhance").applies(actionID: "enhance", targetID: "generic"))
        XCTAssertFalse(ContextRule(name: "action", instruction: "x", scope: .action, actionID: "reply").applies(actionID: "enhance", targetID: "generic"))
        XCTAssertFalse(ContextRule(name: "disabled", instruction: "x", enabled: false).applies(actionID: "enhance", targetID: "generic"))
        XCTAssertFalse(ContextRule(name: "blank", instruction: "   ").applies(actionID: "enhance", targetID: "generic"))
    }

    func testContextFollowsTargetAndPrecedesAuthorProfile() {
        let context = ContextApplication(workspace: nil, playbook: ContextPlaybook(id: "p", name: "P", instructions: "Context instruction"), rules: [], glossary: [])
        let profile = MarkdownProfile(id: "author", name: "Author", content: "Author instruction")
        let composed = Prompts.composeWithProfile(Prompts.composeWithContext(Prompts.enhance, context: context), profile: profile)
        XCTAssertLessThan(composed.range(of: "PLAYBOOK (P)")!.lowerBound, composed.range(of: "AUTHOR CONTEXT")!.lowerBound)
    }
}
