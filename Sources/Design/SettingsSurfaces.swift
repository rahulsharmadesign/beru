import SwiftUI

// Haze surfaces for the settings dashboard: the one module-card recipe every
// page composes from, plus the composed cards (hero, status, stat chips,
// accent swatches). Fills and hairlines only — never a second blur.

extension View {
    /// Haze module card: surface fill, hairline stroke, lit top edge.
    /// The recipe behind `SettingsSection` wells and the composed cards here.
    func settingsModule(radius: CGFloat = BeruRadius.md) -> some View {
        let shape = BeruRadius.shape(radius)
        return self
            .background { shape.fill(BeruColor.card) }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(BeruColor.edge)
                    .frame(height: BeruMetrics.hairline)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(BeruColor.border, lineWidth: BeruMetrics.hairline)
            }
    }
}

/// About identity: brand mark, name, tagline, and the version metapill.
struct SettingsHeroCard: View {
    let name: String
    let tagline: String
    let version: String

    var body: some View {
        HStack(alignment: .center, spacing: BeruSpace.md) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: BeruMetrics.brandHero, height: BeruMetrics.brandHero)
                .clipShape(BeruRadius.shape(BeruRadius.lg))
            VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                Text(name)
                    .font(BeruType.pageTitle)
                    .foregroundStyle(BeruColor.textPrimary)
                Text(tagline)
                    .font(BeruType.body)
                    .foregroundStyle(BeruColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            SettingsStatChip(label: "Version", value: version, mono: true)
        }
        .padding(BeruSpace.md)
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
        HStack(alignment: .center, spacing: BeruSpace.md) {
            ZStack {
                BeruRadius.shape(BeruRadius.sm)
                    .fill(Color.clear)
                    .overlay {
                        BeruRadius.shape(BeruRadius.sm)
                            .strokeBorder(BeruColor.strongBorder, lineWidth: BeruMetrics.hairline)
                    }
                BeruIcon(name: icon, size: BeruMetrics.iconSize)
                    .foregroundStyle(isPositive ? BeruColor.positive : BeruColor.textSecondary)
            }
            .frame(width: BeruMetrics.hitTarget, height: BeruMetrics.hitTarget)
            VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                HStack(spacing: BeruSpace.xs) {
                    Text(title)
                        .font(BeruType.rowTitle)
                        .foregroundStyle(BeruColor.textPrimary)
                    SettingsStatusBadge(title: badgeTitle, isPositive: isPositive)
                }
                Text(message)
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: BeruSpace.sm)
            action
        }
        .padding(BeruSpace.md)
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
        HStack(spacing: BeruSpace.xs) {
            Text(label)
                .font(BeruType.caption)
                .foregroundStyle(BeruColor.textSecondary)
            Text(value)
                .font(mono ? BeruType.mono : BeruType.captionSemibold)
                .foregroundStyle(isDestructive ? BeruColor.destructive : BeruColor.textPrimary)
                .textSelection(.enabled)
        }
        .padding(.horizontal, BeruSpace.xs)
        .frame(minHeight: BeruMetrics.metapillHeight)
        .background {
            BeruRadius.shape(BeruRadius.sm)
                .fill(BeruColor.badge)
                .overlay {
                    BeruRadius.shape(BeruRadius.sm)
                        .strokeBorder(BeruColor.border, lineWidth: BeruMetrics.hairline)
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
        WrapHStack(spacing: BeruSpace.sm) {
            ForEach(PrimaryColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .overlay {
                                Circle().strokeBorder(
                                    BeruColor.strongBorder,
                                    lineWidth: BeruMetrics.hairline
                                )
                            }
                        if color == selection {
                            BeruIcon(name: "check", size: BeruMetrics.iconSizeDense)
                                .foregroundStyle(BeruColor.onAccent)
                        }
                    }
                    .frame(width: BeruMetrics.chipHeight, height: BeruMetrics.chipHeight)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .shadow(color: color == selection ? BeruColor.focusGlow : .clear, radius: BeruMetrics.focusHalo)
                .accessibilityLabel(color.title)
                .accessibilityAddTraits(color == selection ? .isSelected : [])
            }
        }
    }
}
