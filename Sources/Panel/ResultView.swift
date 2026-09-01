import SwiftUI

struct ResultView: View {
    let state: ResultState
    /// AI Search answers render as markdown (headings, bold, links). Other
    /// actions stay plain so prompt hashes like `# Task` are not restyled.
    var usesMarkdown: Bool = false

    var body: some View {
        Group {
            if state == .idle {
                Color.clear
            } else if state == .loading {
                // Declared height so the window has something to size to before
                // any text arrives. No ScrollView — the panel sizes to content.
                BeruLoader()
                    .frame(
                        maxWidth: .infinity,
                        minHeight: PanelMetrics.resultPlaceholderHeight,
                        alignment: .center
                    )
            } else if state == .thinking {
                VStack(spacing: BeruSpace.xs) {
                    BeruLoader()
                    Text("Thinking…")
                        .font(BeruType.caption)
                        .foregroundStyle(BeruColor.textSecondary)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: PanelMetrics.resultPlaceholderHeight,
                    alignment: .center
                )
            } else if case .streaming(let text) = state {
                streamingText(text)
            } else if case .done(let text) = state {
                streamingText(text, isDone: true)
            } else if case .error(let message) = state {
                Text(message)
                    .font(BeruType.body)
                    .foregroundStyle(BeruColor.textSecondary)
            }
        }
    }

    /// Expands with the text so the panel window can grow. Parent scrolls
    /// once `PanelController` hits the 75% viewport cap.
    @ViewBuilder
    private func streamingText(_ text: String, isDone: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if usesMarkdown {
                BeruMarkdown(text: text)
            } else {
                Text(isDone ? text : text)
                    .font(BeruType.resultBody)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, BeruSpace.md)
        .padding(.vertical, BeruSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
