import XCTest
@testable import Enhancify

final class TextCaptureTests: XCTestCase {
    /// VS Code, Cursor and Windsurf copy the whole current line on Cmd-C with
    /// nothing selected. That line must not be mistaken for a selection.
    func testEditorEmptySelectionCopyIsRecognised() {
        XCTAssertTrue(TextCapture.isEmptySelectionMarker(#"{"version":1,"isFromEmptySelection":true,"multicursorText":null,"mode":"swift"}"#))
        XCTAssertFalse(TextCapture.isEmptySelectionMarker(#"{"version":1,"isFromEmptySelection":false,"mode":"swift"}"#))
        XCTAssertFalse(TextCapture.isEmptySelectionMarker("not json"))
        XCTAssertFalse(TextCapture.isEmptySelectionMarker("{}"))
    }
}
