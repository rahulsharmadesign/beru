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
    /// A non-selectable section title ("Tone", "Just for fun").
    var isHeader: Bool = false

    static func header(_ title: String) -> NativeMenuItem {
        NativeMenuItem(id: "header-\(title)", title: title, isHeader: true)
    }
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
        menu.minimumWidth = EnhancifyMetrics.menuWidth
        for item in items {
            if item.isHeader {
                if !menu.items.isEmpty { menu.addItem(.separator()) }
                menu.addItem(.sectionHeader(title: item.title))
                continue
            }
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
                // Target and provider rows are objects, not actions — HIG
                // keeps those symbols visible. macOS 27 hides them otherwise.
                LiquidGlassChrome.keepMenuImageVisible(menuItem)
            }
            menu.addItem(menuItem)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height), in: anchor)
    }

    // MARK: - Composer pills

    var targetMenu: some View {
        let active = targetRegistry.profile(withID: appState.selectedTargetID)
        // "for Claude" with a neutral icon: the target's own sparkle icon
        // read as "Claude is answering", i.e. the model, not the destination.
        return composerPickerPill(
            icon: "target",
            title: "for \(active?.name ?? "Generic")",
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
            accessibilityHint: "Choose which AI provider Enhancify sends requests to",
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
        EnhancifyGlassControl(
            kind: .plain,
            size: .small,
            action: onTap
        ) {
            HStack(spacing: EnhancifySpace.xxs) {
                EnhancifyIcon(name: icon, size: EnhancifyMetrics.iconSizeCompact, strokeWidth: 2)
                    .foregroundStyle(EnhancifyColor.textSecondary)
                Text(title)
                    .font(EnhancifyType.footnoteMedium)
                    .foregroundStyle(EnhancifyColor.textPrimary)
                    .lineLimit(1)
                EnhancifyIcon(name: "chevron-down", size: EnhancifyMetrics.iconSizeDense, strokeWidth: 2)
                    .foregroundStyle(EnhancifyColor.textSecondary)
            }
            .padding(.horizontal, EnhancifySpace.xs)
            .frame(height: EnhancifyMetrics.pillHeightSm)
            .overlay {
                Capsule().strokeBorder(EnhancifyColor.strongBorder, lineWidth: EnhancifyMetrics.hairline)
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
