import SwiftUI

// Haze surfaces for the settings dashboard: the one module-card recipe every
// page composes from, plus the composed cards (hero, status, stat chips,
// accent swatches). Fills and hairlines only — never a second blur.

extension View {
    /// Haze module card: surface fill, hairline stroke, lit top edge.
    /// The recipe behind `SettingsSection` wells and the composed cards here.
    func settingsModule(radius: CGFloat = EnhancifyRadius.md) -> some View {
        let shape = EnhancifyRadius.shape(radius)
        return self
            .background { shape.fill(EnhancifyColor.card) }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(EnhancifyColor.edge)
                    .frame(height: EnhancifyMetrics.hairline)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(EnhancifyColor.border, lineWidth: EnhancifyMetrics.hairline)
            }
    }
}

/// About identity: brand mark, name, tagline, and the version metapill.
struct SettingsHeroCard: View {
    let name: String
    let tagline: String
    let version: String

    var body: some View {
        HStack(alignment: .center, spacing: EnhancifySpace.md) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: EnhancifyMetrics.brandHero, height: EnhancifyMetrics.brandHero)
                .clipShape(EnhancifyRadius.shape(EnhancifyRadius.lg))
            VStack(alignment: .leading, spacing: EnhancifySpace.xxs) {
                Text(name)
                    .font(EnhancifyType.pageTitle)
                    .foregroundStyle(EnhancifyColor.textPrimary)
                Text(tagline)
                    .font(EnhancifyType.body)
                    .foregroundStyle(EnhancifyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            SettingsStatChip(label: "Version", value: version, mono: true)
        }
        .padding(EnhancifySpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsModule()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(tagline). Version \(version).")
    }
}

/// Permission or connection state on its own module card: icon tile, title
/// with status badge, one-line explainer, and the action the state calls for.
struct SettingsStatusCard<Action: View>: View {
    let icon: String
    let title: String
    let badgeTitle: String
    let isPositive: Bool
    let message: String
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .center, spacing: EnhancifySpace.md) {
            ZStack {
                EnhancifyRadius.shape(EnhancifyRadius.sm)
                    .fill(Color.clear)
                    .overlay {
                        EnhancifyRadius.shape(EnhancifyRadius.sm)
                            .strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
                    }
                EnhancifyIcon(name: icon, size: EnhancifyMetrics.iconSize)
                    .foregroundStyle(isPositive ? EnhancifyColor.positive : EnhancifyColor.textSecondary)
            }
            .frame(width: EnhancifyMetrics.hitTarget, height: EnhancifyMetrics.hitTarget)
            VStack(alignment: .leading, spacing: EnhancifySpace.xxs) {
                HStack(spacing: EnhancifySpace.xs) {
                    Text(title)
                        .font(EnhancifyType.rowTitle)
                        .foregroundStyle(EnhancifyColor.textPrimary)
                    SettingsStatusBadge(title: badgeTitle, isPositive: isPositive)
                }
                Text(message)
                    .font(EnhancifyType.footnote)
                    .foregroundStyle(EnhancifyColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: EnhancifySpace.sm)
            action
        }
        .padding(EnhancifySpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsModule()
    }
}

/// One fact on a Haze metapill: label plus value. Group a row of them with
/// `WrapHStack` so narrow windows wrap instead of clipping.
struct SettingsStatChip: View {
    let label: String
    let value: String
    var mono: Bool = false
    var isDestructive: Bool = false

    var body: some View {
        HStack(spacing: EnhancifySpace.xs) {
            Text(label)
                .font(EnhancifyType.caption)
                .foregroundStyle(EnhancifyColor.textSecondary)
            Text(value)
                .font(mono ? EnhancifyType.mono : EnhancifyType.captionSemibold)
                .foregroundStyle(isDestructive ? EnhancifyColor.destructive : EnhancifyColor.textPrimary)
                .textSelection(.enabled)
        }
        .padding(.horizontal, EnhancifySpace.xs)
        .frame(minHeight: EnhancifyMetrics.metapillHeight)
        .background {
            EnhancifyRadius.shape(EnhancifyRadius.sm)
                .fill(EnhancifyColor.badge)
                .overlay {
                    EnhancifyRadius.shape(EnhancifyRadius.sm)
                        .strokeBorder(EnhancifyColor.border, lineWidth: EnhancifyMetrics.hairline)
                }
        }
        .fixedSize()
    }
}

/// The twelve accent choices as Haze swatches: chip-sized dots with the
/// Lucide check on the selected one and a focus-glow halo.
struct SettingsAccentSwatches: View {
    @Binding var selection: PrimaryColor

    var body: some View {
        WrapHStack(spacing: EnhancifySpace.sm) {
            ForEach(PrimaryColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .overlay {
                                Circle().strokeBorder(
                                    EnhancifyColor.strongBorder,
                                    lineWidth: EnhancifyMetrics.hairline
                                )
                            }
                        if color == selection {
                            EnhancifyIcon(name: "check", size: EnhancifyMetrics.iconSizeDense)
                                .foregroundStyle(EnhancifyColor.onAccent)
                        }
                    }
                    .frame(width: EnhancifyMetrics.chipHeight, height: EnhancifyMetrics.chipHeight)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .shadow(color: color == selection ? EnhancifyColor.focusGlow : .clear, radius: EnhancifyMetrics.focusHalo)
                .accessibilityLabel(color.title)
                .accessibilityAddTraits(color == selection ? .isSelected : [])
            }
        }
    }
}
