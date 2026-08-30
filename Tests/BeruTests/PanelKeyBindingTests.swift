import XCTest
@testable import Beru

/// The panel's key handling used to replace the user's selection on a bare
/// Return. Replace is destructive and unrecoverable — it overwrites text in
/// whatever app the user came from — so these tests exist mainly to keep that
/// behaviour from coming back.
final class PanelKeyBindingTests: XCTestCase {

    // MARK: - The regression these tests exist for

    func testBareReturnNeverReplacesWhenComposerIsEmpty() {
        // Previously: fell through to `performReplace()`.
        let intent = PanelKeyBinding.resolveReturn(
            modifiers: .none,
            canSubmit: false,
            hasAcceptableResult: true
        )
        XCTAssertEqual(intent, .pass, "A bare Return must never trigger a destructive replace.")
    }

    func testBareReturnDoesNotReplaceEvenWithNothingElseToDo() {
        let intent = PanelKeyBinding.resolveReturn(
            modifiers: .none,
            canSubmit: false,
            hasAcceptableResult: false
        )
        XCTAssertEqual(intent, .pass)
    }

    // MARK: - Return

    func testBareReturnSubmitsWhenComposerHasText() {
        let intent = PanelKeyBinding.resolveReturn(
            modifiers: .none,
            canSubmit: true,
            hasAcceptableResult: false
        )
        XCTAssertEqual(intent, .submit)
    }

    func testSubmitWinsOverReplaceOnBareReturn() {
        // Both are possible; the non-destructive one must be chosen.
        let intent = PanelKeyBinding.resolveReturn(
            modifiers: .none,
            canSubmit: true,
            hasAcceptableResult: true
        )
        XCTAssertEqual(intent, .submit)
    }

    // MARK: - Command-Return

    func testCommandReturnReplaces() {
        let intent = PanelKeyBinding.resolveReturn(
            modifiers: .command,
            canSubmit: false,
            hasAcceptableResult: true
        )
        XCTAssertEqual(intent, .replace, "⌘↩ is the explicit, documented replace gesture.")
    }

    func testCommandReturnReplacesEvenWhenComposerHasText() {
        // The explicit modifier beats the implicit submit.
        let intent = PanelKeyBinding.resolveReturn(
            modifiers: .command,
            canSubmit: true,
            hasAcceptableResult: true
        )
        XCTAssertEqual(intent, .replace)
    }

    func testCommandReturnDoesNothingWithoutAResult() {
        let intent = PanelKeyBinding.resolveReturn(
            modifiers: .command,
            canSubmit: false,
            hasAcceptableResult: false
        )
        XCTAssertEqual(intent, .pass, "Nothing to apply, so the key should pass through.")
    }

    // MARK: - Copy

    func testCommandCCopies() {
        let intent = PanelKeyBinding.resolveCharacter("c", modifiers: .command, tabCount: 3)
        XCTAssertEqual(intent, .copy)
    }

    func testBareCIsPassedThroughForTyping() {
        // Otherwise the letter "c" could never be typed into the composer.
        let intent = PanelKeyBinding.resolveCharacter("c", modifiers: .none, tabCount: 3)
        XCTAssertEqual(intent, .pass)
    }

    // MARK: - Tab selection

    func testCommandDigitSelectsTab() {
        XCTAssertEqual(
            PanelKeyBinding.resolveCharacter("1", modifiers: .command, tabCount: 3),
            .selectTab(index: 1)
        )
        XCTAssertEqual(
            PanelKeyBinding.resolveCharacter("3", modifiers: .command, tabCount: 3),
            .selectTab(index: 3)
        )
    }

    func testCommandDigitBeyondTabCountIsIgnored() {
        XCTAssertEqual(
            PanelKeyBinding.resolveCharacter("4", modifiers: .command, tabCount: 3),
            .pass
        )
    }

    func testCommandZeroIsIgnored() {
        // Tabs are 1-based; 0 has no target.
        XCTAssertEqual(
            PanelKeyBinding.resolveCharacter("0", modifiers: .command, tabCount: 3),
            .pass
        )
    }

    func testBareDigitIsPassedThroughForTyping() {
        XCTAssertEqual(
            PanelKeyBinding.resolveCharacter("2", modifiers: .none, tabCount: 3),
            .pass
        )
    }

    func testUnclaimedCharacterPasses() {
        XCTAssertEqual(
            PanelKeyBinding.resolveCharacter("q", modifiers: .command, tabCount: 3),
            .pass
        )
    }

    // MARK: - Escape

    func testEscapeCancels() {
        XCTAssertEqual(PanelKeyBinding.resolveEscape(), .cancel)
    }

    // MARK: - No unmodified key is destructive

    func testNoUnmodifiedKeyResolvesToReplace() {
        // Guards the whole class of bug rather than one instance of it.
        for canSubmit in [true, false] {
            for hasResult in [true, false] {
                let intent = PanelKeyBinding.resolveReturn(
                    modifiers: .none,
                    canSubmit: canSubmit,
                    hasAcceptableResult: hasResult
                )
                XCTAssertNotEqual(
                    intent, .replace,
                    "Return without ⌘ resolved to .replace (canSubmit: \(canSubmit), hasResult: \(hasResult))"
                )
            }
        }

        let characters: [Character] = ["c", "1", "5", "9", "q", "0"]
        for character in characters {
            let intent = PanelKeyBinding.resolveCharacter(character, modifiers: .none, tabCount: 5)
            XCTAssertNotEqual(intent, .replace, "'\(character)' without ⌘ resolved to .replace")
        }
    }
}
