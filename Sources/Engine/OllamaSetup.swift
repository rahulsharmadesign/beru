import AppKit
import Foundation

enum OllamaSetupState: Equatable {
    case notInstalled
    case installedNotRunning
    case running
}

/// Detects whether Ollama is installed, can launch it, and resolves setup state
/// from server reachability.
struct OllamaSetup: Sendable {
    static let downloadURL = URL(string: "https://ollama.com/download")!

    private static let appCandidates = [
        "/Applications/Ollama.app",
        NSHomeDirectory() + "/Applications/Ollama.app"
    ]

    static func appURL(fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)) -> URL? {
        for path in appCandidates where fileExists(path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return nil
    }

    static func isAppInstalled(fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)) -> Bool {
        appURL(fileExists: fileExists) != nil
    }

    static func resolve(
        serverReachable: Bool,
        fileExists: (String) -> Bool = FileManager.default.fileExists(atPath:)
    ) -> OllamaSetupState {
        if serverReachable { return .running }
        if isAppInstalled(fileExists: fileExists) { return .installedNotRunning }
        return .notInstalled
    }

    @MainActor
    static func openDownloadPage() {
        NSWorkspace.shared.open(downloadURL)
    }

    @MainActor
    static func launchApp() throws {
        guard let url = appURL() else { throw LaunchError.notInstalled }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                NSLog("Beru: failed to open Ollama — \(error.localizedDescription)")
            }
        }
    }

    enum LaunchError: LocalizedError {
        case notInstalled

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "Ollama is not installed. Download it first."
            }
        }
    }
}
