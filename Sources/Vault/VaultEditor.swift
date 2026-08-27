import SwiftUI

// The note editor: pane, column, bar and footer.

extension VaultView {
    var editorPane: some View {
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
    }

    @ViewBuilder
    var editorColumn: some View {
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
                SettingsHeaderRule()
                editorFooter(for: note)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        }
    }

    func editorBar(for note: VaultNote) -> some View {
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
    }

    func editorFooter(for note: VaultNote) -> some View {
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
    }

    func binding(for note: VaultNote) -> Binding<VaultNote> {
        Binding(
            get: { store.note(id: note.id) ?? note },
            set: { store.updateNote($0) }
        )
    }

    // MARK: - Pins
}
