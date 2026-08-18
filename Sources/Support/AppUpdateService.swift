import AppKit
import Foundation
import Observation

/// GitHub Releases feed used to notice a newer Beru DMG.
enum AppUpdateFeed {
    static let latestRelease = URL(string: "https://api.github.com/repos/rahulsharmadesign/beru/releases/latest")!

    static func isTrustedDownload(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "github.com"
            || host.hasSuffix(".github.com")
            || host == "objects.githubusercontent.com"
            || host.hasSuffix(".githubusercontent.com")
    }

    static func version(fromTag tag: String) -> String {
        var value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        return value
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) == .orderedDescending
    }

    static func dmgAsset(named assets: [String], preferring version: String) -> String? {
        let dmgs = assets.filter { $0.lowercased().hasSuffix(".dmg") && $0.lowercased().contains("beru") }
        if let exact = dmgs.first(where: { $0.localizedCaseInsensitiveContains(version) }) {
            return exact
        }
        return dmgs.first
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let a = numericParts(lhs)
        let b = numericParts(rhs)
        let count = max(a.count, b.count)
        for index in 0..<count {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func numericParts(_ raw: String) -> [Int] {
        version(fromTag: raw)
            .split { !$0.isNumber }
            .compactMap { Int($0) }
    }
}

/// Checks GitHub Releases and replaces this app with the latest DMG.
@MainActor
@Observable
final class AppUpdateService {
    static let shared = AppUpdateService()

    enum Status: Equatable {
        case idle
        case checking
        case available(version: String, downloadURL: URL)
        case downloading
        case installing
        case failed(String)
    }

    private(set) var status: Status = .idle
    private var checkTask: Task<Void, Never>?

    var showsUpdateButton: Bool {
        switch status {
        case .available, .downloading, .installing, .failed: return true
        default: return false
        }
    }

    var buttonTitle: String {
        switch status {
        case .downloading, .installing: return "Updating…"
        case .failed: return "Retry"
        default: return "Update"
        }
    }

    var isBusy: Bool {
        switch status {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    var availableVersion: String? {
        if case .available(let version, _) = status { return version }
        return nil
    }

    private init() {}

    func check() {
        guard !isBusy else { return }
        checkTask?.cancel()
        checkTask = Task { await performCheck() }
    }

    func install() {
        switch status {
        case .available, .failed:
            Task { await performInstall() }
        default:
            break
        }
    }

    private func performCheck() async {
        status = .checking
        do {
            var request = URLRequest(url: AppUpdateFeed.latestRelease)
            request.setValue("Beru", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                status = .idle
                return
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latest = AppUpdateFeed.version(fromTag: release.tagName)
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            guard AppUpdateFeed.isNewer(latest, than: current) else {
                status = .idle
                return
            }
            let names = release.assets.map(\.name)
            guard let dmgName = AppUpdateFeed.dmgAsset(named: names, preferring: latest),
                  let asset = release.assets.first(where: { $0.name == dmgName }),
                  AppUpdateFeed.isTrustedDownload(asset.browserDownloadURL) else {
                status = .idle
                return
            }
            status = .available(version: latest, downloadURL: asset.browserDownloadURL)
        } catch {
            if !Task.isCancelled {
                status = .idle
            }
        }
    }

    private func performInstall() async {
        let downloadURL: URL
        switch status {
        case .available(_, let url):
            downloadURL = url
        case .failed:
            await performCheck()
            if case .available(_, let url) = status {
                downloadURL = url
            } else {
                return
            }
        default:
            return
        }
        guard AppUpdateFeed.isTrustedDownload(downloadURL) else {
            status = .failed("The download source is not trusted.")
            return
        }
        status = .downloading
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
            let dmgURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Beru-update-\(UUID().uuidString).dmg")
            try? FileManager.default.removeItem(at: dmgURL)
            try FileManager.default.moveItem(at: tempURL, to: dmgURL)
            status = .installing
            try launchInstaller(dmgURL: dmgURL)
            NSApp.terminate(nil)
        } catch {
            status = .failed("Couldn’t install the update. Try again.")
        }
    }

    private func launchInstaller(dmgURL: URL) throws {
        let dest = Bundle.main.bundleURL.path
        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("beru-apply-update.sh")
        let script = """
        #!/bin/bash
        set -euo pipefail
        PID="\(pid)"
        DMG="\(dmgURL.path)"
        DEST="\(dest)"
        while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
        sleep 0.5
        MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" | grep -o '/Volumes/[^ ]*' | tail -1)
        SRC=$(find "$MOUNT" -maxdepth 2 -name 'Beru.app' -print -quit)
        if [[ -z "$SRC" || ! -d "$SRC" ]]; then
          hdiutil detach "$MOUNT" -quiet || true
          exit 1
        fi
        rm -rf "$DEST"
        cp -R "$SRC" "$DEST"
        xattr -cr "$DEST" || true
        hdiutil detach "$MOUNT" -quiet || true
        rm -f "$DMG"
        open "$DEST"
        rm -f "$0"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        try process.run()
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}
