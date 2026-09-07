import SwiftUI

/// Provider picker for the menu-bar popup: an inline Haze expansion inside
/// the popup itself — no floating panel, so it can never detach or clip
/// across windows.
struct MenuProviderPicker: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var showsProviders = false

    var body: some View {
        VStack(spacing: BeruSpace.xxs) {
            row
            if showsProviders {
                VStack(spacing: BeruSpace.xxs) {
                    ForEach(ProviderKind.allCases, id: \.rawValue) { kind in
                        option(kind)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var row: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { showsProviders.toggle() }
        } label: {
            HStack(spacing: BeruSpace.xs) {
                BeruIcon(name: "cpu", size: BeruMetrics.iconSize, strokeWidth: 2)
                Text(settings.activeProvider.title)
                    .font(BeruType.controlMedium)
                    .lineLimit(1)
                Spacer(minLength: BeruSpace.xs)
                BeruIcon(name: "chevron-down", size: BeruMetrics.iconSizeDense, strokeWidth: 2)
                    .foregroundStyle(BeruColor.textSecondary)
                    .rotationEffect(.degrees(showsProviders ? 180 : 0))
            }
            .foregroundStyle(BeruColor.textPrimary)
            .padding(.horizontal, BeruSpace.sm)
            .frame(maxWidth: .infinity, minHeight: BeruMetrics.pillHeight, alignment: .leading)
            .background(BeruColor.subtleFill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(BeruColor.border, lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Change the active provider")
        .accessibilityLabel("Active provider, \(settings.activeProvider.title)")
        .accessibilityHint("Choose which AI provider Beru sends requests to")
    }

    private func option(_ kind: ProviderKind) -> some View {
        let selected = kind == settings.activeProvider
        return Button {
            settings.selectProvider(kind)
            withAnimation(.easeOut(duration: 0.18)) { showsProviders = false }
        } label: {
            HStack(spacing: BeruSpace.xs) {
                BeruIcon(name: selected ? "check" : "cloud", size: BeruMetrics.iconSize, strokeWidth: 2)
                    .foregroundStyle(selected ? BeruColor.accent : BeruColor.textSecondary)
                Text(kind.title)
                    .font(BeruType.control)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(
                selected ? BeruColor.textPrimary
                : (settings.isConfigured(kind) ? BeruColor.textSecondary : BeruColor.textTertiary)
            )
            .padding(.horizontal, BeruSpace.sm)
            .frame(maxWidth: .infinity, minHeight: BeruMetrics.pillHeight, alignment: .leading)
            .background(selected ? AnyShapeStyle(BeruColor.selectedRow) : AnyShapeStyle(Color.clear), in: Capsule())
            .overlay {
                if selected {
                    Capsule().strokeBorder(BeruColor.strongBorder, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!settings.isConfigured(kind))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
