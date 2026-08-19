import SwiftUI

/// Actions — list + inspector.
struct ActionsView: View {
    @State private var registry = ActionRegistry.shared
    @State private var selection: String?
    @State private var operationError: String?
    @State private var query = ""
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
        .tint(DashboardTheme.accent)
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
    }

    private var filterBar: some View {
        SettingsWorkspaceToolbar {
            SettingsSearchField(text: $query, placeholder: "Search actions")
                .frame(maxWidth: 260)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            Group {
                if filteredActions.isEmpty {
                    VStack(spacing: 8) {
                        BeruIcon(name: "list-filter", size: 24)
                            .foregroundStyle(SettingsTheme.textSecondary)
                        Text("No matches")
                            .font(BeruSans.rowTitle)
                            .foregroundStyle(SettingsTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, SettingsChrome.contentPadding)
                } else {
                    List(selection: $selection) {
                        ForEach(filteredActions) { action in
                            Button {
                                selection = action.id
                            } label: {
                                actionRow(action)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 1, leading: SettingsChrome.contentPadding, bottom: 1, trailing: SettingsChrome.contentPadding))
                            .listRowBackground(Color.clear)
                        }
                        .onMove { source, destination in
                            guard query.isEmpty else { return }
                            moveActions(from: source, to: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.top, SettingsChrome.workspaceListInset)
                    .frame(maxHeight: .infinity)
                    .help(query.isEmpty ? "Drag to reorder chips in the panel" : "Clear search to reorder")
                }
            }

            SettingsListFooter {
                SettingsIconButton(icon: "plus", help: "Add action") {
                    registry.addCustom(
                        name: "New action",
                        icon: "message-square",
                        systemPrompt: Prompts.toneRewrite(
                            description: "<describe the tone or audience here>"
                        )
                    )
                    selection = registry.customActions.last?.id
                }
                SettingsIconButton(
                    icon: "minus",
                    enabled: selected?.isBuiltIn == false,
                    help: "Delete custom action"
                ) {
                    guard let id = selection,
                          let action = registry.action(withID: id),
                          !action.isBuiltIn else { return }
                    registry.removeCustom(id: id)
                    selection = registry.allActions.first?.id
                }
                SettingsIconButton(icon: "upload", help: "Export custom actions") {
                    exportActions()
                }
                SettingsIconButton(icon: "download", help: "Import custom actions") {
                    importActions()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardChrome.sidebarSurface)
    }

    private func actionRow(_ action: EnhancementAction) -> some View {
        let isSelected = selection == action.id
        return HStack(spacing: 8) {
            BeruIcon(name: action.icon, size: 16)
                .foregroundStyle(isSelected ? SettingsTheme.onActive : SettingsTheme.textSecondary)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(action.name)
                    .font(BeruSans.rowTitle)
                    .foregroundStyle(isSelected ? SettingsTheme.onActive : SettingsTheme.textPrimary)
                    .lineLimit(1)
                Text(action.summary)
                    .font(BeruSans.footnote)
                    .foregroundStyle(isSelected ? SettingsTheme.onActive.opacity(0.72) : SettingsTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous)
                .fill(isSelected ? SettingsTheme.active : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous))
    }

    @ViewBuilder
    private var editor: some View {
        if let action = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if action.isBuiltIn {
                        SettingsSection(
                            title: "Action",
                            subtitle: "Built-in prompts stay shipped so the chip matches the label."
                        ) {
                            SettingsRow(title: "Name") {
                                SettingsValue(text: action.name)
                            }
                            SettingsRow(title: "Role") {
                                SettingsValue(text: action.role == .grammar ? "Grammar" : "Enhance")
                            }
                        }

                        SettingsSection(title: "Prompt", subtitle: "System prompt sent to the model.") {
                            Text(EnhancementAction.resolvedSystemPrompt(for: action))
                                .font(BeruSans.mono)
                                .foregroundStyle(SettingsTheme.textPrimary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                                .settingsEditorSurface()
                        }
                    } else {
                        SettingsSection(title: "Action", subtitle: "Name and icon shown on the panel chip.") {
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
                                .font(BeruSans.mono)
                                .foregroundStyle(SettingsTheme.textPrimary)
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
                .padding(SettingsChrome.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .settingsWorkspacePane()
        } else {
            BeruEmptyState(
                icon: "sparkles",
                title: "No Action Selected",
                message: "Choose an action from the list, or add one."
            )
            .settingsWorkspacePane()
        }
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

    private func moveActions(from source: IndexSet, to destination: Int) {
        registry.move(fromOffsets: source, toOffset: destination)
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
}

