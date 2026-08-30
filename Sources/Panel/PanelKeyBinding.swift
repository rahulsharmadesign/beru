import Foundation
import SwiftUI

/// Pure resolution of panel key presses to intents.
///
/// Kept free of SwiftUI so the decision table is unit-testable without a host
/// view. `PanelView` owns the side effects; this type only decides.
///
/// The rule that matters: **a bare Return never replaces text.** Replace is
/// destructive — it overwrites the user's selection in whatever app they were
/// in — so it requires the explicit ⌘↩ modifier. Return on its own submits when
/// there is something to submit, and otherwise does nothing.
enum PanelKeyIntent: Equatable {
    /// Overwrite the host app's selection with the accepted result.
    case replace
    /// Send the composer instruction to the engine.
    case submit
    /// Copy the accepted result to the clipboard.
    case copy
    /// Cancel any in-flight run and dismiss.
    case cancel
    /// Select the nth tab (1-based).
    case selectTab(index: Int)
    /// Not ours — let the event travel on to the focused control.
    case pass
}

/// The subset of modifier state the panel cares about.
struct PanelKeyModifiers: Equatable {
    var command: Bool = false

    static let none = PanelKeyModifiers()
    static let command = PanelKeyModifiers(command: true)
}

extension PanelKeyModifiers {
    /// Bridges SwiftUI's `KeyPress` to the value the decision table takes, so
    /// the resolvers stay testable without constructing a `KeyPress`.
    init(press: KeyPress) {
        self.init(command: press.modifiers.contains(.command))
    }
}

enum PanelKeyBinding {
    /// Resolves a Return press.
    ///
    /// - Parameters:
    ///   - modifiers: modifier state at the time of the press.
    ///   - canSubmit: whether the composer holds a non-empty instruction.
    ///   - hasAcceptableResult: whether a result exists that replace could apply.
    ///   - allowsReplace: Search has no Replace; ⌘↩ must not write into the host.
    static func resolveReturn(
        modifiers: PanelKeyModifiers,
        canSubmit: Bool,
        hasAcceptableResult: Bool,
        allowsReplace: Bool = true
    ) -> PanelKeyIntent {
        if modifiers.command {
            // Explicit destructive intent. Still requires something to apply.
            return allowsReplace && hasAcceptableResult ? .replace : .pass
        }
        if canSubmit {
            return .submit
        }
        // Deliberately NOT `.replace`. A bare Return with an empty composer used
        // to overwrite the user's selection, which is unrecoverable and was
        // never asked for.
        return .pass
    }

    /// Resolves a character press. Returns `.pass` for anything unclaimed.
    static func resolveCharacter(
        _ character: Character,
        modifiers: PanelKeyModifiers,
        tabCount: Int
    ) -> PanelKeyIntent {
        guard modifiers.command else { return .pass }

        if character == "c" { return .copy }

        if let digit = character.wholeNumberValue, digit >= 1, digit <= tabCount {
            return .selectTab(index: digit)
        }

        return .pass
    }

    /// Escape always cancels; it is the one unmodified key with a side effect,
    /// and that side effect is non-destructive.
    static func resolveEscape() -> PanelKeyIntent { .cancel }
}
