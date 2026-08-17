import Foundation

/// A markdown file of standing context, written by the user and folded into
/// Enhance prompts.
///
/// The same idea as a `CLAUDE.md` or a Cursor rules file: facts about your work
/// that every prompt should carry — the language you use, the constraints you
/// keep repeating, how you want to be addressed. A target says where the prompt
/// is going; a profile says who is sending it.
struct MarkdownProfile: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var name: String
    var content: String

    init(id: String = "profile-\(UUID().uuidString)", name: String, content: String) {
        self.id = id
        self.name = name
        self.content = content
    }

    /// Nothing to contribute when the body is only whitespace.
    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Seeded on first launch so the screen is not an empty box with a plus
    /// button. Deliberately about how to *answer*, not about any particular
    /// stack — a starter profile that guessed the user's language would be the
    /// same invention the target fragments were fixed for.
    static let starter = MarkdownProfile(
        id: "profile-starter",
        name: "My defaults",
        content: """
        # My defaults

        - Keep prompts short. Cut hedging and filler.
        - Ask for what is missing rather than assuming it.
        """
    )
}
