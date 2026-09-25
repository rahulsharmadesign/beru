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

/// Text-only pill for the Grammar style row. A step quieter than the tabs
/// above it — it is an option of Grammar, not a peer — and neutral when
/// selected so the panel keeps one accent. Its own view rather than the
/// verb chip: that one shares the tab row's matched-geometry highlight.
private struct GrammarStyleChip: View {
    let title: String
    let isSelected: Bool
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: BeruSpace.xxs) {
            Text(title)
                .font(BeruType.captionMedium)
                .lineLimit(1)
            if showsChevron {
                BeruIcon(name: "chevron-down", size: BeruMetrics.iconSizeDense, strokeWidth: 2)
            }
        }
        .foregroundStyle(isSelected ? BeruColor.textPrimary : BeruColor.textSecondary)
        .padding(.horizontal, BeruSpace.xs)
        .frame(height: BeruMetrics.pillHeightSm)
        .background {
            if isSelected {
                Capsule().fill(BeruColor.hoverFill)
            }
        }
        .contentShape(Capsule())
    }
}
