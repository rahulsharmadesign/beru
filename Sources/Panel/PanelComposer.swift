import AppKit
import SwiftUI

// The bottom half: instruction field, send button, target and provider
// pickers, and the footer actions.

extension PanelView {
    // MARK: - Footer / composer

    var hasFinishedResult: Bool {
        if case .done = appState.resultState(for: appState.selectedActionID) { return true }
        return false
    }

    /// Outcome strip sits behind the composer and only appears once a result
    /// is in — token pill plus Replace / Copy / Pin, no dismiss control.
    var composerColumn: some View {
        VStack(spacing: hasFinishedResult ? -PanelMetrics.composerOverlap : 0) {
            if hasFinishedResult {
                footer
                    .glassModule()
                    .fixedSize(horizontal: false, vertical: true)
                    .zIndex(0)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            intentField
                .glassModule(radius: PanelMetrics.composerRadius, focusRing: describeFieldFocused)
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)
        }
        .animation(tabAnimation, value: hasFinishedResult)
    }

    var footer: some View {
        HStack(spacing: BeruSpace.xs) {
            if let savings = appState.savings[appState.selectedActionID] {
                SavingsPill(savings: savings)
                    .transition(.opacity)
            }

            if let provenance = contextProvenance {
                Text(provenance)
                    .font(BeruType.captionMedium)
                    .foregroundStyle(BeruColor.textSecondary)
                    .lineLimit(1)
                    .help("Local context applied to this result")
            }
            Spacer()

            if appState.copiedFeedback {
                Text("Copied")
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .transition(.opacity)
            }

            if appState.pinnedFeedback {
                Text("Pinned")
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .transition(.opacity)
            }

            BeruButton(
                title: primaryFooterTitle,
                variant: .primary,
                size: .compact
            ) { performReplace() }
                .help(primaryFooterHelp)

            BeruButton(title: "Copy", size: .compact) { performCopy() }

            BeruButton(title: "Pin", size: .compact) { performPin() }
                .help("Save this result in the vault")
        }
        .padding(.horizontal, PanelMetrics.moduleInset)
        .padding(.top, BeruSpace.xxs)
        .padding(.bottom, PanelMetrics.composerOverlap + BeruSpace.xxs)
        .frame(minHeight: PanelMetrics.footerMinHeight, alignment: .center)
        .frame(maxWidth: .infinity)
    }

    var contextProvenance: String? {
        guard let context = appState.contextApplications[appState.selectedActionID] else { return nil }
        if let playbook = context.playbook { return "Playbook: \(playbook.name)" }
        if !context.rules.isEmpty { return "Rules: \(context.rules.count)" }
        if let workspace = context.workspace, workspace.hasMemory { return "Workspace: \(workspace.name)" }
        return context.glossary.isEmpty ? nil : "Glossary"
    }

    var isErrorState: Bool {
        if case .error = appState.resultState(for: appState.selectedActionID) { return true }
        return false
    }

    var intentField: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            HStack(spacing: BeruSpace.xs) {
                BeruIcon(
                    name: appState.isQuickSearch ? "search" : "sparkles",
                    size: 16
                )
                .foregroundStyle(BeruColor.textSecondary)
                TextField(composerPlaceholder, text: $appState.describeInstruction)
                    .textFieldStyle(.plain)
                    .font(BeruType.body)
                    .focused($describeFieldFocused)
                    .onSubmit { submitDescribe() }
            }
            HStack(spacing: BeruSpace.xs) {
                if isSmartReply {
                    toneMenu
                }
                if targetPickerVisible {
                    targetMenu
                } else {
                    providerMenu
                }
                PanelIconHitButton(
                    icon: "rotate-cw",
                    help: "Regenerate",
                    hint: "Run this action again on the same input",
                    enabled: hasFinishedResult || isErrorState
                ) {
                    engine.retry(actionID: appState.selectedActionID)
                }
                Spacer(minLength: BeruSpace.xs)
                DictationButton(onNeedsPermission: { engine.requestDictationPermission() })
                sendButton
            }
        }
        // Search mode swaps the icon, placeholder and the target/provider menu.
        // Scoped here so the composer card's own frame is not part of it.
        .animation(tabAnimation, value: appState.isQuickSearch)
        .padding(.horizontal, PanelMetrics.moduleInset)
        .padding(.vertical, BeruSpace.xs)
        .frame(minHeight: PanelMetrics.composerMinHeight, alignment: .center)
        .frame(maxWidth: .infinity)
    }

    var sendButton: some View {
        Button {
            guard canSubmitDescribe else { return }
            submitDescribe()
        } label: {
            ZStack {
                Circle()
                    .fill(canSubmitDescribe ? BeruColor.accent : BeruColor.disabledFill)
                BeruIcon(name: "arrow-up", size: 15, strokeWidth: 2.4)
                    .foregroundStyle(canSubmitDescribe ? BeruColor.onAccent : BeruColor.textSecondary)
            }
            .frame(width: BeruMetrics.hitTarget, height: BeruMetrics.hitTarget)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: canSubmitDescribe)
        .help("Run this intent")
        .accessibilityLabel("Run this intent")
        .accessibilityHint("Send the instruction to Beru")
    }

    var composerPlaceholder: String {
        if appState.isQuickSearch || appState.selectedActionID == EnhancementAction.searchID {
            return "Ask anything — no selection needed"
        }
        if appState.capturedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Nothing selected — ask instead"
        }
        // A concrete example beats "instruction for this action", which read
        // as required. Custom actions keep the generic line.
        switch appState.selectedActionID {
        case EnhancementAction.grammarID:
            return "Optional: e.g. \u{201C}keep my tone\u{201D}"
        case EnhancementAction.enhanceID:
            return "Optional: e.g. \u{201C}for beginners\u{201D}"
        case EnhancementAction.replyID:
            return "Optional: e.g. \u{201C}mention Friday\u{201D}"
        case EnhancementAction.summarizeID, EnhancementAction.explainID:
            return "Optional: e.g. \u{201C}in 5 bullets\u{201D}"
        default:
            return "Optional instruction for this action…"
        }
    }

    var canSubmitDescribe: Bool {
        !appState.describeInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submitDescribe() {
        if appState.selectedActionID == EnhancementAction.searchID || appState.isQuickSearch {
            engine.runQuickSearch(query: appState.describeInstruction)
        } else {
            engine.runDescribe(instruction: appState.describeInstruction)
        }
    }

    var targetPickerVisible: Bool {
        guard !appState.isQuickSearch,
              let action = registry.action(withID: appState.selectedActionID) else { return false }
        return Prompts.targetApplies(
            actionID: action.id, role: action.role, usesBuiltInPrompt: action.isBuiltIn
        )
    }

    var targetMenu: some View {
        let active = targetRegistry.profile(withID: appState.selectedTargetID)
        return composerPickerPill(
            icon: active?.icon ?? "circle-dashed",
            title: active?.name ?? "Generic",
            help: "Which AI this prompt is written for",
            accessibilityLabel: "Target, \(active?.name ?? "Generic")",
            accessibilityHint: "Choose which AI this prompt is written for",
            action: presentTargetMenu
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
            action: presentProviderMenu
        )
    }

    func composerPickerPill(
        icon: String,
        title: String,
        help: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: BeruSpace.xxs) {
                BeruIcon(name: icon, size: 12, strokeWidth: 2)
                    .foregroundStyle(BeruColor.accent)
                Text(title)
                    .font(BeruType.captionMedium)
                    .foregroundStyle(BeruColor.textSecondary)
                    .lineLimit(1)
                BeruIcon(name: "chevron-down", size: 10, strokeWidth: 2)
                    .foregroundStyle(BeruColor.textSecondary)
            }
            .padding(.horizontal, BeruSpace.xs)
            .padding(.vertical, BeruSpace.xxs)
            .background {
                Capsule()
                    .fill(BeruColor.subtleFill)
                    .overlay(Capsule().strokeBorder(BeruColor.border, lineWidth: 1))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    /// `NSMenu.popUp` works in a non-activating panel. SwiftUI `Menu` does not —
    /// the control draws, but the menu never appears, so the picker looks dead.
    func presentTargetMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let selectedID = appState.selectedTargetID
        TargetMenuRelay.shared.onPick = { id in
            selectTarget(id)
        }
        for profile in targetRegistry.profiles {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(TargetMenuRelay.pick(_:)),
                keyEquivalent: ""
            )
            item.target = TargetMenuRelay.shared
            item.representedObject = profile.id
            item.state = profile.id == selectedID ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func presentProviderMenu() {
        let settings = SettingsStore.shared
        let menu = NSMenu()
        menu.autoenablesItems = false
        let selected = settings.activeProvider
        PanelProviderMenuRelay.shared.onPick = { kind in
            settings.selectProvider(kind)
        }
        for kind in ProviderKind.allCases {
            let item = NSMenuItem(
                title: kind.title,
                action: #selector(PanelProviderMenuRelay.pick(_:)),
                keyEquivalent: ""
            )
            item.target = PanelProviderMenuRelay.shared
            item.representedObject = kind.rawValue
            item.state = kind == selected ? .on : .off
            item.isEnabled = settings.isConfigured(kind)
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func selectTarget(_ targetID: String) {
        guard targetID != appState.selectedTargetID else { return }
        appState.selectTarget(targetID)
        let actionID = appState.selectedActionID
        appState.results.removeValue(forKey: actionID)
        engine.startIfNeeded(actionID: actionID)
    }

    func performReplace() {
        guard let text = appState.acceptedText() else { return }
        engine.replace(text: text)
    }

    func performCopy() {
        guard let text = appState.acceptedText() else { return }
        engine.copy(text: text)
    }

    func performPin() {
        guard let text = appState.acceptedText() else { return }
        engine.pin(text: text)
    }
}

/// Target of `NSMenuItem` actions. SwiftUI views cannot be `@objc` targets.
final class TargetMenuRelay: NSObject {
    static let shared = TargetMenuRelay()
    var onPick: ((String) -> Void)?

    @objc func pick(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onPick?(id)
    }
}

final class PanelProviderMenuRelay: NSObject {
    static let shared = PanelProviderMenuRelay()
    var onPick: ((ProviderKind) -> Void)?

    @objc func pick(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let kind = ProviderKind(rawValue: raw) else { return }
        onPick?(kind)
    }
}

extension ProviderKind {
    var composerTitle: String {
        switch self {
        case .ollama: return "Ollama"
        case .anthropic: return "Anthropic"
        case .custom: return "API"
        }
    }

    var composerIcon: String {
        switch self {
        case .ollama: return "cpu"
        case .anthropic: return "sparkle"
        case .custom: return "cloud"
        }
    }
}
