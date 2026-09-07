import SwiftUI

// Haze float menu for the panel. `NSMenu.popUp` works in a non-activating
// panel but paints a native menu; SwiftUI `Menu` never opens there at all.
// This renders the Haze `.float.menu` in-window above the anchor pill, so
// clicks, hover, and dismissal all stay inside the panel host.

// MARK: - Model

/// One row in an in-window Haze float menu.
struct PanelFloatItem: Identifiable {
    let id: String
    let title: String
    var icon: String? = nil
    var isSelected: Bool = false
    var isEnabled: Bool = true
    var isDestructive: Bool = false
}

// MARK: - Menu

/// In-window float. Spec `.float.menu`: 230 wide, hairline, e2 lift.
struct PanelFloatMenu: View {
    let items: [PanelFloatItem]
    let onSelect: (PanelFloatItem) -> Void


    var body: some View {
        VStack(alignment: .leading, spacing: BeruSpace.hair) {
            ForEach(items) { item in
                PanelFloatRow(item: item) { onSelect(item) }
            }
        }
        .padding(BeruMetrics.floatMenuPadding)
        .frame(width: BeruMetrics.menuWidth)
        .background {
            BeruRadius.shape(BeruRadius.sm2)
                .fill(BeruColor.panelSolid)
                .overlay {
                    BeruRadius.shape(BeruRadius.sm2)
                        .strokeBorder(BeruColor.border, lineWidth: 1)
                }
                .shadow(color: BeruColor.liftShadow, radius: BeruSpace.lg, y: BeruSpace.xs)
                .shadow(color: BeruColor.contactShadow, radius: BeruSpace.hair, y: 1)
        }
    }
}

private struct PanelFloatRow: View {
    let item: PanelFloatItem
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            guard item.isEnabled else { return }
            action()
        } label: {
            HStack(spacing: BeruSpace.sm) {
                if let icon = item.icon {
                    BeruIcon(name: icon, size: BeruMetrics.iconSize)
                }
                Text(item.title)
                    .font(BeruType.control)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if item.isSelected {
                    BeruIcon(name: "check", size: BeruMetrics.iconSizeDense)
                        .foregroundStyle(BeruColor.accent)
                }
            }
            .foregroundStyle(
                item.isDestructive
                    ? BeruColor.destructive
                    : (item.isEnabled ? BeruColor.textPrimary : BeruColor.textTertiary)
            )
            .padding(.horizontal, BeruSpace.sm)
            .frame(height: BeruMetrics.pillHeightSm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                BeruRadius.shape(BeruRadius.sm)
                    .fill(isHovered && item.isEnabled ? BeruColor.hoverFill : .clear)
            }
            .contentShape(BeruRadius.shape(BeruRadius.sm))
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .opacity(item.isEnabled ? 1 : 0.45)
        .onHover { isHovered = $0 }
.beruHoverEase(isHovered)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(item.isSelected ? .isSelected : [])
    }
}

// MARK: - Anchoring

/// Frames of openable pills in the `panelMenu` coordinate space. Overlay
/// preferences never enter layout, so the frozen height contract is untouched.
struct MenuAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Reports this pill's frame so an open float can sit above it.
    func menuAnchor(_ id: String) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: MenuAnchorKey.self,
                    value: [id: geo.frame(in: .named("panelMenu"))]
                )
            }
        }
    }
}

// MARK: - Panel wiring

extension PanelView {
    /// Float ids opened from the composer pills.
    enum PanelMenuID {
        static let provider = "provider"
        static let target = "target"
        static let tone = "tone"
    }

    func toggleMenu(_ id: String) {
        openMenuID = (openMenuID == id) ? nil : id
    }

    /// Dismiss layer + anchored float. The catcher sits under the float so
    /// option taps land on rows; anything else in the window dismisses.
    /// The float column ends 8pt above the pill and bottom-aligns, so it
    /// grows upward no matter how many options it holds.
    @ViewBuilder
    var menuLayer: some View {
        if let id = openMenuID {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { openMenuID = nil }
                if let frame = menuAnchors[id] {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        openFloatMenu(id: id)
                    }
                    .frame(
                        width: BeruMetrics.menuWidth,
                        height: max(frame.minY - BeruSpace.xs, 0),
                        alignment: .bottom
                    )
                    .offset(x: menuX(for: frame))
                }
            }
        }
    }

    private func menuX(for frame: CGRect) -> CGFloat {
        min(
            frame.minX,
            PanelMetrics.width - BeruMetrics.menuWidth - PanelMetrics.moduleInset * 2
        )
    }

    @ViewBuilder
    func openFloatMenu(id: String) -> some View {
        switch id {
        case PanelMenuID.provider:
            PanelFloatMenu(items: providerMenuItems) { item in
                if let kind = ProviderKind(rawValue: item.id) {
                    SettingsStore.shared.selectProvider(kind)
                }
                openMenuID = nil
            }
        case PanelMenuID.target:
            PanelFloatMenu(items: targetMenuItems) { item in
                selectTarget(item.id)
                openMenuID = nil
            }
        case PanelMenuID.tone:
            PanelFloatMenu(items: toneMenuItems) { item in
                if let tone = ReplyTone(rawValue: item.id) {
                    appState.selectedReplyTone = tone
                }
                openMenuID = nil
            }
        default:
            EmptyView()
        }
    }

    private var providerMenuItems: [PanelFloatItem] {
        let settings = SettingsStore.shared
        return ProviderKind.allCases.map { kind in
            PanelFloatItem(
                id: kind.rawValue,
                title: kind.title,
                icon: kind.composerIcon,
                isSelected: kind == settings.activeProvider,
                isEnabled: settings.isConfigured(kind)
            )
        }
    }

    private var targetMenuItems: [PanelFloatItem] {
        targetRegistry.profiles.map { profile in
            PanelFloatItem(
                id: profile.id,
                title: profile.name,
                icon: profile.icon,
                isSelected: profile.id == appState.selectedTargetID
            )
        }
    }

    private var toneMenuItems: [PanelFloatItem] {
        let selected = appState.selectedReplyTone
        return ReplyTone.allCases.map { tone in
            PanelFloatItem(
                id: tone.rawValue,
                title: tone.title,
                isSelected: tone == selected,
                isEnabled: appState.replySuggestions.isEmpty
                    || appState.replySuggestions.contains { $0.tone == tone }
            )
        }
    }
}
