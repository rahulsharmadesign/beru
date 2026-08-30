import SwiftUI

/// Actions — list + inspector.
struct ActionsView: View {
    @Bindable private var registry = ActionRegistry.shared
    @State private var selection: String?
    @State private var operationError: String?
    @State private var query = ""
    @State private var pendingDeleteID: String?

    private var selected: EnhancementAction? {
        registry.action(withID: selection ?? "")
    }

    private var filteredActions: [EnhancementAction] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return registry.allActions }
        return registry.allActions.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        SettingsWorkspace(title: "Actions", subtitle: DashboardRoute.actions.pageSubtitle) {
            VStack(spacing: 0) {
                filterBar
                SettingsSplitView {
                    list
                } detail: {
                    editor
                }
            }
        }
        .tint(BeruColor.accent)
        .onAppear {
            if selection == nil {
                selection = registry.allActions.first?.id
            }
        }
        .alert("Action operation failed", isPresented: errorPresented) {
            Button("OK") { operationError = nil }
        } message: {
            Text(operationError ?? "Please try again.")
        }
        .confirmationDialog(
            "Delete this action?",
            isPresented: deleteConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deletePending()
            }
        } message: {
            Text("This custom action is removed from the panel.")
        }
    }

    private var filterBar: some View {
        SettingsWorkspaceToolbar {
            SettingsSearchField(text: $query, placeholder: "Search actions")
                .frame(maxWidth: 260)
            SettingsOverflowMenu(title: "More") {
                Button("Export custom actions…") { exportActions() }
                Button("Import custom actions…") { importActions() }
            }
        }
    }

    private var list: some View {
        WorkspaceSourceList(
            selection: $selection,
            isEmpty: filteredActions.isEmpty,
            emptyIcon: "search",
            emptyTitle: "No matches",
            emptyMessage: "Try a different search term."
        ) {
            ForEach(filteredActions) { action in
                WorkspaceListRow(
                    title: action.name,
                    subtitle: action.summary,
                    icon: action.icon
                )
                .tag(action.id)
                .workspaceSourceRow()
                .contextMenu {
                    if !action.isBuiltIn {
                        Button("Delete", role: .destructive) {
                            pendingDeleteID = action.id
                        }
                    }
                }
            }
            .onMove(perform: moveActions)
        } footer: {
            SettingsListFooter {
                SettingsIconButton(icon: "plus", help: "Add action") {
                    addCustomAction()
                }
                SettingsIconButton(
                    icon: "minus",
                    enabled: selected?.isBuiltIn == false,
                    help: "Delete custom action"
                ) {
                    pendingDeleteID = selection
                }
            }
        }
        .help(query.isEmpty ? "Drag to reorder chips in the panel" : "Clear search to reorder")
    }

    @ViewBuilder
    private var editor: some View {
        if let action = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: BeruSpace.lg) {
                    actionEditorSections(action)
                }
                .padding(BeruMetrics.workspaceInspectorPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .settingsWorkspacePane()
        } else {
            BeruEmptyState(
                icon: "sparkles",
                title: "No action selected",
                message: "Choose an action from the list, or add one."
            ) {
                SettingsPrimaryButton(title: "New Action", icon: "plus") {
                    addCustomAction()
                }
            }
            .settingsWorkspacePane()
        }
    }

    @ViewBuilder
    private func actionEditorSections(_ action: EnhancementAction) -> some View {
        if action.isBuiltIn {
            SettingsSection(
                title: "Action",
                subtitle: "Built-in prompts stay shipped so the chip matches the label."
            ) {
                SettingsRow(title: "Kind") {
                    SettingsValue(text: "Built-in")
                }
                SettingsRow(title: "Name") {
                    SettingsValue(text: action.name)
                }
                SettingsRow(title: "Role") {
                    SettingsValue(text: action.role == .grammar ? "Grammar" : "Enhance")
                }
            }

            SettingsSection(title: "Prompt", subtitle: "System prompt sent to the model.") {
                Text(EnhancementAction.resolvedSystemPrompt(for: action))
                    .font(BeruType.mono)
                    .foregroundStyle(BeruColor.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                    .settingsEditorSurface()
            }
        } else {
            SettingsSection(title: "Action", subtitle: "Name and icon shown on the panel chip.") {
                SettingsRow(title: "Kind") {
                    SettingsValue(text: "Custom")
                }
                SettingsRow(title: "Name") {
                    SettingsField(
                        placeholder: "Name",
                        text: customNameBinding(for: action)
                    )
                }
                SettingsRow(title: "Icon") {
                    SettingsField(
                        placeholder: "Lucide icon",
                        text: customIconBinding(for: action)
                    )
                }
            }

            SettingsSection(title: "Prompt", subtitle: "Shown as a verb chip in the panel.") {
                TextEditor(text: customPromptBinding(for: action))
                    .font(BeruType.mono)
                    .foregroundStyle(BeruColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minWidth: 0, minHeight: 220)
                    .frame(maxWidth: .infinity)
                    .dashboardEditorCanvas()
                    .settingsEditorSurface()
                SettingsPillButton(title: "Insert Tone Preset") {
                    var updated = action
                    updated.systemPrompt = Prompts.toneRewrite(
                        description: "<describe the tone or audience here>"
                    )
                    registry.updateCustom(updated)
                }
            }
        }
    }

    private func moveActions(from offsets: IndexSet, to destination: Int) {
        guard query.isEmpty else { return }
        registry.move(fromOffsets: offsets, toOffset: destination)
    }

    private func addCustomAction() {
        registry.addCustom(
            name: "New action",
            icon: "message-square",
            systemPrompt: Prompts.toneRewrite(
                description: "<describe the tone or audience here>"
            )
        )
        selection = registry.customActions.last?.id
    }

    private func deletePending() {
        guard let id = pendingDeleteID,
              let action = registry.action(withID: id),
              !action.isBuiltIn else {
            pendingDeleteID = nil
            return
        }
        registry.removeCustom(id: id)
        selection = registry.allActions.first?.id
        pendingDeleteID = nil
    }

    private func customNameBinding(for action: EnhancementAction) -> Binding<String> {
        Binding(
            get: { registry.action(withID: action.id)?.name ?? action.name },
            set: { newValue in
                guard var updated = registry.action(withID: action.id), !updated.isBuiltIn else { return }
                updated.name = newValue
                registry.updateCustom(updated)
            }
        )
    }

    private func customIconBinding(for action: EnhancementAction) -> Binding<String> {
        Binding(
            get: { registry.action(withID: action.id)?.icon ?? action.icon },
            set: { newValue in
                guard var updated = registry.action(withID: action.id), !updated.isBuiltIn else { return }
                updated.icon = newValue
                registry.updateCustom(updated)
            }
        )
    }

    private func customPromptBinding(for action: EnhancementAction) -> Binding<String> {
        Binding(
            get: { registry.action(withID: action.id)?.systemPrompt ?? action.systemPrompt },
            set: { newValue in
                guard var updated = registry.action(withID: action.id), !updated.isBuiltIn else { return }
                updated.systemPrompt = newValue
                registry.updateCustom(updated)
            }
        )
    }

    private func exportActions() {
        guard let data = registry.exportCustomActions(), !data.isEmpty else {
            operationError = "There are no custom actions to export."
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "beru-actions.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.message = "Share custom actions as JSON. Built-in actions are not included."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func importActions() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Import custom actions from a JSON file. Existing actions are kept."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            operationError = "The selected file could not be read."
            return
        }
        registry.importCustomActions(from: data)
        selection = registry.customActions.last?.id
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )
    }

    private var deleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteID != nil },
            set: { if !$0 { pendingDeleteID = nil } }
        )
    }
}
