import SwiftUI

/// Renders a precomputed diff. The ops are calculated once, off the main
/// thread, when the grammar stream completes (see PanelEngine); this view only
/// converts them to a single AttributedString, so body evaluations stay cheap.
struct DiffView: View {
    let revised: String
    /// When false, omit the inner ScrollView so a parent (e.g. All Runs detail)
    /// can own scrolling. Nested scroll views leave half the pane empty.
    var scrolls: Bool
    private let attributed: AttributedString?

    init(ops: [DiffOp]?, revised: String, showDiff: Bool, scrolls: Bool = true) {
        self.revised = revised
        self.scrolls = scrolls
        if showDiff, let ops {
            self.attributed = Self.attributedString(from: ops)
        } else {
            self.attributed = nil
        }
    }

    var body: some View {
        Group {
            if scrolls {
                ScrollView { content.contributesPanelHeight() }
            } else {
                content
            }
        }
    }

    private var content: some View {
        Group {
            if let attributed {
                Text(attributed)
                    .font(BeruType.body)
            } else {
                Text(revised)
                    .font(BeruType.body)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, scrolls ? BeruSpace.md : 0)
        .padding(.vertical, scrolls ? BeruSpace.md : 0)
    }

    private static func attributedString(from ops: [DiffOp]) -> AttributedString {
        var result = AttributedString()
        for op in ops {
            switch op {
            case .equal(let s):
                result += AttributedString(s)
            case .deletion(let s):
                var segment = AttributedString(s)
                segment.foregroundColor = BeruColor.destructive
                segment.strikethroughStyle = .init(pattern: .solid, color: BeruColor.destructive)
                result += segment
            case .insertion(let s):
                var segment = AttributedString(s)
                segment.foregroundColor = BeruColor.positive
                segment.underlineStyle = .init(pattern: .solid, color: BeruColor.positive)
                result += segment
            }
        }
        return result
    }
}
