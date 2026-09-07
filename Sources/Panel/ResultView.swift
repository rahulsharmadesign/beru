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
                PixelGridLoader(variant: .dots)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: PanelMetrics.resultPlaceholderHeight,
                        alignment: .center
                    )
            } else if state == .thinking {
                PixelLoadingState(label: "Thinking…")
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
                    .font(BeruType.resultBody)
                    .foregroundStyle(BeruColor.textSecondary)
            }
        }
    }

    /// Expands with the text so the panel window can grow. Parent scrolls
    /// once `PanelController` hits the 75% viewport cap. No inner padding:
    /// the module inset is the single frame, so text aligns edge to edge.
    ///
    /// A live answer renders as plain text and only gains markdown on `.done`.
    /// Re-parsing block structure per chunk pops measured height — a lone `#`
    /// arrives as a tall padded heading, `-` flips paragraph to bullet row —
    /// and every pop resized the window mid-stream, bouncing the composer.
    /// Plain-text line layout grows monotonically, so growth steps stay tiny.
    @ViewBuilder
    private func streamingText(_ text: String, isDone: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if usesMarkdown && isDone {
                BeruMarkdown(text: text)
            } else {
                Text(text)
                    .font(BeruType.resultBody)
                    .foregroundStyle(BeruColor.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
