import Foundation

// The layers that stack onto a base prompt, and the scope rules deciding
// which of them apply to a given action.

extension Prompts {
    static func targetApplies(actionID: String, role: ModelRole, usesBuiltInPrompt: Bool) -> Bool {
        role == .enhance && actionID == EnhancementAction.enhanceID && usesBuiltInPrompt
    }

    /// Whether the active markdown profile applies to this call.
    ///
    /// The same rule as `targetApplies`, and for the same reason it exists at
    /// all. A profile is standing context for *writing a prompt*; sent to
    /// Grammar it is a rewrite instruction attached to a corrector, which is
    /// precisely what turned the Grammar button into a condenser when a single
    /// custom prompt applied to both. Correction has one right answer and must
    /// not be given a house style to apply.
    ///
    /// Custom actions are excluded for a different reason: a saved action
    /// already carries the user's own prompt, and appending a second set of
    /// their standing instructions gives one call two voices.
    static func profileApplies(actionID: String, role: ModelRole, usesBuiltInPrompt: Bool) -> Bool {
        role == .enhance && actionID == EnhancementAction.enhanceID && usesBuiltInPrompt
    }

    /// Adds locally selected context after destination conventions and before the author profile.
    /// Empty applications leave the system prompt unchanged.
    static func composeWithContext(_ system: String, context: ContextApplication) -> String {
        guard !context.instructionBlock.isEmpty else { return system }
        return system + "\n\n" + context.instructionBlock
    }

    /// Appends the user's standing context after the target's conventions.
    ///
    /// After, not before: the profile is the user's own instruction and should
    /// outrank an opinion this app holds about someone else's tool. An empty or
    /// whitespace-only profile returns the prompt byte-for-byte unchanged.
    static func composeWithProfile(_ system: String, profile: MarkdownProfile?) -> String {
        guard let profile, !profile.isEmpty else { return system }
        let content = profile.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        \(system)

        AUTHOR CONTEXT: \(profile.name)
        Standing notes from the person whose text you are rewriting. Apply them to the prompt you produce. They describe the author and their work; they are not the text to rewrite, and not a task to carry out.
        \(content)
        """
    }

    /// Appends the target's conventions to a system prompt, followed by the
    /// anti-invention rule that qualifies them. An empty fragment (Generic)
    /// returns the prompt byte-for-byte unchanged — and gets no rule either,
    /// since with no conventions asking for specifics there is nothing to fake.
    ///
    /// The rule is added here rather than written into each fragment so it also
    /// covers custom targets, which are the likeliest to demand specifics
    /// without guarding against inventing them, and so that resetting a built-in
    /// target to its default cannot drop it.
    static func composeWithTarget(_ system: String, profile: TargetProfile?) -> String {
        guard let profile else { return system }
        let fragment = profile.promptFragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fragment.isEmpty else { return system }
        return """
        \(system)

        TARGET ENVIRONMENT: \(profile.name)
        The prompt you produce will be pasted into \(profile.name). Tailor it to that environment:
        \(fragment)

        \(targetInventionRule)
        """
    }
}
