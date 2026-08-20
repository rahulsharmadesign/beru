import Foundation
import Observation

// Reusable context — rules, playbooks, workspaces and glossary — that the
// prompt chain layers onto a request. Shared a file with the unrelated
// markdown profile registry purely because both are prompt inputs.

struct ContextRule: Identifiable, Codable, Equatable, Sendable {
    enum Scope: String, Codable, CaseIterable, Sendable { case global, action, target }
    var id: String
    var name: String
    var instruction: String
    var scope: Scope
    var actionID: String?
    var targetID: String?
    var enabled: Bool
    init(id: String = "rule-\(UUID().uuidString)", name: String, instruction: String = "", scope: Scope = .global, actionID: String? = nil, targetID: String? = nil, enabled: Bool = true) {
        self.id = id; self.name = name; self.instruction = instruction
        self.scope = scope; self.actionID = actionID; self.targetID = targetID; self.enabled = enabled
    }
    var isEmpty: Bool { instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func applies(actionID: String, targetID: String) -> Bool {
        guard enabled && !isEmpty else { return false }
        switch scope { case .global: return true; case .action: return self.actionID == actionID; case .target: return self.targetID == targetID }
    }
}

struct ContextPlaybook: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var instructions: String
    init(id: String = "playbook-\(UUID().uuidString)", name: String, instructions: String = "") {
        self.id = id; self.name = name; self.instructions = instructions
    }
    var isEmpty: Bool { instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    static let starter = ContextPlaybook(id: "playbook-client", name: "Client communication", instructions: "Use a courteous, direct, and confident tone. Preserve names, dates, commitments, and factual details exactly. Do not invent commitments, timelines, or policy details. Return a ready-to-send response only.")
}

struct ContextWorkspace: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var memory: String
    init(id: String = "workspace-\(UUID().uuidString)", name: String, memory: String = "") {
        self.id = id; self.name = name; self.memory = memory
    }
    var hasMemory: Bool { !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    static let personal = ContextWorkspace(id: "workspace-personal", name: "Personal")
}

struct GlossaryTerm: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var preferred: String
    var aliases: String
    var note: String
    init(id: String = "glossary-\(UUID().uuidString)", preferred: String = "", aliases: String = "", note: String = "") {
        self.id = id; self.preferred = preferred; self.aliases = aliases; self.note = note
    }
    var isEmpty: Bool { preferred.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct ContextApplication: Equatable, Sendable {
    static let empty = ContextApplication(workspace: nil, playbook: nil, rules: [], glossary: [])
    var workspace: ContextWorkspace?
    var playbook: ContextPlaybook?
    var rules: [ContextRule]
    var glossary: [GlossaryTerm]
    var appliedNames: [String] {
        var names: [String] = []
        if let workspace, workspace.hasMemory { names.append(workspace.name) }
        if let playbook, !playbook.isEmpty { names.append(playbook.name) }
        names.append(contentsOf: rules.map(\.name))
        if !glossary.isEmpty { names.append("Glossary") }
        return names
    }
    var isEmpty: Bool { appliedNames.isEmpty }
    var instructionBlock: String {
        guard !isEmpty else { return "" }
        var blocks = ["USER-SELECTED CONTEXT — apply only when it does not conflict with the current request."]
        if let workspace, workspace.hasMemory { blocks.append("WORKSPACE (\(workspace.name)):\n\(workspace.memory)") }
        if let playbook, !playbook.isEmpty { blocks.append("PLAYBOOK (\(playbook.name)):\n\(playbook.instructions)") }
        if !rules.isEmpty { blocks.append("RULES:\n" + rules.map { "- \($0.instruction)" }.joined(separator: "\n")) }
        let terms = glossary.filter { !$0.isEmpty }.map { term in
            "- Prefer '\(term.preferred)'" + (term.aliases.isEmpty ? "" : "; aliases: \(term.aliases)") + (term.note.isEmpty ? "" : "; \(term.note)")
        }
        if !terms.isEmpty { blocks.append("LOCAL GLOSSARY:\n" + terms.joined(separator: "\n")) }
        return blocks.joined(separator: "\n\n")
    }
}

@MainActor
@Observable
final class ContextLibrary {
    static let shared = ContextLibrary()
    private enum Key {
        static let playbooks = "contextPlaybooks"
        static let activePlaybook = "activeContextPlaybookID"
        static let rules = "contextRules"
        static let workspaces = "contextWorkspaces"
        static let activeWorkspace = "activeContextWorkspaceID"
        static let glossary = "contextGlossary"
    }
    private let defaults: UserDefaults
    private(set) var playbooks: [ContextPlaybook]
    private(set) var rules: [ContextRule]
    private(set) var workspaces: [ContextWorkspace]
    private(set) var glossary: [GlossaryTerm]
    private(set) var activePlaybookID: String?
    private(set) var activeWorkspaceID: String?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        playbooks = Self.load([ContextPlaybook].self, Key.playbooks, defaults) ?? [.starter]
        rules = Self.load([ContextRule].self, Key.rules, defaults) ?? []
        workspaces = Self.load([ContextWorkspace].self, Key.workspaces, defaults) ?? [.personal]
        glossary = Self.load([GlossaryTerm].self, Key.glossary, defaults) ?? []
        activePlaybookID = defaults.string(forKey: Key.activePlaybook)
        activeWorkspaceID = defaults.string(forKey: Key.activeWorkspace) ?? ContextWorkspace.personal.id
        if !playbooks.contains(where: { $0.id == activePlaybookID }) { activePlaybookID = nil }
        if !workspaces.contains(where: { $0.id == activeWorkspaceID }) { activeWorkspaceID = workspaces.first?.id }
        persist()
    }

    var activePlaybook: ContextPlaybook? { playbooks.first { $0.id == activePlaybookID } }
    var activeWorkspace: ContextWorkspace? { workspaces.first { $0.id == activeWorkspaceID } }

    func setActivePlaybook(_ id: String?) { activePlaybookID = id == activePlaybookID ? nil : id; persist() }
    func setActiveWorkspace(_ id: String) { guard workspaces.contains(where: { $0.id == id }) else { return }; activeWorkspaceID = id; persist() }

    @discardableResult func addPlaybook(name: String = "New playbook") -> ContextPlaybook {
        let item = ContextPlaybook(name: name); playbooks.append(item); persist(); return item
    }
    func update(_ item: ContextPlaybook) { if let index = playbooks.firstIndex(where: { $0.id == item.id }) { playbooks[index] = item; persist() } }
    func removePlaybook(id: String) { playbooks.removeAll { $0.id == id }; if activePlaybookID == id { activePlaybookID = nil }; persist() }

    @discardableResult func addRule(name: String = "New rule") -> ContextRule {
        let item = ContextRule(name: name); rules.append(item); persist(); return item
    }
    func update(_ item: ContextRule) { if let index = rules.firstIndex(where: { $0.id == item.id }) { rules[index] = item; persist() } }
    func removeRule(id: String) { rules.removeAll { $0.id == id }; persist() }

    @discardableResult func addWorkspace(name: String = "New workspace") -> ContextWorkspace {
        let item = ContextWorkspace(name: name); workspaces.append(item); persist(); return item
    }
    func update(_ item: ContextWorkspace) { if let index = workspaces.firstIndex(where: { $0.id == item.id }) { workspaces[index] = item; persist() } }
    func removeWorkspace(id: String) {
        guard workspaces.count > 1 else { return }
        workspaces.removeAll { $0.id == id }
        if activeWorkspaceID == id { activeWorkspaceID = workspaces.first?.id }
        persist()
    }

    @discardableResult func addGlossaryTerm() -> GlossaryTerm {
        let item = GlossaryTerm(); glossary.append(item); persist(); return item
    }
    func update(_ item: GlossaryTerm) { if let index = glossary.firstIndex(where: { $0.id == item.id }) { glossary[index] = item; persist() } }
    func removeGlossaryTerm(id: String) { glossary.removeAll { $0.id == id }; persist() }

    func application(actionID: String, targetID: String) -> ContextApplication {
        ContextApplication(workspace: activeWorkspace, playbook: activePlaybook, rules: rules.filter { $0.applies(actionID: actionID, targetID: targetID) }, glossary: glossary.filter { !$0.isEmpty })
    }

    private func persist() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(playbooks) { defaults.set(data, forKey: Key.playbooks) }
        if let data = try? encoder.encode(rules) { defaults.set(data, forKey: Key.rules) }
        if let data = try? encoder.encode(workspaces) { defaults.set(data, forKey: Key.workspaces) }
        if let data = try? encoder.encode(glossary) { defaults.set(data, forKey: Key.glossary) }
        defaults.set(activePlaybookID, forKey: Key.activePlaybook)
        defaults.set(activeWorkspaceID, forKey: Key.activeWorkspace)
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String, _ defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
