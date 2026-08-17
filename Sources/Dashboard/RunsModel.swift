import Foundation
import Observation

/// Loads and filters history for the All Runs screen.
///
/// Filtering happens here rather than in the view so the rules — particularly
/// what counts as accepted — live next to the data and can be tested without
/// building a view.
@MainActor
@Observable
final class RunsModel {
    private(set) var runs: [UsageRun] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    var query: String = ""
    var acceptedOnly = false
    /// Nil means every action.
    var actionFilter: String?
    var appFilter: String?

    var selection: UUID?

    private let reader: UsageLogReader

    init(reader: UsageLogReader = .shared) {
        self.reader = reader
    }

    /// True when the user has switched recording off. The screen says so rather
    /// than showing an empty list, because a blank screen with no explanation
    /// is indistinguishable from a broken feature.
    var isRecordingDisabled: Bool {
        !SettingsStore.shared.usageLoggingEnabled
    }

    var filtered: [UsageRun] {
        Self.filter(runs, query: query, acceptedOnly: acceptedOnly, action: actionFilter, app: appFilter)
    }

    /// Pure and `nonisolated` so the filter rules can be tested without the
    /// main actor, matching `TargetRegistry.resolveTargetID`.
    nonisolated static func filter(
        _ runs: [UsageRun],
        query: String,
        acceptedOnly: Bool,
        action: String?,
        app: String?
    ) -> [UsageRun] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return runs.filter { run in
            if acceptedOnly && !run.outcome.wasAccepted { return false }
            if let action, run.actionID != action { return false }
            if let app, run.hostAppName != app { return false }
            guard !needle.isEmpty else { return true }
            // Search what the user can see: their text, the result, and the
            // explanation. Not ids or model names, which they did not write.
            return run.inputText.lowercased().contains(needle)
                || (run.outputText?.lowercased().contains(needle) ?? false)
                || (run.rationale?.lowercased().contains(needle) ?? false)
        }
    }

    /// Distinct app names present in the loaded history, for the filter menu.
    var knownApps: [String] {
        Array(Set(runs.compactMap(\.hostAppName))).sorted()
    }

    var knownActions: [(id: String, name: String)] {
        var seen: [String: String] = [:]
        for run in runs {
            guard let id = run.actionID else { continue }
            seen[id] = run.actionName ?? id
        }
        return seen.map { (id: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        let loaded = await reader.allRuns()
        runs = loaded
        if selection == nil { selection = loaded.first?.id }
        isLoading = false
        hasLoaded = true
    }

    func run(withID id: UUID?) -> UsageRun? {
        guard let id else { return nil }
        return runs.first { $0.id == id }
    }
}
