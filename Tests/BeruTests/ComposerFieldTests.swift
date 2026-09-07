import AppKit
import XCTest
@testable import Beru

/// The growing composer field must size, cap, scroll, and submit — those
/// paths run on every keystroke and once took the app down with them.
@MainActor
final class ComposerFieldTests: XCTestCase {
    private func makeScroll() -> (ComposerScrollView, GrowingComposerTextView) {
        let font = NSFont.systemFont(ofSize: 13)
        let oneLine = GrowingComposerTextView.oneLineHeight(for: font)
        let textView = GrowingComposerTextView(frame: NSRect(x: 0, y: 0, width: 300, height: oneLine))
        textView.font = font
        let scroll = ComposerScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: oneLine))
        scroll.minHeight = oneLine
        scroll.maxHeight = oneLine * 3
        scroll.documentView = textView
        return (scroll, textView)
    }

    func testShortTextReportsAtLeastOneLine() {
        let (scroll, textView) = makeScroll()
        textView.string = "hello"
        scroll.syncHeight()
        XCTAssertGreaterThanOrEqual(scroll.intrinsicContentSize.height, scroll.minHeight)
    }

    func testLongTextCapsAtThreeLines() {
        let (scroll, textView) = makeScroll()
        textView.string = String(repeating: "word ", count: 200)
        scroll.syncHeight()
        XCTAssertLessThanOrEqual(scroll.intrinsicContentSize.height, scroll.maxHeight + 1)
    }

    /// Three lines of 13pt system hold ~51pt. The old ascender + descender +
    /// leading math measured ~60 and a fourth line slipped through.
    func testCapMatchesThreeRenderedLines() {
        let (scroll, _) = makeScroll()
        XCTAssertGreaterThanOrEqual(scroll.maxHeight, 45)
        XCTAssertLessThanOrEqual(scroll.maxHeight, 55)
    }

    func testReturnSubmits() {
        let (_, textView) = makeScroll()
        var submitted = false
        textView.onSubmit = { submitted = true }
        textView.insertNewline(nil)
        XCTAssertTrue(submitted)
    }
}
