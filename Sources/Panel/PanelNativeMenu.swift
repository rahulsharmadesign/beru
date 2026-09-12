import AppKit
import SwiftUI

/// Native dropdown menus for the composer pills.
///
/// SwiftUI `Menu` never opens in the non-activating panel, so the pills
/// present an AppKit `NSMenu` instead — the real system menu with Liquid
/// Glass, checkmarks, disabled items, type-select, and VoiceOver.
/// `popUp` tracks synchronously and returns after dismissal, so no SwiftUI
/// open-state is needed: the pill chevron stays static and Escape needs no
/// menu branch.

// MARK: - Anchor

/// Holds a pill's NSView without invalidating SwiftUI state: a plain weak
/// slot, so assigning it never refreshes the view and the representable
/// update path cannot recurse.
final class MenuAnchorHolder {
    weak var view: NSView?
}

final class MenuAnchorView: NSView {
    var holder: MenuAnchorHolder?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { holder?.view = self }
    }
}

/// Transparent AppKit view seated behind a pill so `NSMenu.popUp` has a
/// window to attach to. Never draws, never tracks — clicks still land on
/// the SwiftUI button above it.
struct NativeMenuAnchor: NSViewRepresentable {
    let holder: MenuAnchorHolder

    func makeNSView(context: Context) -> MenuAnchorView {
        let view = MenuAnchorView()
        view.holder = holder
        return view
    }

    func updateNSView(_ view: MenuAnchorView, context: Context) {
        view.holder = holder
        holder.view = view
    }
}

// MARK: - Presentation

/// One row in a native pill menu.
struct NativeMenuItem {
    let id: String
    let title: String
    var icon: String? = nil
    var isSelected: Bool = false
    var isEnabled: Bool = true
}

private final class MenuActionTarget: NSObject {
    let onSelect: (String) -> Void

    init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    @objc func selected(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { onSelect(id) }
    }
}

extension PanelView {
    /// Presents a native menu from a pill. The local target outlives the
    /// synchronous tracking loop, so the weak `NSMenuItem.target` is safe.
    func presentNativeMenu(
        from holder: MenuAnchorHolder,
        items: [NativeMenuItem],
        onSelect: @escaping (String) -> Void
    ) {
        guard let anchor = holder.view, anchor.window != nil else { return }
        let target = MenuActionTarget(onSelect: onSelect)
        let menu = NSMenu()
        menu.minimumWidth = BeruMetrics.menuWidth
        for item in items {
            let menuItem = NSMenuItem(
                title: item.title,
                action: #selector(MenuActionTarget.selected(_:)),
                keyEquivalent: ""
            )
            menuItem.target = target
            menuItem.representedObject = item.id
            menuItem.state = item.isSelected ? .on : .off
            menuItem.isEnabled = item.isEnabled
            if let icon = item.icon {
                menuItem.image = NSImage(
                    systemSymbolName: IconNames.system(stored: icon),
                    accessibilityDescription: nil
                )
            }
            menu.addItem(menuItem)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height), in: anchor)
    }

    // MARK: - Composer pills

    var targetMenu: some View {
        let active = targetRegistry.profile(withID: appState.selectedTargetID)
        return composerPickerPill(
            icon: active?.icon ?? "circle-dashed",
            title: active?.name ?? "Generic",
            help: "Which AI this prompt is written for",
            accessibilityLabel: "Target, \(active?.name ?? "Generic")",
            accessibilityHint: "Choose which AI this prompt is written for",
            anchor: targetAnchor,
            onTap: presentTargetMenu
        )
    }

    func presentTargetMenu() {
        presentNativeMenu(
            from: targetAnchor,
            items: targetRegistry.profiles.map { profile in
                NativeMenuItem(
                    id: profile.id,
                    title: profile.name,
                    icon: profile.icon,
                    isSelected: profile.id == appState.selectedTargetID
                )
            },
            onSelect: { selectTarget($0) }
        )
    }

    var providerMenu: some View {
        let kind = SettingsStore.shared.activeProvider
        return composerPickerPill(
            icon: kind.composerIcon,
            title: kind.composerTitle,
            help: "Change the active provider",
            accessibilityLabel: "Active provider, \(kind.title)",
            accessibilityHint: "Choose which AI provider Beru sends requests to",
            anchor: providerAnchor,
            onTap: presentProviderMenu
        )
    }

    func presentProviderMenu() {
        let settings = SettingsStore.shared
        presentNativeMenu(
            from: providerAnchor,
            items: ProviderKind.allCases.map { kind in
                NativeMenuItem(
                    id: kind.rawValue,
                    title: kind.title,
                    icon: kind.composerIcon,
                    isSelected: kind == settings.activeProvider,
                    isEnabled: settings.isConfigured(kind)
                )
            },
            onSelect: { id in
                if let kind = ProviderKind(rawValue: id) {
                    SettingsStore.shared.selectProvider(kind)
                }
            }
        )
    }

    func composerPickerPill(
        icon: String,
        title: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        anchor: MenuAnchorHolder,
        onTap: @escaping () -> Void
    ) -> some View {
        BeruGlassControl(
            kind: .plain,
            size: .small,
            action: onTap
        ) {
            HStack(spacing: BeruSpace.xxs) {
                BeruIcon(name: icon, size: BeruMetrics.iconSizeCompact, strokeWidth: 2)
                    .foregroundStyle(BeruColor.textSecondary)
                Text(title)
                    .font(BeruType.footnoteMedium)
                    .foregroundStyle(BeruColor.textPrimary)
                    .lineLimit(1)
                BeruIcon(name: "chevron-down", size: BeruMetrics.iconSizeDense, strokeWidth: 2)
                    .foregroundStyle(BeruColor.textSecondary)
            }
            .padding(.horizontal, BeruSpace.xs)
            .frame(height: BeruMetrics.pillHeightSm)
            .overlay {
                Capsule().strokeBorder(BeruColor.strongBorder, lineWidth: BeruMetrics.hairline)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .background(NativeMenuAnchor(holder: anchor))
        }
        .fixedSize()
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(title)
    }
}
