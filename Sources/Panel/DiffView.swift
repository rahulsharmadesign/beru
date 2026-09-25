import SwiftUI

/// Renders a precomputed diff. The ops are calculated once, off the main
/// thread, when the grammar stream completes (see PanelEngine); this view only
/// converts them to a single AttributedString, so body evaluations stay cheap.
struct DiffView: View {
    /// `.full` shows deletions struck through in red and insertions in green.
    /// `.clean` reads like the finished text: deletions are hidden and changed
    /// words carry only a faint dotted underline — the panel's default,
    /// because a heavy rewrite in `.full` is hard to read.
    enum Style {
        case full
        case clean
    }

    let revised: String
    /// When false, omit the inner ScrollView so a parent (e.g. All Runs detail)
    /// can own scrolling. Nested scroll views leave half the pane empty.
    var scrolls: Bool
    private let attributed: AttributedString?

    init(ops: [DiffOp]?, revised: String, showDiff: Bool, scrolls: Bool = true, style: Style = .full) {
        self.revised = revised
        self.scrolls = scrolls
        if showDiff, let ops {
            self.attributed = style == .clean
                ? Self.cleanAttributedString(from: ops)
                : Self.attributedString(from: ops)
        } else {
            self.attributed = nil
        }
    }

    var body: some View {
        Group {
            if scrolls {
                ScrollView { content }
            } else {
                content
            }
        }
    }

    private var content: some View {
        Group {
            if let attributed {
                Text(attributed)
                    .enhancifyPrintedText()
            } else {
                Text(revised)
                    .enhancifyPrintedText()
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func attributedString(from ops: [DiffOp]) -> AttributedString {
        var result = AttributedString()
        var previousWasDeletion = false
        for op in ops {
            // A replacement ("FOr" → "For") rendered back to back read as one
            // mangled word; a space between the struck and new text splits it.
            if case .insertion = op, previousWasDeletion {
                result += AttributedString(" ")
            }
            if case .deletion = op { previousWasDeletion = true } else { previousWasDeletion = false }
            switch op {
            case .equal(let s):
                result += AttributedString(s)
            case .deletion(let s):
                var segment = AttributedString(s)
                segment.foregroundColor = EnhancifyColor.destructive
                segment.strikethroughStyle = .init(pattern: .solid, color: EnhancifyColor.destructive)
                result += segment
            case .insertion(let s):
                var segment = AttributedString(s)
                segment.foregroundColor = EnhancifyColor.positive
                segment.underlineStyle = .init(pattern: .solid, color: EnhancifyColor.positive)
                result += segment
            }
        }
        return result
    }

    private static func cleanAttributedString(from ops: [DiffOp]) -> AttributedString {
        var result = AttributedString()
        for op in ops {
            switch op {
            case .equal(let s):
                result += AttributedString(s)
            case .deletion:
                continue
            case .insertion(let s):
                // Mark only the words, not the spaces around them.
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let range = s.range(of: trimmed) else {
                    result += AttributedString(s)
                    continue
                }
                result += AttributedString(String(s[..<range.lowerBound]))
                var word = AttributedString(trimmed)
                word.underlineStyle = .init(pattern: .dot, color: EnhancifyColor.textTertiary)
                result += word
                result += AttributedString(String(s[range.upperBound...]))
            }
        }
        return result
    }
}
