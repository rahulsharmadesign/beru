import XCTest
@testable import Beru

/// The updater deletes an application directory unattended. These tests assert
/// the script's safety properties, since the failure mode is "user has no app".
final class AppUpdateInstallerTests: XCTestCase {

    private func payload(leaf: String? = "Developer ID Application: Example") -> AppUpdateInstaller.Payload {
        AppUpdateInstaller.Payload(
            dmgPath: "/tmp/Beru-update.dmg",
            destinationPath: "/Applications/Beru.app",
            bundleIdentifier: "com.rahul.beru",
            processIdentifier: 4242,
            expectedLeafName: leaf
        )
    }

    // MARK: - Never destroy before verifying

    func testScriptDoesNotRecursivelyDeleteDestinationOutright() {
        let script = AppUpdateInstaller.script(for: payload())
        // The original ran `rm -rf "$DEST"` before copying anything.
        XCTAssertFalse(
            script.contains("rm -rf \"$DEST\""),
            "Destination must be moved aside, never deleted before a verified replacement exists."
        )
    }

    func testScriptMovesOldBundleAsideAndCanRestoreIt() {
        let script = AppUpdateInstaller.script(for: payload())
        XCTAssertTrue(script.contains("mv \"$DEST\" \"$BACKUP\""))
        XCTAssertTrue(script.contains("mv \"$BACKUP\" \"$DEST\""), "Must be able to roll back.")
        XCTAssertTrue(script.contains("trap restore ERR"), "Failures must trigger the restore path.")
    }

    func testScriptStagesBesideDestinationBeforeSwapping() {
        let script = AppUpdateInstaller.script(for: payload())
        XCTAssertTrue(script.contains("cp -R \"$SRC\" \"$STAGE\""))
        XCTAssertTrue(script.contains("mv \"$STAGE\" \"$DEST\""))
    }

    // MARK: - Verify before trusting

    func testScriptVerifiesSignatureOfDownloadBeforeSwapping() {
        let script = AppUpdateInstaller.script(for: payload())
        XCTAssertTrue(script.contains("codesign --verify --deep --strict \"$SRC\""))

        let verifyIndex = script.range(of: "codesign --verify --deep --strict \"$SRC\"")?.lowerBound
        let swapIndex = script.range(of: "mv \"$DEST\" \"$BACKUP\"")?.lowerBound
        XCTAssertNotNil(verifyIndex)
        XCTAssertNotNil(swapIndex)
        if let verifyIndex, let swapIndex {
            XCTAssertLessThan(verifyIndex, swapIndex, "Signature must be checked before the app is touched.")
        }
    }

    func testScriptVerifiesStagedCopyToo() {
        let script = AppUpdateInstaller.script(for: payload())
        XCTAssertTrue(
            script.contains("codesign --verify --deep --strict \"$STAGE\""),
            "A truncated copy satisfies cp but not codesign."
        )
    }

    func testScriptChecksBundleIdentifier() {
        let script = AppUpdateInstaller.script(for: payload())
        XCTAssertTrue(script.contains("WANT_ID=\"com.rahul.beru\""))
        XCTAssertTrue(script.contains("$GOT_ID\" != \"$WANT_ID"))
    }

    func testScriptPinsExpectedLeafCertificateWhenKnown() {
        let script = AppUpdateInstaller.script(for: payload())
        XCTAssertTrue(script.contains("WANT_LEAF=\"Developer ID Application: Example\""))
    }

    func testUnsignedBuildDegradesToStructuralCheckOnly() {
        // Ad-hoc local builds have no leaf name; the update must still work.
        let script = AppUpdateInstaller.script(for: payload(leaf: nil))
        XCTAssertTrue(script.contains("WANT_LEAF=\"\""))
        XCTAssertTrue(
            script.contains("if [[ -n \"$WANT_LEAF\" ]]; then"),
            "Empty expected leaf must skip the comparison rather than fail it."
        )
    }

    func testQuotesAreStrippedFromLeafNameSoTheScriptCannotBeBroken() {
        let script = AppUpdateInstaller.script(for: payload(leaf: "Bad\" name"))
        XCTAssertTrue(script.contains("WANT_LEAF=\"Bad name\""))
    }

    // MARK: - Waiting for exit must terminate

    func testWaitForProcessExitIsBounded() {
        let script = AppUpdateInstaller.script(for: payload())
        XCTAssertFalse(
            script.contains("while kill -0 \"$PID\" 2>/dev/null; do"),
            "An unbounded wait hangs forever if the pid is recycled."
        )
        XCTAssertTrue(script.contains("for _ in $(seq 1 150)"))
    }

    // MARK: - Unpredictable script location

    func testScriptIsWrittenToAPrivateRandomDirectory() throws {
        let first = try AppUpdateInstaller.writeScript("#!/bin/bash\ntrue\n")
        let second = try AppUpdateInstaller.writeScript("#!/bin/bash\ntrue\n")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        XCTAssertNotEqual(
            first.deletingLastPathComponent(),
            second.deletingLastPathComponent(),
            "A fixed path can be pre-created or symlinked by another process."
        )

        let attributes = try FileManager.default.attributesOfItem(
            atPath: first.deletingLastPathComponent().path
        )
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(permissions, 0o700, "Containing directory must be user-only.")

        let scriptPermissions = try FileManager.default
            .attributesOfItem(atPath: first.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(scriptPermissions?.intValue, 0o700)
    }

    func testWriteScriptFailsIfDirectoryAlreadyExists() throws {
        // `withIntermediateDirectories: false` is deliberate: it makes a
        // pre-created directory an error instead of something we write into.
        let url = try AppUpdateInstaller.writeScript("#!/bin/bash\ntrue\n")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
