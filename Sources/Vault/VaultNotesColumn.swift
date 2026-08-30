import SwiftUI

// The notes list and its rows.

extension VaultView {
    var notesColumn: some View {
        WorkspaceSourceList(
            selection: $selection,
            isEmpty: filteredNotes.isEmpty,
            emptyIcon: searchText.isEmpty ? "sticky-note" : "search",
            emptyTitle: searchText.isEmpty ? "No notes yet" : "No matches",
            emptyMessage: searchText.isEmpty
                ? "Write a note, or import a vault from Folder."
                : "Try a different search term."
        ) {
            ForEach(filteredNotes) { note in
                WorkspaceListRow(
                    title: note.title.isEmpty ? "Untitled" : note.title,
                    subtitle: note.preview,
                    icon: "sticky-note",
                    accessory: {
                        Text(note.updatedAt, style: .relative)
                            .lineLimit(1)
                            .fixedSize()
                    }
                )
                .tag(note.id)
                .workspaceSourceRow()
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        pendingDeleteID = note.id
                    }
                }
            }
        } footer: {
            SettingsListFooter {
                SettingsIconButton(icon: "plus", help: "New note") {
                    let created = store.createNote()
                    selection = created.id
                    showingPreview = false
                }
                SettingsIconButton(icon: "minus", enabled: selection != nil, help: "Delete note") {
                    pendingDeleteID = selection
                }
            }
        }
    }

    func deleteNote(id: String) {
        store.deleteNote(id: id)
        selection = store.notes.first?.id
        VaultSelectionMemory.persist(selection)
    }

    // MARK: - Editor
}
