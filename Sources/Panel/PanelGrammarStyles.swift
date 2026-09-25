import SwiftUI

// Grammar's style row: one-tap Proofread / Shorten / To English / Humanize,
// then a native menu for tone and just-for-fun rewrites. Picking a style
// re-runs Grammar on the same text.

extension PanelView {
    var grammarStyleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EnhancifySpace.xs) {
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
        .frame(height: EnhancifyMetrics.pillHeightSm)
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
/// selected (an outline, where the tabs use a fill) so the panel keeps one
/// accent. Its own view rather than the
/// verb chip: that one shares the tab row's matched-geometry highlight.
private struct GrammarStyleChip: View {
    let title: String
    let isSelected: Bool
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: EnhancifySpace.xxs) {
            Text(title)
                .font(EnhancifyType.captionMedium)
                .lineLimit(1)
            if showsChevron {
                EnhancifyIcon(name: "chevron-down", size: EnhancifyMetrics.iconSizeDense, strokeWidth: 2)
            }
        }
        .foregroundStyle(isSelected ? EnhancifyColor.textPrimary : EnhancifyColor.textSecondary)
        .padding(.horizontal, EnhancifySpace.xs)
        .frame(height: EnhancifyMetrics.pillHeightSm)
        // Outline, not fill: the tab row above uses a filled pill, so the two
        // levels read as different controls at a glance.
        .overlay {
            if isSelected {
                Capsule().strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
            }
        }
        .contentShape(Capsule())
    }
}
