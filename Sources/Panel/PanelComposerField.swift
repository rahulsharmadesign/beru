import AppKit
import SwiftUI

/// Multiline composer field: one line at rest, grows to three, then scrolls
/// inside a borderless scroll view. An AppKit text view on purpose — Return
/// must submit exactly like the old single-line field, while Option-Return
/// still breaks the line. SwiftUI's vertical `TextField` hands Return to the
/// text system and the panel's submit-on-Return dies with it.
struct ComposerTextField: NSViewRepresentable {
    @Binding var text: String
    var isFocused: Bool
    var font: NSFont = BeruType.bodyNSFont
    var maxLines: Int = 3
    var onSubmit: () -> Void
    var onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> ComposerScrollView {
        let textView = GrowingComposerTextView(frame: .zero)
        textView.font = font
        textView.onSubmit = onSubmit
        textView.delegate = context.coordinator
        let scroll = ComposerScrollView()
        scroll.minHeight = GrowingComposerTextView.oneLineHeight(for: font)
        scroll.maxHeight = GrowingComposerTextView.oneLineHeight(for: font) * CGFloat(maxLines)
        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: ComposerScrollView, context: Context) {
        guard let view = scroll.documentView as? GrowingComposerTextView else { return }
        view.onSubmit = onSubmit
        if view.string != text {
            view.string = text
            scroll.syncHeight()
        }
        if isFocused, scroll.window?.firstResponder != view {
            scroll.window?.makeFirstResponder(view)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextField

        init(parent: ComposerTextField) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard
                let view = notification.object as? GrowingComposerTextView,
                let scroll = view.enclosingScrollView as? ComposerScrollView
            else { return }
            parent.text = view.string
            scroll.syncHeight()
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
        }
    }
}

/// Borderless scroll host. Owns the height SwiftUI measures (one line at
/// rest, three at most) while the document view grows unbounded behind the
/// clip — so wheel scrolling, scroller, and caret follow are all native.
final class ComposerScrollView: NSScrollView {
    var minHeight: CGFloat = 16
    var maxHeight: CGFloat = 48

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        backgroundColor = .clear
        borderType = .noBorder
        hasVerticalScroller = true
        autohidesScrollers = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        guard let document = documentView as? GrowingComposerTextView else {
            return super.intrinsicContentSize
        }
        let height = ceil(min(max(document.contentHeight, minHeight), maxHeight))
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    func syncHeight() {
        invalidateIntrinsicContentSize()
        if let document = documentView as? GrowingComposerTextView {
            document.scrollRangeToVisible(document.selectedRange())
        }
    }
}

/// Single-font plain-text view that never swallows the panel's keys. Return
/// submits; Option-Return (insertLineBreak) falls through to a real newline;
/// Tab moves focus like a field.
final class GrowingComposerTextView: NSTextView {
    var onSubmit: () -> Void = {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configure()
    }

    /// TextKit advances lines by ascender + descender. Adding `leading` on
    /// top overshoots ~20% — that overshoot once let a fourth line slip past
    /// a three-line cap, so it lives here next to its only consumer.
    static func oneLineHeight(for font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender)
    }

    private func configure() {
        isRichText = false
        importsGraphics = false
        drawsBackground = false
        backgroundColor = .clear
        textColor = .labelColor
        insertionPointColor = BeruColor.accentNSColor
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        textContainerInset = .zero
        textContainer?.lineFragmentPadding = 0
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        minSize = NSSize(width: 0, height: 0)
        // Typed instructions must never gain smart quotes, dashes, links,
        // or completions on the way to the model.
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Plain Return submits — the panel's long-standing contract.
    override func insertNewline(_ sender: Any?) {
        onSubmit()
    }

    override func insertTab(_ sender: Any?) {
        window?.selectNextKeyView(self)
    }

    override func insertBacktab(_ sender: Any?) {
        window?.selectPreviousKeyView(self)
    }

    var contentHeight: CGFloat {
        if let layout = layoutManager, let container = textContainer {
            layout.ensureLayout(for: container)
            return layout.usedRect(for: container).height
        }
        if let manager = textLayoutManager {
            manager.ensureLayout(for: manager.documentRange)
            var height: CGFloat = 0
            manager.enumerateTextLayoutFragments(
                from: manager.documentRange.location,
                options: [.ensuresLayout]
            ) { fragment in
                height = max(height, fragment.layoutFragmentFrame.maxY)
                return true
            }
            return height
        }
        return 0
    }
}
