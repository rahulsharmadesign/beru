import Foundation
import Observation

/// Built-in actions plus user-defined ones, persisted as JSON in UserDefaults.
@MainActor
@Observable
final class ActionRegistry {
    static let shared = ActionRegistry()

    private static let customActionsKey = "customActions"
    private static let actionOrderKey = "actionOrder"
    /// Legacy: Writing Tools tones. Still honored for installs that already
    /// received them; new installs skip tones and get verb skills instead.
    private static let seededStartersKey = "seededStarterActions"
    static let seededVerbActionsKey = "seededVerbActions"
    /// Retired setting, read once by the migration below and then cleared.
    static let legacySkillPromptKey = "customSkillPrompt"
    static let migratedSkillActionID = "custom-migrated-skill"

    private(set) var customActions: [EnhancementAction]
    private var actionOrder: [String]

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.customActionsKey),
           let decoded = try? JSONDecoder().decode([EnhancementAction].self, from: data) {
            customActions = decoded
        } else {
            customActions = []
        }
        actionOrder = defaults.stringArray(forKey: Self.actionOrderKey) ?? []
        // New installs: seed Reply / Summarize / Explain, not Writing Tools tones.
        // Existing installs that already have tones keep them; verbs are added once.
        if !defaults.bool(forKey: Self.seededVerbActionsKey) {
            let existingIDs = Set(customActions.map(\.id))
            let verbs = EnhancementAction.starterVerbActions.filter { !existingIDs.contains($0.id) }
            if !verbs.isEmpty {
                customActions.append(contentsOf: verbs)
                persist()
            }
            defaults.set(true, forKey: Self.seededVerbActionsKey)
        }
        // Mark the old tone seed consumed without adding tones, so first-run
        // users never get Friendly / Professional / Concise by default.
        if !defaults.bool(forKey: Self.seededStartersKey) {
            defaults.set(true, forKey: Self.seededStartersKey)
        }
        migrateLegacySkillPrompt(defaults: defaults)
        refreshShippedVerbPrompts()
    }

    /// Keeps Reply / Summarize / Explain prompts in sync with `Prompts.swift`.
    /// Those chips are seeded into UserDefaults once; without this, improving
    /// the prompts in code would never reach existing installs.
    private func refreshShippedVerbPrompts() {
        var changed = false
        for index in customActions.indices {
            let id = customActions[index].id
            guard let live = EnhancementAction.liveSystemPrompt(for: id),
                  customActions[index].systemPrompt != live else { continue }
            customActions[index].systemPrompt = live
            changed = true
        }
        if changed { persist() }
    }

    /// Moves a saved "Custom Skill Prompt" onto its own chip, once.
    ///
    /// That setting replaced the built-in Enhance prompt entirely, so the
    /// Enhance button ran whatever was saved while still calling itself Enhance
    /// and still appending the Enhance target fragment. The reported case: a
    /// "text refinement engine ... never expand the text" prompt plus the Cursor
    /// fragment's "write a work order for a coding agent, reference file paths,
    /// name the command that must pass". The model got two opposite jobs in one
    /// system prompt and produced neither.
    ///
    /// A prompt on its own chip carries a name that says what it does, takes no
    /// target fragment, and leaves Enhance to be a prompt enhancer. Nothing is
    /// discarded: the prompt survives verbatim and stays editable under Actions.
    private func migrateLegacySkillPrompt(defaults: UserDefaults) {
        guard let legacy = defaults.string(forKey: Self.legacySkillPromptKey) else { return }
        // Cleared whether or not it converts, so the retired key cannot linger
        // and be picked up by a future reader.
        defer { defaults.removeObject(forKey: Self.legacySkillPromptKey) }

        guard let migrated = Self.migratedAction(fromLegacyPrompt: legacy, existing: customActions) else {
            return
        }
        customActions.append(migrated)
        persist()
    }

    /// The action a legacy prompt becomes, or nil if there is nothing to convert.
    /// Split out from the caller so the conversion can be tested without
    /// reaching into the singleton's initializer.
    static func migratedAction(
        fromLegacyPrompt legacy: String,
        existing: [EnhancementAction]
    ) -> EnhancementAction? {
        let trimmed = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Idempotent: if the key somehow reappears, don't add a second copy.
        guard !existing.contains(where: { $0.id == migratedSkillActionID }) else { return nil }

        return EnhancementAction(
            id: migratedSkillActionID,
            name: "My Skill",
            icon: "wand-sparkles",
            role: .enhance,
            systemPrompt: trimmed,
            isBuiltIn: false
        )
    }

    var allActions: [EnhancementAction] {
        Self.ordered([.grammar, .enhance] + customActions, by: actionOrder)
    }

    /// Built-ins first (Grammar, Enhance), then customs, unless `ids` names a
    /// saved chip order from Settings.
    static func ordered(_ actions: [EnhancementAction], by ids: [String]) -> [EnhancementAction] {
        let byID = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
        var seen = Set<String>()
        var result: [EnhancementAction] = []
        for id in ids {
            guard let action = byID[id], seen.insert(id).inserted else { continue }
            result.append(action)
        }
        for action in actions where seen.insert(action.id).inserted {
            result.append(action)
        }
        return result
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ids = allActions.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        actionOrder = ids
        persistOrder()
    }

    func action(withID id: String) -> EnhancementAction? {
        allActions.first { $0.id == id }
    }

    func addCustom(name: String, icon: String, systemPrompt: String) {
        let action = EnhancementAction(
            id: "custom-\(UUID().uuidString)",
            name: name,
            icon: icon,
            role: .enhance,
            systemPrompt: systemPrompt,
            isBuiltIn: false
        )
        customActions.append(action)
        if !actionOrder.isEmpty { actionOrder.append(action.id) }
        persist()
    }

    func updateCustom(_ action: EnhancementAction) {
        guard !action.isBuiltIn, let index = customActions.firstIndex(where: { $0.id == action.id }) else { return }
        customActions[index] = action
        persist()
    }

    func removeCustom(id: String) {
        customActions.removeAll { $0.id == id && !$0.isBuiltIn }
        actionOrder.removeAll { $0 == id }
        persist()
    }

    /// Serialises custom actions for sharing or import. Built-ins are excluded:
    /// they come from code, and round-tripping them through JSON would freeze a
    /// snapshot of the prompt as the shipped text.
    func exportCustomActions() -> Data? {
        guard !customActions.isEmpty else { return nil }
        return try? JSONEncoder().encode(customActions)
    }

    /// Merges a JSON array of custom actions into the registry, skipping any
    /// whose id already exists so a re-import doesn't duplicate. Returns the
    /// number added.
    @discardableResult
    func importCustomActions(from data: Data) -> Int {
        guard let decoded = try? JSONDecoder().decode([EnhancementAction].self, from: data) else {
            return 0
        }
        let existing = Set(customActions.map(\.id))
        let additions = decoded.filter { !$0.isBuiltIn && !existing.contains($0.id) }
        guard !additions.isEmpty else { return 0 }
        customActions.append(contentsOf: additions)
        if !actionOrder.isEmpty {
            actionOrder.append(contentsOf: additions.map(\.id))
        }
        persist()
        return additions.count
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customActions) {
            UserDefaults.standard.set(data, forKey: Self.customActionsKey)
        }
        persistOrder()
    }

    private func persistOrder() {
        UserDefaults.standard.set(actionOrder, forKey: Self.actionOrderKey)
    }
}
