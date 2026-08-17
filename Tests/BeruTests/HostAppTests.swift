import XCTest
@testable import Beru

final class HostAppTests: XCTestCase {
    func testHelperStemStripsElectronSuffix() {
        XCTAssertEqual(HostApp.helperStem("Cursor Helper (Renderer)"), "Cursor")
        XCTAssertEqual(HostApp.helperStem("Claude Helper (GPU)"), "Claude")
        XCTAssertEqual(HostApp.helperStem("Cursor"), "Cursor")
    }

    func testPickPromotesHelperToOwnerApp() {
        let helper = HostApp.Info(bundleID: "com.github.Electron.helper", name: "Cursor Helper (Renderer)")
        let cursor = HostApp.Info(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor")
        let notes = HostApp.Info(bundleID: "com.apple.Notes", name: "Notes")

        let picked = HostApp.pick(focused: helper, frontmost: notes, running: [cursor, notes])
        XCTAssertEqual(picked?.bundleID, cursor.bundleID)
        XCTAssertEqual(picked?.name, "Cursor")
    }

    func testPickKeepsNonHelperFocusedApp() {
        let notes = HostApp.Info(bundleID: "com.apple.Notes", name: "Notes")
        let cursor = HostApp.Info(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor")
        let picked = HostApp.pick(focused: notes, frontmost: cursor, running: [notes, cursor])
        XCTAssertEqual(picked?.bundleID, notes.bundleID)
    }
}
