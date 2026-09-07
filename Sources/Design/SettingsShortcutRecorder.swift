import AppKit
import SwiftUI
import KeyboardShortcuts

// Shortcut recorder inside a Haze field well. `KeyboardShortcuts.RecorderCocoa`
// is an `NSSearchField`; its system bezel, search glyph, and clear round are
// stripped so the well paints the look instead.
//
// Root cause of past misalignment: an NSSearchField centers its text through
// its bezel's layout logic. With the bezel stripped, the cell paints the
// string at the top of its bounds like a plain text cell, so the control is
// sized to exactly one text line (`recorderTextHeight`) and centered in the
// 32pt well by its constraints.

public struct SettingsShortcutRecorder: View {
    let name: KeyboardShortcuts.Name

    public init(name: KeyboardShortcuts.Name) {
        self.name = name
    }

    public var body: some View {
        RecorderField(name: name)
            .frame(width: BeruMetrics.fieldWidth, height: BeruMetrics.fieldHeight)
            .background {
                Capsule()
                    .fill(BeruColor.subtleFill)
                    .overlay {
                        Capsule().strokeBorder(BeruColor.border, lineWidth: BeruMetrics.hairline)
                    }
            }
    }
}

private struct RecorderField: NSViewRepresentable {
    let name: KeyboardShortcuts.Name

    func makeNSView(context: Context) -> RecorderHost {
        RecorderHost(name: name)
    }

    func updateNSView(_ host: RecorderHost, context: Context) {
        host.recorder.shortcutName = name
    }
}

private final class RecorderHost: NSView {
    let recorder: KeyboardShortcuts.RecorderCocoa

    init(name: KeyboardShortcuts.Name) {
        recorder = KeyboardShortcuts.RecorderCocoa(for: name)
        super.init(frame: .zero)
        recorder.focusRingType = .none
        recorder.isBezeled = false
        recorder.drawsBackground = false
        recorder.alignment = .center
        recorder.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        if let cell = recorder.cell as? NSSearchFieldCell {
            cell.searchButtonCell = nil
            cell.cancelButtonCell = nil
        }
        recorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(recorder)
        NSLayoutConstraint.activate([
            recorder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: BeruSpace.sm),
            recorder.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -BeruSpace.sm),
            recorder.centerYAnchor.constraint(equalTo: centerYAnchor),
            recorder.heightAnchor.constraint(equalToConstant: BeruMetrics.recorderTextHeight)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: BeruMetrics.fieldWidth, height: BeruMetrics.fieldHeight)
    }
}
