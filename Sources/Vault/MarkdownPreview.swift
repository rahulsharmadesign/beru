import SwiftUI

struct MarkdownPreview: View {
    let text: String

    var body: some View {
        BeruMarkdown(text: text)
    }
}
