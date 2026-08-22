import XCTest
@testable import Beru

@MainActor
final class InvokeActionTests: XCTestCase {
    func testNoToolOpensAISearch() {
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: false, host: nil,
                defaultActionID: EnhancementAction.grammarID
            ),
            EnhancementAction.searchID
        )
        let notes = HostApp.Info(bundleID: "com.apple.Notes", name: "Notes")
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: false, host: notes,
                defaultActionID: EnhancementAction.grammarID
            ),
            EnhancementAction.searchID
        )
    }

    func testIntegratedToolLandsOnGrammarNotEnhanceAlone() {
        let hosts: [HostApp.Info] = [
            .init(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor"),
            .init(bundleID: "com.openai.chat", name: "ChatGPT"),
            .init(bundleID: "com.anthropic.claudefordesktop", name: "Claude"),
            .init(bundleID: "cn.moonshot.kimi", name: "Kimi")
        ]
        for host in hosts {
            let id = AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: false, host: host,
                defaultActionID: EnhancementAction.grammarID
            )
            XCTAssertEqual(id, EnhancementAction.grammarID, host.name ?? host.bundleID)
            XCTAssertNotEqual(id, EnhancementAction.enhanceID, host.name ?? host.bundleID)
        }
        let chipIDs = ActionRegistry.shared.allActions.map(\.id)
        XCTAssertTrue(chipIDs.contains(EnhancementAction.grammarID))
        XCTAssertTrue(chipIDs.contains(EnhancementAction.enhanceID))
    }

    func testEmptyInvokeStillOpensAISearchInCursor() {
        let cursor = HostApp.Info(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor")
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: true, needsSetup: false, host: cursor,
                defaultActionID: EnhancementAction.grammarID
            ),
            EnhancementAction.searchID
        )
    }

    func testUnconfiguredInstallStaysOnAISearch() {
        let cursor = HostApp.Info(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor")
        XCTAssertEqual(
            AppCoordinator.initialActionID(
                openOnSearch: false, needsSetup: true, host: cursor,
                defaultActionID: EnhancementAction.grammarID
            ),
            EnhancementAction.searchID
        )
    }
}
