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
                StreamingPrintedText(text: text, isLive: true)
            } else if case .done(let text) = state {
                if usesMarkdown {
                    BeruMarkdown(text: text)
                } else {
                    StreamingPrintedText(text: text, isLive: false)
                }
            } else if case .error(let message) = state {
                Text(message)
                    .beruPrintedText()
                    .foregroundStyle(BeruColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
