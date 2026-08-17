import Foundation
import Observation

/// Lifetime token accounting, kept as four running totals in UserDefaults.
///
/// Deliberately not derived from the history log: retention deletes day-files
/// and the History tab can clear them, but a lifetime total that resets itself
/// when old logs age out would be worthless. It also means the Settings tab
/// never has to parse a 200 MB directory to draw a number.
///
/// Only *accepted* results count. A generation the user looked at and dismissed
/// saved nothing, so crediting it would inflate the total into a vanity metric.
@MainActor
@Observable
final class SavingsStore {
    static let shared = SavingsStore()

    private let defaults: UserDefaults

    private(set) var totalInputTokens: Int
    private(set) var totalOutputTokens: Int
    private(set) var acceptedRuns: Int
    /// When counting began — the first accepted run, not first launch, so the
    /// "since" date in Settings always has runs behind it.
    private(set) var trackingSince: Date?

    private enum Keys {
        static let inputTokens = "savingsTotalInputTokens"
        static let outputTokens = "savingsTotalOutputTokens"
        static let acceptedRuns = "savingsAcceptedRuns"
        static let trackingSince = "savingsTrackingSince"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        totalInputTokens = defaults.integer(forKey: Keys.inputTokens)
        totalOutputTokens = defaults.integer(forKey: Keys.outputTokens)
        acceptedRuns = defaults.integer(forKey: Keys.acceptedRuns)
        trackingSince = defaults.object(forKey: Keys.trackingSince) as? Date
    }

    /// Net lifetime saving. Signed: a stretch of runs that all grew their input
    /// shows as a negative total rather than silently reading zero.
    var totalSavedTokens: Int { totalInputTokens - totalOutputTokens }

    /// Lifetime ratio, computed from the totals rather than by averaging
    /// per-run ratios — a two-token run must not weigh as much as a 900-token
    /// one.
    var ratio: Double {
        guard totalInputTokens > 0 else { return 0 }
        return Double(totalSavedTokens) / Double(totalInputTokens)
    }

    var percent: Int { Int((abs(ratio) * 100).rounded()) }

    var hasData: Bool { acceptedRuns > 0 }

    /// Credits one accepted result and returns the new lifetime total, which
    /// the caller writes into the history event so the log alone can reconstruct
    /// the curve over time.
    @discardableResult
    func record(_ savings: TokenSavings) -> Int {
        totalInputTokens += savings.inputTokens
        totalOutputTokens += savings.outputTokens
        acceptedRuns += 1
        if trackingSince == nil {
            let now = Date()
            trackingSince = now
            defaults.set(now, forKey: Keys.trackingSince)
        }
        defaults.set(totalInputTokens, forKey: Keys.inputTokens)
        defaults.set(totalOutputTokens, forKey: Keys.outputTokens)
        defaults.set(acceptedRuns, forKey: Keys.acceptedRuns)
        return totalSavedTokens
    }

    func reset() {
        totalInputTokens = 0
        totalOutputTokens = 0
        acceptedRuns = 0
        trackingSince = nil
        for key in [Keys.inputTokens, Keys.outputTokens, Keys.acceptedRuns, Keys.trackingSince] {
            defaults.removeObject(forKey: key)
        }
    }
}
