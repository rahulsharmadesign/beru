import SwiftUI

/// Word tokens for the panel typewriter. Trailing whitespace stays on the
/// token so joining reconstructs the source (newlines included).
enum StreamingPrint {
    static func tokens(in text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character.isWhitespace {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    static func prefix(_ tokens: [String], count: Int) -> String {
        tokens.prefix(max(0, count)).joined()
    }
}

/// Live result print: words appear one by one with a caret — a plain
/// typewriter, no blur. Finished answers pass `isLive: false` so Search
/// history does not replay. Reduce Motion shows the full string.
struct StreamingPrintedText: View {
    let text: String
    var isLive: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedCount = 0
    @State private var caretOn = true

    private var tokens: [String] { StreamingPrint.tokens(in: text) }

    private var revealed: String {
        StreamingPrint.prefix(tokens, count: min(revealedCount, tokens.count))
    }

    private var shouldType: Bool {
        isLive && !reduceMotion
    }

    private var tickID: Int {
        shouldType && revealedCount < tokens.count ? revealedCount : -1
    }

    var body: some View {
        (Text(revealed) + caret)
            .enhancifyPrintedText()
            .foregroundStyle(EnhancifyColor.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: text, initial: true) { _, new in
                syncReveal(for: new)
            }
            .onChange(of: isLive, initial: true) { _, _ in
                syncReveal(for: text)
            }
            .task(id: tickID) { await tick() }
            .task(id: shouldType) { await blinkCaret() }
    }

    private var caret: Text {
        guard shouldType else { return Text("") }
        return Text("▌")
            .foregroundStyle(EnhancifyColor.textPrimary.opacity(caretOn ? 1 : 0))
    }

    private func syncReveal(for new: String) {
        let count = StreamingPrint.tokens(in: new).count
        if !shouldType {
            revealedCount = count
            return
        }
        if count < revealedCount {
            revealedCount = 0
        }
    }

    private func tick() async {
        guard tickID >= 0 else { return }
        try? await Task.sleep(for: .seconds(EnhancifyMotion.typewriterWord))
        guard !Task.isCancelled else { return }
        revealedCount = min(revealedCount + 1, tokens.count)
    }

    private func blinkCaret() async {
        guard shouldType else { return }
        caretOn = true
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(EnhancifyMotion.typewriterCaret))
            guard !Task.isCancelled else { return }
            caretOn.toggle()
        }
    }
}
