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
        let allDmgs = assets.filter { $0.lowercased().hasSuffix(".dmg") }
        let named = allDmgs.filter { $0.lowercased().contains("beru") }
        let pool = named.isEmpty ? allDmgs : named
        if let exact = pool.first(where: { $0.localizedCaseInsensitiveContains(version) }) {
            return exact
        }
        return pool.first
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
        case upToDate
        case localBuild
        case available(version: String, downloadURL: URL)
        case downloading
        case installing
        case failed(String)
    }

    private(set) var status: Status = .idle
    private var checkTask: Task<Void, Never>?

    var showsInstallButton: Bool {
        switch status {
        case .available, .downloading, .installing: return true
        default: return false
        }
    }

    /// Sidebar and panel: a newer DMG is ready, or the last install failed.
    var showsUpdateButton: Bool {
        switch status {
        case .available, .downloading, .installing, .failed: return true
        default: return false
        }
    }

    var checkButtonTitle: String {
        switch status {
        case .checking: return "Checking…"
        case .failed: return "Retry"
        default: return "Check for Updates"
        }
    }

    var buttonTitle: String {
        switch status {
        case .downloading, .installing: return "Updating…"
        case .failed: return "Retry"
        default: return "Install"
        }
    }

    var statusMessage: String? {
        switch status {
        case .idle: return nil
        case .checking: return "Checking GitHub for a newer build…"
        case .upToDate: return "You’re on the latest version."
        case .localBuild:
            return "This local build does not install GitHub DMGs. Install a release to get updates."
        case .available(let version, _): return "Beru \(version) is available."
        case .downloading, .installing: return "Updating…"
        case .failed(let message): return message
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
        if AppSigning.isLocalDevelopmentBuild {
            status = .localBuild
            return
        }
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
                status = .failed("Couldn’t check for updates.")
                return
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latest = AppUpdateFeed.version(fromTag: release.tagName)
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            guard AppUpdateFeed.isNewer(latest, than: current) else {
                status = .upToDate
                return
            }
            let names = release.assets.map(\.name)
            guard let dmgName = AppUpdateFeed.dmgAsset(named: names, preferring: latest),
                  let asset = release.assets.first(where: { $0.name == dmgName }),
                  AppUpdateFeed.isTrustedDownload(asset.browserDownloadURL) else {
                status = .failed("No trusted disk image on the latest GitHub release.")
                return
            }
            status = .available(version: latest, downloadURL: asset.browserDownloadURL)
        } catch {
            if !Task.isCancelled {
                status = .failed("Couldn’t check for updates.")
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
        let payload = AppUpdateInstaller.Payload(
            dmgPath: dmgURL.path,
            destinationPath: Bundle.main.bundleURL.path,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.rahul.beru",
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            expectedLeafName: AppSigning.leafCertificateCommonName
        )

        let scriptURL = try AppUpdateInstaller.writeScript(
            AppUpdateInstaller.script(for: payload)
        )

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
