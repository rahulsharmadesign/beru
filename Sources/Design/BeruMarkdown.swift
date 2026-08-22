import SwiftUI

/// Shared markdown renderer for AI Search answers and the vault preview.
///
/// Headings, bold, and links are styled from `BeruType` / `BeruColor` so both
/// surfaces share one scale. Layout is a vertical stack of blocks — not a web
/// stylesheet — so the panel still sizes from intrinsic height.
struct BeruMarkdown: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let content):
                    Text(inline(content))
                        .font(Self.headingFont(level))
                        .foregroundStyle(BeruColor.textPrimary)
                        .padding(.top, level == 1 ? BeruSpace.xxs : 0)
                case .bullet(let content):
                    HStack(alignment: .firstTextBaseline, spacing: BeruSpace.xs) {
                        Text("•")
                            .font(BeruType.resultBodyBold)
                            .foregroundStyle(BeruColor.textSecondary)
                        Text(inline(content))
                            .font(BeruType.resultBody)
                            .foregroundStyle(BeruColor.textPrimary)
                    }
                case .paragraph(let content):
                    Text(inline(content))
                        .font(BeruType.resultBody)
                        .foregroundStyle(BeruColor.textPrimary)
                case .blank:
                    Color.clear.frame(height: BeruSpace.hair)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return BeruType.heading1
        case 2: return BeruType.heading2
        default: return BeruType.heading3
        }
    }

    private enum Block {
        case heading(Int, String)
        case bullet(String)
        case paragraph(String)
        case blank
    }

    private var blocks: [Block] {
        text.components(separatedBy: .newlines).map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return .blank }
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                return .heading(
                    hashes,
                    String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
                )
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return .bullet(String(trimmed.dropFirst(2)))
            }
            return .paragraph(trimmed)
        }
    }

    private func inline(_ content: String) -> AttributedString {
        var attributed = (try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(content)
        for run in attributed.runs where run.link != nil {
            attributed[run.range].foregroundColor = BeruColor.link
            attributed[run.range].underlineStyle = .single
        }
        return attributed
    }
}
