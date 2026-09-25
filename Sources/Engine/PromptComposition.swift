import Foundation

// The target layer that stacks onto the Enhance prompt.

extension Prompts {
    /// Target conventions apply to the built-in Enhance prompt only.
    static func targetApplies(actionID: String) -> Bool {
        actionID == EnhancementAction.enhanceID
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
