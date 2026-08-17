import XCTest
@testable import Beru

final class OllamaSetupTests: XCTestCase {
    func testResolveWhenServerIsReachable() {
        XCTAssertEqual(
            OllamaSetup.resolve(serverReachable: true, fileExists: { _ in false }),
            .running
        )
        XCTAssertEqual(
            OllamaSetup.resolve(serverReachable: true, fileExists: { _ in true }),
            .running
        )
    }

    func testResolveWhenInstalledButServerIsDown() {
        XCTAssertEqual(
            OllamaSetup.resolve(serverReachable: false, fileExists: { $0.hasSuffix("Ollama.app") }),
            .installedNotRunning
        )
    }

    func testResolveWhenNotInstalledAndServerIsDown() {
        XCTAssertEqual(
            OllamaSetup.resolve(serverReachable: false, fileExists: { _ in false }),
            .notInstalled
        )
    }

    func testAppURLPrefersSystemApplications() {
        let url = OllamaSetup.appURL { path in
            path == "/Applications/Ollama.app" || path.hasSuffix("/Applications/Ollama.app")
        }
        XCTAssertEqual(url?.path, "/Applications/Ollama.app")
    }

    func testAppURLFallsBackToUserApplications() {
        let home = NSHomeDirectory()
        let url = OllamaSetup.appURL { path in
            path == home + "/Applications/Ollama.app"
        }
        XCTAssertEqual(url?.path, home + "/Applications/Ollama.app")
    }

    func testAppURLIsNilWhenMissing() {
        XCTAssertNil(OllamaSetup.appURL { _ in false })
    }

    func testIsAppInstalledReflectsPresence() {
        XCTAssertTrue(OllamaSetup.isAppInstalled { $0.hasSuffix("Ollama.app") })
        XCTAssertFalse(OllamaSetup.isAppInstalled { _ in false })
    }
}
