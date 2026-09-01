import SwiftUI

/// Shared markdown renderer for AI Search answers and the vault preview.
///
/// Headings, bold, and links are styled from `BeruType` / `BeruColor` so both
/// surfaces share one scale. Layout is a vertical stack of blocks — not a web
/// stylesheet — so the panel still sizes from intrinsic height.
struct BeruMarkdown: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xxs) {
            ForEach(Array(Self.parse(text).enumerated()), id: \.offset) { index, block in
                switch block {
                case .heading(let level, let content):
                    Text(inline(content))
                        .font(Self.headingFont(level))
                        .foregroundStyle(BeruColor.textPrimary)
                        .padding(.top, index == 0 ? 0 : Self.headingTopPadding(level))
                        .padding(.bottom, BeruSpace.xxs)
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
                case .gap:
                    Color.clear.frame(height: BeruSpace.sm)
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

    static func headingTopPadding(_ level: Int) -> CGFloat {
        level <= 1 ? BeruSpace.md : BeruSpace.sm
    }

    enum Block: Equatable {
        case heading(Int, String)
        case bullet(String)
        case paragraph(String)
        case gap
    }

    /// Line-based ATX headings and `- ` / `* ` bullets. Consecutive blank
    /// lines collapse to a single paragraph gap.
    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var pendingGap = false
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !blocks.isEmpty { pendingGap = true }
                continue
            }
            if pendingGap {
                blocks.append(.gap)
                pendingGap = false
            }
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                blocks.append(.heading(
                    hashes,
                    String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
                ))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(.bullet(String(trimmed.dropFirst(2))))
            } else {
                blocks.append(.paragraph(trimmed))
            }
        }
        return blocks
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
