import AppKit
import SwiftUI

/// Local vault: notes list + markdown editor, with pins alongside.
struct VaultView: View {
    @Bindable var model: DashboardModel
    @State private var store = VaultStore.shared
    @State private var selection: String?
    @State private var showingPreview = false
    @State private var showingPins = true
    @State private var showingLinkSheet = false
    @State private var linkTitle = ""
    @State private var linkURL = ""
    @State private var searchText = ""

    private var selected: VaultNote? {
        store.note(id: selection ?? "")
    }

    /// Notes matching the search query, in title or body. Empty query returns
    /// them all — an empty result then reads as "no search hits", not "broken".
    private var filteredNotes: [VaultNote] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return store.notes }
        return store.notes.filter { note in
            note.title.lowercased().contains(needle)
                || note.body.lowercased().contains(needle)
        }
    }

    var body: some View {
        SettingsWorkspace(title: "Vault", subtitle: DashboardRoute.vault.pageSubtitle) {
            VStack(spacing: 0) {
                toolbar
                SettingsSplitView {
                    notesColumn
                } detail: {
                    editorPane
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .tint(BeruColor.accent)
        .onAppear(perform: prepare)
        .sheet(isPresented: $showingLinkSheet) {
            linkSheet
        }
    }

    private func prepare() {
        store.reload()
        if store.notes.isEmpty {
            let welcome = store.createNote(
                title: "Welcome",
                body: """
                # Welcome to your vault

                Write notes here. They stay on this Mac as markdown files.

                - Click **Enhance this note** to open Beru on this text
                - **Apply** in the panel writes the result back here
                - **Pin** saves a result or link in the Pins column

                Choose a folder above to keep the vault in iCloud Drive or Dropbox.
                """
            )
            selection = welcome.id
        } else if selection == nil || store.note(id: selection ?? "") == nil {
            selection = store.notes.first?.id
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        SettingsWorkspaceToolbar {
            SettingsSearchField(text: $searchText, placeholder: "Search notes")
                .frame(maxWidth: 260)

            SettingsPillButton(title: "New Note", leadingIcon: "plus") {
                let created = store.createNote()
                selection = created.id
                showingPreview = false
            }

            Rectangle()
                .fill(SettingsTheme.border)
                .frame(width: 1, height: 16)

            BeruIcon(name: "folder", size: 16)
                .foregroundStyle(SettingsTheme.textSecondary)
            Text(displayPath)
                .font(BeruSans.footnote)
                .foregroundStyle(SettingsTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 80, maxWidth: 220, alignment: .leading)
                .layoutPriority(-1)
                .help(store.rootURL.path)

            SettingsPillButton(title: "Choose…") { store.chooseRootFolder() }

            if !store.isUsingDefaultRoot {
                SettingsPillButton(title: "Reset") { store.resetToDefaultRoot() }
            }

            Spacer(minLength: 8)

            if let status = store.statusMessage {
                Text(status)
                    .font(BeruSans.footnote)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .lineLimit(1)
            }

            SettingsTogglePill(title: "Pins", icon: "pin", isOn: $showingPins)
        }
    }

    private var displayPath: String {
        store.rootURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    // MARK: - Notes list

    private var notesColumn: some View {
        VStack(spacing: 0) {
            Group {
                if filteredNotes.isEmpty {
                    VStack(spacing: 8) {
                        BeruIcon(name: "search", size: 24)
                            .foregroundStyle(SettingsTheme.textSecondary)
                        Text(searchText.isEmpty ? "No notes yet" : "No matches")
                            .font(BeruSans.rowTitle)
                            .foregroundStyle(SettingsTheme.textPrimary)
                        if !searchText.isEmpty {
                            Text("Try a different search term.")
                                .font(BeruSans.footnote)
                                .foregroundStyle(SettingsTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, SettingsChrome.contentPadding)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(filteredNotes) { note in
                                Button {
                                    selection = note.id
                                } label: {
                                    noteRow(note)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        deleteNote(id: note.id)
                                    }
                                }
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
                SettingsIconButton(icon: "plus", help: "New note") {
                    let created = store.createNote()
                    selection = created.id
                    showingPreview = false
                }
                SettingsIconButton(icon: "minus", enabled: selection != nil, help: "Delete note") {
                    guard let id = selection else { return }
                    deleteNote(id: id)
                }
                SettingsIconButton(icon: "upload", help: "Export vault") {
                    store.exportZip()
                }
                SettingsIconButton(icon: "download", help: "Import vault") {
                    store.importZip()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardChrome.sidebarSurface)
    }

    private func noteRow(_ note: VaultNote) -> some View {
        let isSelected = selection == note.id
        return VStack(alignment: .leading, spacing: 2) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(BeruSans.rowTitle)
                .foregroundStyle(isSelected ? SettingsTheme.onActive : SettingsTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(note.preview)
                .font(BeruSans.footnote)
                .foregroundStyle(isSelected ? SettingsTheme.onActive.opacity(0.72) : SettingsTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, BeruSpace.sm)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous)
                .fill(isSelected ? SettingsTheme.active : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous))
    }

    private func deleteNote(id: String) {
        store.deleteNote(id: id)
        selection = store.notes.first?.id
    }

    // MARK: - Editor + optional pins

    private var editorPane: some View {
        HStack(spacing: 0) {
            editorColumn
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)

            if showingPins {
                SettingsVRule()
                pinsColumn
                    .frame(width: 220)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(SettingsTheme.window)
    }

    @ViewBuilder
    private var editorColumn: some View {
        if let note = selected {
            VStack(alignment: .leading, spacing: 0) {
                editorBar(for: note)
                SettingsHeaderRule()
                Group {
                    if showingPreview {
                        ScrollView {
                            MarkdownPreview(text: note.body)
                                .padding(SettingsChrome.contentPadding)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        TextEditor(text: binding(for: note).body)
                            .font(BeruSans.control)
                            .foregroundStyle(SettingsTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .dashboardEditorCanvas()
                            .padding(SettingsChrome.contentPadding)
                    }
                }
                .frame(minWidth: 0, minHeight: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                .background(SettingsTheme.window)
                SettingsHeaderRule()
                editorFooter(for: note)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SettingsTheme.window)
        } else {
            BeruEmptyState(
                icon: "sticky-note",
                title: "No note selected",
                message: "Create a note to start writing."
            ) {
                SettingsPillButton(title: "New Note", leadingIcon: "plus") {
                    selection = store.createNote().id
                }
            }
            .background(SettingsTheme.window)
        }
    }

    private func editorBar(for note: VaultNote) -> some View {
        HStack(spacing: BeruSpace.sm) {
            TextField("Title", text: binding(for: note).title)
                .textFieldStyle(.plain)
                .font(BeruSans.section)
                .foregroundStyle(SettingsTheme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            AppEditorModeControl(showingPreview: $showingPreview)
        }
        .padding(.horizontal, SettingsChrome.contentPadding)
        .padding(.vertical, BeruSpace.sm)
        .fixedSize(horizontal: false, vertical: true)
        .background(SettingsTheme.window)
    }

    private func editorFooter(for note: VaultNote) -> some View {
        let hasBody = !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: BeruSpace.sm) {
            SettingsPrimaryButton(
                title: "Enhance this note",
                icon: "sparkles",
                enabled: hasBody
            ) {
                model.enhanceNote(note.id)
            }

            SettingsPillButton(title: "Pin note", enabled: hasBody, leadingIcon: "pin") {
                store.pinResult(
                    title: note.title,
                    body: note.body,
                    noteID: note.id
                )
            }

            Spacer(minLength: 8)

            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(BeruSans.footnote)
                .foregroundStyle(SettingsTheme.textSecondary)
                .lineLimit(1)
                .layoutPriority(-1)
        }
        .padding(.horizontal, SettingsChrome.contentPadding)
        .padding(.vertical, BeruSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsTheme.window)
    }

    private func binding(for note: VaultNote) -> Binding<VaultNote> {
        Binding(
            get: { store.note(id: note.id) ?? note },
            set: { store.updateNote($0) }
        )
    }

    // MARK: - Pins

    private var pinsColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pins")
                    .font(BeruSans.sidebarHeader)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                SettingsIconButton(icon: "link", help: "Pin a link") {
                    linkTitle = ""
                    linkURL = ""
                    showingLinkSheet = true
                }
            }
            .padding(.horizontal, SettingsChrome.workspaceListInset)
            .padding(.vertical, BeruSpace.sm)
            .fixedSize(horizontal: false, vertical: true)

            SettingsHeaderRule()

            if store.pins.isEmpty {
                VStack(spacing: 8) {
                    BeruIcon(name: "pin-off", size: 22)
                        .foregroundStyle(SettingsTheme.textSecondary)
                    Text("No pins yet")
                        .font(BeruSans.rowTitle)
                    Text("Pin a link, or pin a panel result.")
                        .font(BeruSans.footnote)
                        .foregroundStyle(SettingsTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    SettingsPillButton(title: "Pin link", leadingIcon: "link") {
                        showingLinkSheet = true
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.pins) { pin in
                        pinRow(pin)
                            .listRowInsets(EdgeInsets(top: 4, leading: SettingsChrome.workspaceListInset, bottom: 4, trailing: SettingsChrome.workspaceListInset))
                            .listRowSeparator(.hidden)
                    }
                }
                .settingsSidebarList()
                .background(DashboardChrome.sidebarSurface)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardChrome.sidebarSurface)
    }

    private func pinRow(_ pin: VaultPin) -> some View {
        VStack(alignment: .leading, spacing: BeruSpace.xxs) {
            HStack(spacing: BeruSpace.xs) {
                BeruIcon(name: pin.kind == .link ? "link" : "inventory_2", size: 14)
                    .foregroundStyle(SettingsTheme.textSecondary)
                Text(pin.title)
                    .font(BeruSans.rowCaption.weight(.medium))
                    .foregroundStyle(SettingsTheme.textPrimary)
                    .lineLimit(2)
            }

            if pin.kind == .link, let url = pin.url, !url.isEmpty {
                Text(url)
                    .font(BeruSans.footnote)
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                    .onTapGesture { openURL(url) }
            } else if let body = pin.body, !body.isEmpty {
                Text(body.replacingOccurrences(of: "\n", with: " "))
                    .font(BeruSans.footnote)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .lineLimit(3)
            }

            HStack(spacing: 2) {
                if pin.kind == .run, let body = pin.body, !body.isEmpty {
                    SettingsInlineButton(title: "Enhance") { model.enhanceText(body) }
                }
                if pin.kind == .link, let url = pin.url {
                    SettingsInlineButton(title: "Open") { openURL(url) }
                }
                SettingsInlineButton(title: "Copy") {
                    let text = pin.kind == .link ? (pin.url ?? pin.title) : (pin.body ?? pin.title)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    store.flashStatus("Copied pin")
                }
                Spacer(minLength: 0)
                SettingsIconButton(icon: "trash-2", size: 13, frameSize: 22, help: "Delete pin") {
                    store.deletePin(id: pin.id)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var linkSheet: some View {
        VStack(alignment: .leading, spacing: DashboardMetrics.md) {
            Text("Pin link")
                .font(BeruSans.section)
                .foregroundStyle(SettingsTheme.textPrimary)
            SettingsField(placeholder: "Title", text: $linkTitle, width: 364)
            SettingsField(placeholder: "URL", text: $linkURL, width: 364)
            HStack {
                Spacer()
                SettingsPillButton(title: "Cancel") { showingLinkSheet = false }
                    .keyboardShortcut(.cancelAction)
                SettingsPrimaryButton(
                    title: "Pin",
                    enabled: !linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    store.addLinkPin(title: linkTitle, url: linkURL)
                    showingLinkSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DashboardMetrics.lg)
        .frame(width: 420)
    }

    private func openURL(_ string: String) {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") {
            value = "https://\(value)"
        }
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}
