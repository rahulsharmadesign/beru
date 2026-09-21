import AppKit
import SwiftUI

/// Raycast-style crown shade over the panel slab: near-solid at the top,
/// opening into translucency toward the bottom so the chrome end reads
/// anchored and the result end stays glass. Dark only — Light stays pure
/// slab tint. Fills, not a second blur.
///
/// Lives here rather than in BeruColor: that file sits at the 400-line
/// ceiling and this shade is one responsibility (the panel crown).
extension BeruColor {
    static var panelShade: LinearGradient {
        LinearGradient(
            colors: [panelShadeTop, panelShadeBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var panelShadeTop: Color {
        Color(nsColor: NSColor(name: "BeruPanelShadeTop") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark ? NSColor.black.withAlphaComponent(0.65) : .clear
        })
    }

    static var panelShadeBottom: Color {
        Color(nsColor: NSColor(name: "BeruPanelShadeBottom") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark ? NSColor.black.withAlphaComponent(0.12) : .clear
        })
    }
}
