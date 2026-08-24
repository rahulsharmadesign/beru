import AppKit
import Foundation
import Observation
import Security

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

    /// Local `install.sh` builds keep a marketing version that can sit behind
    /// GitHub. Offering a DMG there would replace the working tree with the
    /// last release.
    static func shouldOfferUpdate(latest: String, current: String, isLocalDevelopmentBuild: Bool) -> Bool {
        !isLocalDevelopmentBuild && isNewer(latest, than: current)
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

        var isAvailable: Bool {
            if case .available = self { return true }
            return false
        }
    }

    private(set) var status: Status = .idle
    private var checkTask: Task<Void, Never>?
    private var periodicTask: Task<Void, Never>?
    /// Menu-bar apps stay launched for days. Re-check so a release published
    /// after startup still surfaces an Update chip without requiring a relaunch.
    private static let periodicInterval: Duration = .seconds(6 * 60 * 60)

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

    /// Starts the launch check and a slow background poll. Safe to call once.
    func start() {
        check()
        guard periodicTask == nil else { return }
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.periodicInterval)
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.check() }
            }
        }
    }

    /// Looks for a newer GitHub release. Pass `force` from About so opening
    /// that page always refreshes, even when an older "available" result is
    /// already showing.
    func check(force: Bool = false) {
        guard !isBusy else { return }
        guard !AppSigning.isLocalDevelopmentBuild else {
            status = .idle
            return
        }
        if !force, case .available = status { return }
        checkTask?.cancel()
        checkTask = Task { await performCheck(preservingAvailable: !force) }
    }

    func install() {
        switch status {
        case .available, .failed:
            Task { await performInstall() }
        default:
            break
        }
    }

    private func performCheck(preservingAvailable: Bool) async {
        let previous = status
        if !(preservingAvailable && previous.isAvailable) {
            status = .checking
        }
        do {
            var request = URLRequest(url: AppUpdateFeed.latestRelease)
            request.setValue("Beru", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                // Keep a known-good Update chip if GitHub blips.
                if !(preservingAvailable && previous.isAvailable) {
                    status = .idle
                }
                return
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latest = AppUpdateFeed.version(fromTag: release.tagName)
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            guard AppUpdateFeed.shouldOfferUpdate(
                latest: latest,
                current: current,
                isLocalDevelopmentBuild: AppSigning.isLocalDevelopmentBuild
            ) else {
                status = .idle
                return
            }
            let names = release.assets.map(\.name)
            guard let dmgName = AppUpdateFeed.dmgAsset(named: names, preferring: latest),
                  let asset = release.assets.first(where: { $0.name == dmgName }),
                  AppUpdateFeed.isTrustedDownload(asset.browserDownloadURL) else {
                if !(preservingAvailable && previous.isAvailable) {
                    status = .idle
                }
                return
            }
            status = .available(version: latest, downloadURL: asset.browserDownloadURL)
        } catch {
            if !Task.isCancelled, !(preservingAvailable && previous.isAvailable) {
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
            await performCheck(preservingAvailable: false)
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

/// Leaf certificate of the running binary. `install.sh` re-signs with
/// "Beru Local Signing"; GitHub DMGs do not.
enum AppSigning {
    static let localCertificateName = "Beru Local Signing"

    static var isLocalDevelopmentBuild: Bool {
        leafCertificateCommonName == localCertificateName
    }

    static var leafCertificateCommonName: String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info
        ) == errSecSuccess, let info else { return nil }
        let certificates = (info as NSDictionary)[kSecCodeInfoCertificates] as? [SecCertificate]
        guard let leaf = certificates?.first else { return nil }
        var commonName: CFString?
        guard SecCertificateCopyCommonName(leaf, &commonName) == errSecSuccess else { return nil }
        return commonName as String?
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
