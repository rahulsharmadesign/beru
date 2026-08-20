import AppKit
import SwiftUI

/// Local vault: notes list + markdown editor, with pins alongside.
struct VaultView: View {
    @Bindable var model: DashboardModel
    /// @Bindable, not @State: a shared singleton held in @State is captured once
    /// and never re-observed, so the list could miss a note saved elsewhere.
    @Bindable var store = VaultStore.shared
    @State var selection: String?
    @State var showingPreview = false
    @State var showingPins = true
    @State var showingLinkSheet = false
    @State var linkTitle = ""
    @State var linkURL = ""
    @State var searchText = ""

    var selected: VaultNote? {
        store.note(id: selection ?? "")
    }

    /// Notes matching the search query, in title or body. Empty query returns
    /// them all — an empty result then reads as "no search hits", not "broken".
    var filteredNotes: [VaultNote] {
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

    func prepare() {
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

    var toolbar: some View {
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

    var displayPath: String {
        store.rootURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    // MARK: - Notes list
}
