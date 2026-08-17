import Foundation
import Observation

/// Target profiles, seeded from the built-in defaults and persisted as JSON in
/// UserDefaults. Unlike actions, built-in targets are editable — their prompt
/// fragments are opinions about other tools' conventions, which users may
/// reasonably disagree with — but each can be reset to the shipped default.
@MainActor
@Observable
final class TargetRegistry {
    static let shared = TargetRegistry()

    private static let profilesKey = "targetProfiles"
    private static let seededKey = "seededTargetProfiles"
    private static let editedIDsKey = "targetProfilesEditedIDs"

    private(set) var profiles: [TargetProfile]

    /// Built-in ids the user has edited, so a shipped fix does not overwrite
    /// their wording. Tracked here rather than as a field on `TargetProfile`,
    /// whose `Equatable` conformance is what `isModifiedFromDefault` compares.
    private var userEditedIDs: Set<String>

    private init() {
        let defaults = UserDefaults.standard
        let edited = Set(defaults.stringArray(forKey: Self.editedIDsKey) ?? [])
        userEditedIDs = edited
        var stored: [TargetProfile] = []
        if defaults.bool(forKey: Self.seededKey),
           let data = defaults.data(forKey: Self.profilesKey),
           let decoded = try? JSONDecoder().decode([TargetProfile].self, from: data) {
            stored = decoded
        } else {
            stored = TargetProfile.builtInDefaults
            defaults.set(true, forKey: Self.seededKey)
        }
        // Re-append any built-in the stored copy predates, so shipping a new
        // target never requires the user to reset their profiles.
        let knownIDs = Set(stored.map(\.id))
        stored.append(contentsOf: TargetProfile.builtInDefaults.filter { !knownIDs.contains($0.id) })
        profiles = Self.refreshingUneditedBuiltIns(stored, userEdited: edited)
        persist()
    }

    /// Adopts the shipped wording for every built-in the user has not edited.
    ///
    /// Without this, a fragment is frozen at whatever shipped the first time the
    /// app ran: seeding writes the defaults to UserDefaults once, and the init
    /// above only ever re-appended *new* ids. So a correction to a fragment's
    /// text reached nobody who had already launched the app — which made fixing
    /// the Cursor fragment's invented paths and build commands a no-op on the
    /// one machine that reported them. Fragments are prompt engineering, not user
    /// data; a better one should arrive with the update that improves it.
    ///
    /// An edited built-in is left exactly as the user left it. The set is empty
    /// for anyone upgrading from before it was recorded, so a built-in edited
    /// before this shipped is reverted once — acceptable because the Targets tab
    /// offers Reset for precisely this and the shipped text is the one that was
    /// measured, and because the alternative is silently keeping a fragment
    /// known to fabricate file paths.
    /// Pure and `nonisolated` so it can be tested without UserDefaults or the
    /// main actor, like `resolveTargetID` below.
    nonisolated static func refreshingUneditedBuiltIns(
        _ stored: [TargetProfile],
        userEdited: Set<String>
    ) -> [TargetProfile] {
        stored.map { profile in
            guard profile.isBuiltIn, !userEdited.contains(profile.id),
                  let shipped = TargetProfile.builtInDefaults.first(where: { $0.id == profile.id })
            else { return profile }
            return shipped
        }
    }

    func profile(withID id: String) -> TargetProfile? {
        profiles.first { $0.id == id }
    }

    func addCustom(name: String, icon: String, fragment: String) {
        profiles.append(
            TargetProfile(
                id: "target-custom-\(UUID().uuidString)",
                name: name,
                icon: icon,
                promptFragment: fragment,
                isBuiltIn: false
            )
        )
        persist()
    }

    func update(_ profile: TargetProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        // Editing a built-in opts it out of shipped-wording refreshes. Recorded
        // even when the edit happens to leave the text identical: the user opened
        // it and pressed save, which is the signal, not the diff.
        if profile.isBuiltIn {
            userEditedIDs.insert(profile.id)
        }
        profiles[index] = profile
        persist()
    }

    func resetToDefault(id: String) {
        guard let shipped = TargetProfile.builtInDefaults.first(where: { $0.id == id }),
              let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        // Reset hands the profile back to the shipped wording, which also means
        // handing back future improvements to it.
        userEditedIDs.remove(id)
        profiles[index] = shipped
        persist()
    }

    /// True when the stored copy has drifted from what shipped.
    func isModifiedFromDefault(id: String) -> Bool {
        guard let shipped = TargetProfile.builtInDefaults.first(where: { $0.id == id }),
              let current = profile(withID: id) else { return false }
        return shipped != current
    }

    func removeCustom(id: String) {
        profiles.removeAll { $0.id == id && !$0.isBuiltIn }
        persist()
    }

    /// Serialises custom targets for sharing or import. Built-ins are excluded:
    /// they ship from code, and round-tripping them through JSON would freeze a
    /// snapshot of the fragment as the shipped text.
    func exportCustomTargets() -> Data? {
        let custom = profiles.filter { !$0.isBuiltIn }
        guard !custom.isEmpty else { return nil }
        return try? JSONEncoder().encode(custom)
    }

    /// Merges a JSON array of custom targets into the registry, skipping any
    /// whose id already exists so a re-import doesn't duplicate. Returns the
    /// number added.
    @discardableResult
    func importCustomTargets(from data: Data) -> Int {
        guard let decoded = try? JSONDecoder().decode([TargetProfile].self, from: data) else {
            return 0
        }
        let existing = Set(profiles.map(\.id))
        let additions = decoded.filter { !$0.isBuiltIn && !existing.contains($0.id) }
        guard !additions.isEmpty else { return 0 }
        profiles.append(contentsOf: additions)
        persist()
        return additions.count
    }

    /// Which target to pre-select. Pure and side-effect free so it can be
    /// tested without AX or UserDefaults.
    nonisolated static func resolveTargetID(
        bundleID: String?,
        appName: String? = nil,
        perApp: [String: String],
        lastUsed: String,
        known: Set<String>
    ) -> String {
        func valid(_ id: String?) -> String? {
            guard let id, known.contains(id) else { return nil }
            return id
        }
        let seeded = bundleID.flatMap { valid(TargetProfile.seededID(forBundleID: $0, name: appName)) }
        if let bundleID {
            let remembered = valid(perApp[bundleID])
            if let remembered, remembered != TargetProfile.genericID {
                return remembered
            }
            if let seeded { return seeded }
            if let remembered { return remembered }
        }
        return valid(lastUsed) ?? TargetProfile.genericID
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.profilesKey)
        }
        UserDefaults.standard.set(Array(userEditedIDs), forKey: Self.editedIDsKey)
    }
}
