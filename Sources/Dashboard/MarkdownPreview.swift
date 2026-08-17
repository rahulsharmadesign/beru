import SwiftUI

struct MarkdownPreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let content):
                    Text(inline(content))
                        .font(level == 1 ? BeruSans.pageTitle : BeruSans.section)
                        .foregroundStyle(SettingsTheme.textPrimary)
                        .padding(.top, 4)
                case .bullet(let content):
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("•").foregroundStyle(SettingsTheme.textSecondary)
                        Text(inline(content))
                            .font(BeruSans.control)
                            .foregroundStyle(SettingsTheme.textPrimary)
                    }
                case .paragraph(let content):
                    Text(inline(content))
                        .font(BeruSans.control)
                        .foregroundStyle(SettingsTheme.textPrimary)
                case .blank:
                    Color.clear.frame(height: 2)
                }
            }
        }
        .textSelection(.enabled)
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
                return .heading(hashes, String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces))
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return .bullet(String(trimmed.dropFirst(2)))
            }
            return .paragraph(trimmed)
        }
    }

    private func inline(_ content: String) -> AttributedString {
        (try? AttributedString(markdown: content)) ?? AttributedString(content)
    }
}
