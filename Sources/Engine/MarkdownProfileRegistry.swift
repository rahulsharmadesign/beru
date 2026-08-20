import Foundation
import Observation

/// Markdown profiles, persisted as JSON in UserDefaults.
///
/// Exactly one profile is active at a time, or none. Stacking several would put
/// the user back where the old single "custom skill prompt" setting left them:
/// a prompt assembled from pieces they cannot see all at once, producing results
/// they cannot attribute to anything.
@MainActor
@Observable
final class MarkdownProfileRegistry {
    static let shared = MarkdownProfileRegistry()

    private static let profilesKey = "markdownProfiles"
    private static let activeKey = "activeMarkdownProfileID"
    private static let seededKey = "seededMarkdownProfiles"

    private(set) var profiles: [MarkdownProfile]

    /// Nil means no profile is applied, which must stay reachable: it is the
    /// only way to get the unmodified Enhance prompt back.
    private(set) var activeID: String?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.bool(forKey: Self.seededKey),
           let data = defaults.data(forKey: Self.profilesKey),
           let decoded = try? JSONDecoder().decode([MarkdownProfile].self, from: data) {
            profiles = decoded
        } else {
            profiles = [MarkdownProfile.starter]
            defaults.set(true, forKey: Self.seededKey)
        }
        // Off by default. A profile silently rewriting every prompt from the
        // first launch would make the tool's behaviour unattributable before the
        // user knows the feature exists.
        activeID = defaults.string(forKey: Self.activeKey)
        if let activeID, !profiles.contains(where: { $0.id == activeID }) {
            self.activeID = nil
        }
        persist()
    }

    private let defaults: UserDefaults

    var active: MarkdownProfile? {
        guard let activeID else { return nil }
        return profiles.first { $0.id == activeID }
    }

    func profile(withID id: String) -> MarkdownProfile? {
        profiles.first { $0.id == id }
    }

    /// Passing nil, or the id that is already active, switches it off — so the
    /// same control both selects and deselects.
    func setActive(_ id: String?) {
        activeID = (id == activeID) ? nil : id
        persist()
    }

    @discardableResult
    func add(name: String = "New profile", content: String = "") -> MarkdownProfile {
        let profile = MarkdownProfile(name: name, content: content)
        profiles.append(profile)
        persist()
        return profile
    }

    func update(_ profile: MarkdownProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        persist()
    }

    func remove(id: String) {
        profiles.removeAll { $0.id == id }
        // Deleting the active profile must clear the selection, or prompts keep
        // being composed against a profile that no longer exists.
        if activeID == id { activeID = nil }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Self.profilesKey)
        }
        defaults.set(activeID, forKey: Self.activeKey)
    }
}
