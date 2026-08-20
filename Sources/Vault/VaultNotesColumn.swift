import SwiftUI

// The notes list and its rows.

extension VaultView {
    var notesColumn: some View {
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

    func noteRow(_ note: VaultNote) -> some View {
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

    func deleteNote(id: String) {
        store.deleteNote(id: id)
        selection = store.notes.first?.id
    }

    // MARK: - Editor + optional pins
}
