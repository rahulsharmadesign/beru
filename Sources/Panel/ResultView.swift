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
                // A declared height rather than filling the parent, so the
                // window has something to size to before any text arrives.
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: PanelMetrics.resultPlaceholderHeight)
                    .contributesPanelHeight()
            } else if state == .thinking {
                VStack(spacing: BeruSpace.xs) {
                    Text("Thinking…")
                        .font(BeruType.caption)
                        .foregroundStyle(BeruColor.textSecondary)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: PanelMetrics.resultPlaceholderHeight,
                    alignment: .center
                )
                .contributesPanelHeight()
            } else if case .streaming(let text) = state {
                streamingText(text)
            } else if case .done(let text) = state {
                streamingText(text, isDone: true)
            } else if case .error(let message) = state {
                Text(message)
                    .font(BeruType.body)
                    .foregroundStyle(BeruColor.textSecondary)
                    .contributesPanelHeight()
            }
        }
    }

    @ViewBuilder
    private func streamingText(_ text: String, isDone: Bool = false) -> some View {
        ScrollView {
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
            // Reported from inside the scroll view: this is the text's natural
            // height, which is what the window needs in order to show it all.
            .contributesPanelHeight()
        }
    }
}