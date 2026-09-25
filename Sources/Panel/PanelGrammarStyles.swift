import SwiftUI

// Grammar's style row: one-tap Proofread / Shorten / To English / Humanize,
// then a native menu for tone and just-for-fun rewrites. Picking a style
// re-runs Grammar on the same text.

extension PanelView {
    var grammarStyleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BeruSpace.xs) {
                ForEach(GrammarStyle.quick) { style in
                    PanelHitCapsule(
                        help: style == .english
                            ? "Translate to English — Hinglish and other languages welcome"
                            : style.title,
                        accessibilityLabel: style.title
                    ) {
                        engine.applyGrammarStyle(style)
                    } label: {
                        GrammarStyleChip(
                            title: style.title,
                            icon: style.icon,
                            isSelected: appState.grammarStyle == style,
                            showsChevron: false
                        )
                    }
                }
                PanelHitCapsule(
                    help: "More styles: tone and just for fun",
                    accessibilityLabel: "More styles"
                ) {
                    presentGrammarStyleMenu()
                } label: {
                    GrammarStyleChip(
                        title: menuStyleSelected ? appState.grammarStyle.title : "More",
                        icon: "smile",
                        isSelected: menuStyleSelected,
                        showsChevron: true
                    )
                    .background(NativeMenuAnchor(holder: styleAnchor))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: BeruMetrics.pillHeightSm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var menuStyleSelected: Bool {
        !GrammarStyle.quick.contains(appState.grammarStyle)
    }

    func presentGrammarStyleMenu() {
        func items(_ styles: [GrammarStyle]) -> [NativeMenuItem] {
            styles.map {
                NativeMenuItem(id: $0.rawValue, title: $0.title, isSelected: $0 == appState.grammarStyle)
            }
        }
        presentNativeMenu(
            from: styleAnchor,
            items: [NativeMenuItem.header("Tone")] + items(GrammarStyle.tones)
                + [NativeMenuItem.header("Just for fun")] + items(GrammarStyle.fun),
            onSelect: { id in
                if let style = GrammarStyle(rawValue: id) { engine.applyGrammarStyle(style) }
            }
        )
    }
}

/// Small capsule for the Grammar style row. Its own view rather than the
/// verb chip: that one shares the tab row's matched-geometry highlight.
private struct GrammarStyleChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: BeruSpace.xxs) {
            BeruIcon(name: icon, size: BeruMetrics.iconSizeCompact, strokeWidth: 2)
            Text(title)
                .font(BeruType.footnoteMedium)
                .lineLimit(1)
            if showsChevron {
                BeruIcon(name: "chevron-down", size: BeruMetrics.iconSizeDense, strokeWidth: 2)
            }
        }
        .foregroundStyle(isSelected ? BeruColor.onAccent : BeruColor.textPrimary)
        .padding(.horizontal, BeruSpace.sm)
        .frame(height: BeruMetrics.pillHeightSm)
        .background {
            if isSelected {
                Capsule().fill(BeruColor.accent)
            }
        }
        .overlay {
            if !isSelected {
                Capsule().strokeBorder(BeruColor.strongBorder, lineWidth: BeruMetrics.hairline)
            }
        }
        .contentShape(Capsule())
    }
}
