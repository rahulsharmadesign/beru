import XCTest
@testable import Beru

final class TextReplaceTests: XCTestCase {
    func testUnchangedSelectionIsNotTrusted() {
        XCTAssertFalse(TextReplace.didMutateSelection(
            before: "hello",
            after: "hello",
            replacement: "hello world"
        ))
    }

    func testMatchingReplacementCountsAsSuccess() {
        XCTAssertTrue(TextReplace.didMutateSelection(
            before: "hello",
            after: "hello world",
            replacement: "hello world"
        ))
    }

    func testConsumedSelectionCountsAsSuccess() {
        // Hosts often clear the selection after a successful write.
        XCTAssertTrue(TextReplace.didMutateSelection(
            before: "hello",
            after: "",
            replacement: "hello world"
        ))
    }

    func testAlreadyCorrectSelectionIsSuccess() {
        XCTAssertTrue(TextReplace.didMutateSelection(
            before: "hello",
            after: "hello",
            replacement: "hello"
        ))
    }

    func testUnreadBeforeAndAfterIsNotTrusted() {
        XCTAssertFalse(TextReplace.didMutateSelection(
            before: nil,
            after: nil,
            replacement: "hello"
        ))
    }

    func testElectronHelperBundleIsSkipped() {
        let helper = HostApp.Info(bundleID: "com.github.Electron.helper", name: "Cursor Helper (Renderer)")
        XCTAssertTrue(helper.isHelper)
        let notes = HostApp.Info(bundleID: "com.apple.Notes", name: "Notes")
        XCTAssertFalse(notes.isHelper)
    }
}
