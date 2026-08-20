import SwiftUI

/// Targets — list + inspector.
struct TargetsView: View {
    @State private var registry = TargetRegistry.shared
    @State private var selection: String?
    @State private var operationError: String?
    @State private var query = ""

    private var selected: TargetProfile? {
        registry.profile(withID: selection ?? "")
    }

    private var filteredProfiles: [TargetProfile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return registry.profiles }
        return registry.profiles.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        SettingsWorkspace(title: "Targets", subtitle: DashboardRoute.targets.pageSubtitle) {
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
    }

    private var filterBar: some View {
        SettingsWorkspaceToolbar {
            SettingsSearchField(text: $query, placeholder: "Search targets")
                .frame(maxWidth: 260)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            Group {
                if filteredProfiles.isEmpty {
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
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(filteredProfiles) { profile in
                                Button {
                                    selection = profile.id
                                } label: {
                                    targetRow(profile)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .padding(.top, SettingsChrome.workspaceListInset)
                    .padding(.horizontal, SettingsChrome.contentPadding)
                    .frame(maxHeight: .infinity)
                }
            }

            SettingsListFooter {
                SettingsIconButton(icon: "plus", help: "Add target") {
                    registry.addCustom(name: "New target", icon: "target", fragment: "")
                    selection = registry.profiles.last?.id
                }
                SettingsIconButton(
                    icon: "minus",
                    enabled: selected?.isBuiltIn == false,
                    help: "Delete custom target"
                ) {
                    guard let id = selection,
                          let profile = registry.profile(withID: id),
                          !profile.isBuiltIn else { return }
                    registry.removeCustom(id: id)
                    selection = registry.profiles.first?.id
                }
                SettingsIconButton(icon: "upload", help: "Export custom targets") {
                    exportTargets()
                }
                SettingsIconButton(icon: "download", help: "Import custom targets") {
                    importTargets()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardChrome.sidebarSurface)
    }

    private func targetRow(_ profile: TargetProfile) -> some View {
        let isSelected = selection == profile.id
        return HStack(spacing: BeruSpace.sm) {
            BeruIcon(name: profile.icon, size: 16)
                .foregroundStyle(isSelected ? SettingsTheme.onActive : SettingsTheme.textSecondary)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: BeruSpace.hair) {
                Text(profile.name)
                    .font(BeruSans.rowTitle)
                    .foregroundStyle(isSelected ? SettingsTheme.onActive : SettingsTheme.textPrimary)
                    .lineLimit(1)
                Text(profile.isBuiltIn ? "Built-in" : "Custom")
                    .font(BeruSans.footnote)
                    .foregroundStyle(isSelected ? SettingsTheme.onActive.opacity(0.72) : SettingsTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BeruSpace.sm)
        .padding(.vertical, BeruSpace.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous)
                .fill(isSelected ? SettingsTheme.active : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous))
    }

    @ViewBuilder
    private var editor: some View {
        if let profile = selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsSection(title: "Target", subtitle: "Name and icon shown in the panel picker.") {
                        SettingsRow(title: "Name") {
                            SettingsField(
                                placeholder: "Name",
                                text: binding(for: profile).name
                            )
                        }
                        SettingsRow(title: "Icon") {
                            SettingsField(
                                placeholder: "Lucide icon",
                                text: binding(for: profile).icon
                            )
                        }
                    }

                    SettingsSection(
                        title: "Conventions",
                        subtitle: "Appended to Enhance Prompt for this environment. Leave empty for Generic."
                    ) {
                        TextEditor(text: binding(for: profile).promptFragment)
                            .font(BeruSans.mono)
                            .foregroundStyle(SettingsTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minWidth: 0, minHeight: 220)
                            .frame(maxWidth: .infinity)
                            .dashboardEditorCanvas()
                            .settingsEditorSurface()
                    }

                    if profile.isBuiltIn, registry.isModifiedFromDefault(id: profile.id) {
                        SettingsPillButton(title: "Reset to Default") {
                            registry.resetToDefault(id: profile.id)
                        }
                    }
                }
                .padding(SettingsChrome.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .settingsWorkspacePane()
        } else {
            BeruEmptyState(
                icon: "target",
                title: "No Target Selected",
                message: "Choose a target from the list, or add one."
            )
            .settingsWorkspacePane()
        }
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
}
