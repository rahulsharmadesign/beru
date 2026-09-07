import SwiftUI

/// Targets — list + inspector.
struct TargetsView: View {
    @Bindable private var registry = TargetRegistry.shared
    @State private var selection: String?
    @State private var operationError: String?
    @State private var query = ""
    @State private var pendingDeleteID: String?

    private var selected: TargetProfile? {
        registry.profile(withID: selection ?? "")
    }

    private var filteredProfiles: [TargetProfile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return registry.profiles }
        return registry.profiles.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        SettingsWorkspace(
            title: DashboardRoute.targets.title,
            subtitle: DashboardRoute.targets.pageSubtitle,
            icon: DashboardRoute.targets.lucideIcon
        ) {
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
                selection = registry.profiles.first?.id
            }
        }
        .alert("Target operation failed", isPresented: errorPresented) {
            Button("OK") { operationError = nil }
        } message: {
            Text(operationError ?? "Please try again.")
        }
        .confirmationDialog(
            "Delete this target?",
            isPresented: deleteConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deletePending()
            }
        } message: {
            Text("This custom target is removed from the picker.")
        }
    }

    private var filterBar: some View {
        SettingsWorkspaceToolbar {
            SettingsSearchField(text: $query, placeholder: "Search targets")
                .frame(maxWidth: BeruMetrics.toolbarSearchWidth)
            Spacer(minLength: BeruSpace.md)
            SettingsPillButton(title: "Import", leadingIcon: "square.and.arrow.down") {
                importTargets()
            }
            SettingsPillButton(title: "Export", leadingIcon: "square.and.arrow.up") {
                exportTargets()
            }
        }
    }

    private var list: some View {
        WorkspaceSourceList(
            isEmpty: filteredProfiles.isEmpty,
            emptyIcon: "search",
            emptyTitle: "No matches",
            emptyMessage: "Try a different search term."
        ) {
            ForEach(filteredProfiles) { profile in
                WorkspaceListRow(
                    title: profile.name,
                    subtitle: profile.isBuiltIn ? "Built-in" : "Custom",
                    icon: profile.icon
                )
                .workspaceRowSelection($selection, value: profile.id, isSelected: selection == profile.id)
                .contextMenu {
                    if !profile.isBuiltIn {
                        Button("Delete", role: .destructive) {
                            pendingDeleteID = profile.id
                        }
                    }
                }
            }
        } footer: {
            SettingsListFooter {
                SettingsIconButton(icon: "plus", help: "Add target") {
                    addCustomTarget()
                }
                SettingsIconButton(
                    icon: "minus",
                    enabled: selected?.isBuiltIn == false,
                    help: "Delete custom target"
                ) {
                    pendingDeleteID = selection
                }
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let profile = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: BeruSpace.lg) {
                    SettingsSection(title: "Target") {
                        SettingsRow(title: "Kind") {
                            SettingsValue(text: inspectorBadge(for: profile))
                        }
                        SettingsRow(title: "Name") {
                            SettingsField(
                                placeholder: "Name",
                                text: binding(for: profile).name
                            )
                        }
                        SettingsRow(title: "Icon") {
                            SettingsField(
                                placeholder: "SF Symbol or icon name",
                                text: binding(for: profile).icon
                            )
                        }
                    }

                    SettingsSection(
                        title: "Conventions",
                        subtitle: "Appended to Enhance Prompt for this environment."
                    ) {
                        TextEditor(text: binding(for: profile).promptFragment)
                            .font(BeruType.mono)
                            .foregroundStyle(BeruColor.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minWidth: 0, minHeight: BeruMetrics.editorMinHeight)
                            .frame(maxWidth: .infinity)
                            .dashboardEditorCanvas()
                    }

                    if profile.isBuiltIn, registry.isModifiedFromDefault(id: profile.id) {
                        SettingsPillButton(title: "Reset to Default") {
                            registry.resetToDefault(id: profile.id)
                        }
                    }
                }
                .padding(BeruMetrics.workspaceInspectorPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .settingsWorkspacePane()
        } else {
            BeruEmptyState(
                icon: "target",
                title: "No target selected",
                message: "Choose a target from the list, or add one."
            ) {
                SettingsPrimaryButton(title: "New Target", icon: "plus") {
                    addCustomTarget()
                }
            }
            .settingsWorkspacePane()
        }
    }

    private func inspectorBadge(for profile: TargetProfile) -> String {
        if !profile.isBuiltIn { return "Custom" }
        if registry.isModifiedFromDefault(id: profile.id) { return "Edited" }
        return "Built-in"
    }

    private func addCustomTarget() {
        registry.addCustom(name: "New target", icon: "target", fragment: "")
        selection = registry.profiles.last?.id
    }

    private func deletePending() {
        guard let id = pendingDeleteID,
              let profile = registry.profile(withID: id),
              !profile.isBuiltIn else {
            pendingDeleteID = nil
            return
        }
        registry.removeCustom(id: id)
        selection = registry.profiles.first?.id
        pendingDeleteID = nil
    }

    private func binding(for profile: TargetProfile) -> Binding<TargetProfile> {
        Binding(
            get: { registry.profile(withID: profile.id) ?? profile },
            set: { registry.update($0) }
        )
    }

    private func exportTargets() {
        guard let data = registry.exportCustomTargets(), !data.isEmpty else {
            operationError = "There are no custom targets to export."
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "beru-targets.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.message = "Share custom targets as JSON. Built-in targets are not included."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func importTargets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Import custom targets from a JSON file. Existing targets are kept."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            operationError = "The selected file could not be read."
            return
        }
        registry.importCustomTargets(from: data)
        selection = registry.profiles.last?.id
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
