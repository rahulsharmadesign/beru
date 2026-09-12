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

/// Live result print: words appear one by one with a caret, the newest
/// resolving out of blur. Finished answers pass `isLive: false` so Search
/// history does not replay. Reduce Motion shows the full string.
struct StreamingPrintedText: View {
    let text: String
    var isLive: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedCount = 0
    @State private var caretOn = true
    @State private var newestBlur: CGFloat = 0

    private var tokens: [String] { StreamingPrint.tokens(in: text) }

    private var revealed: String {
        StreamingPrint.prefix(tokens, count: min(revealedCount, tokens.count))
    }

    private var newest: String {
        guard revealedCount > 0, revealedCount <= tokens.count else { return "" }
        return tokens[revealedCount - 1]
    }

    private var shouldType: Bool {
        isLive && !reduceMotion
    }

    private var tickID: Int {
        shouldType && revealedCount < tokens.count ? revealedCount : -1
    }

    var body: some View {
        (Text(revealed) + caret)
            .beruPrintedText()
            .foregroundStyle(BeruColor.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textRenderer(
                NewestWordRenderer(
                    blurRadius: newestBlur,
                    newestCount: shouldType ? newest.count : 0
                )
            )
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
            .foregroundStyle(BeruColor.textPrimary.opacity(caretOn ? 1 : 0))
    }

    private func syncReveal(for new: String) {
        let count = StreamingPrint.tokens(in: new).count
        if !shouldType {
            revealedCount = count
            newestBlur = 0
            return
        }
        if count < revealedCount {
            revealedCount = 0
            newestBlur = 0
        }
    }

    private func tick() async {
        guard tickID >= 0 else { return }
        try? await Task.sleep(for: .seconds(BeruMotion.typewriterWord))
        guard !Task.isCancelled else { return }
        revealedCount = min(revealedCount + 1, tokens.count)
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) { newestBlur = BeruSpace.xxs }
        withAnimation(.easeOut(duration: BeruMotion.typewriterBlur)) {
            newestBlur = 0
        }
    }

    private func blinkCaret() async {
        guard shouldType else { return }
        caretOn = true
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(BeruMotion.typewriterCaret))
            guard !Task.isCancelled else { return }
            caretOn.toggle()
        }
    }
}

/// Blurs only the newest word (and the caret sitting on it) so already-printed
/// copy stays sharp. Animatable so the radius eases to zero.
private struct NewestWordRenderer: TextRenderer, Animatable {
    var blurRadius: CGFloat
    var newestCount: Int

    var animatableData: CGFloat {
        get { blurRadius }
        set { blurRadius = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let runs = layout.flatMap { Array($0) }
        let total = runs.reduce(0) { $0 + $1.count }
        let blurAfter = max(0, total - max(newestCount, 0))
        var index = 0
        for run in runs {
            var copy = context
            if blurRadius > 0, index + run.count > blurAfter {
                copy.addFilter(.blur(radius: blurRadius))
            }
            copy.draw(run)
            index += run.count
        }
    }
}
