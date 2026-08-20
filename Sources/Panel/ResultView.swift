import SwiftUI

struct ResultView: View {
    let state: ResultState

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
                VStack(spacing: 8) {
                    Text("Thinking…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
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
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .contributesPanelHeight()
            }
        }
    }

    @ViewBuilder
    private func streamingText(_ text: String, isDone: Bool = false) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(isDone ? text : text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            // Reported from inside the scroll view: this is the text's natural
            // height, which is what the window needs in order to show it all.
            .contributesPanelHeight()
        }
    }
}