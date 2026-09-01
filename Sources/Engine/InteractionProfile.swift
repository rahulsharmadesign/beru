import Foundation

/// On-device preferences inferred from Insert / Replace / Copy. Not usage
/// history: no full documents, no extra disk folder, never Keychain.
struct InteractionProfile: Equatable, Codable, Sendable {
    var lastReplyTone: String?
    var lastGrammarKind: String?
    var lastEnhanceTargetName: String?
    var lastEnhanceInstruction: String?

    static let instructionBudget = 160
    static let blockCharBudget = 400

    var isEmpty: Bool {
        lastReplyTone == nil
            && lastGrammarKind == nil
            && (lastEnhanceTargetName?.isEmpty ?? true)
            && (lastEnhanceInstruction?.isEmpty ?? true)
    }

    var preferredGrammarKind: GrammarKind? {
        lastGrammarKind.flatMap(GrammarKind.init(rawValue:))
    }

    mutating func recordAccepted(
        actionID: String,
        replyTone: ReplyTone?,
        grammarKind: GrammarKind?,
        targetName: String?,
        instruction: String?
    ) {
        if actionID == EnhancementAction.replyID, let replyTone {
            lastReplyTone = replyTone.rawValue
        }
        if actionID == EnhancementAction.grammarID, let grammarKind {
            lastGrammarKind = grammarKind.rawValue
        }
        if actionID == EnhancementAction.enhanceID {
            if let targetName {
                let trimmed = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { lastEnhanceTargetName = trimmed }
            }
            if let instruction {
                let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lastEnhanceInstruction = SessionThread.clip(trimmed, to: Self.instructionBudget)
                }
            }
        }
    }

    func promptBlock(actionID: String) -> String? {
        if actionID == EnhancementAction.grammarID { return nil }
        var lines: [String] = []
        if actionID == EnhancementAction.replyID,
           let raw = lastReplyTone,
           let tone = ReplyTone(rawValue: raw) {
            lines.append(
                "This person usually sends \(tone.title) replies when they Insert. Prefer that humour density on Funny and Witty; still honor the six-tone catalog."
            )
        }
        if actionID == EnhancementAction.enhanceID {
            if let name = lastEnhanceTargetName, !name.isEmpty {
                lines.append(
                    "Recent accepted destination was \(name). That is a prior, not an override of the current target."
                )
            }
            if let instruction = lastEnhanceInstruction, !instruction.isEmpty {
                lines.append("Recent accepted follow-up instructions looked like: \(instruction)")
            }
        }
        guard !lines.isEmpty else { return nil }
        var block = "LEARNED PREFERENCES\n" + lines.joined(separator: "\n")
        if block.count > Self.blockCharBudget {
            block = String(block.prefix(Self.blockCharBudget - 1)) + "…"
        }
        return block
    }
}

extension Prompts {
    /// After context and thread, before the author profile. Empty profiles
    /// leave the system prompt byte-identical. Grammar never receives this.
    static func composeWithInteractionProfile(_ system: String, profile: InteractionProfile, actionID: String) -> String {
        guard let block = profile.promptBlock(actionID: actionID) else { return system }
        return """
        \(system)

        \(block)
        """
    }
}
