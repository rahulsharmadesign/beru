import SwiftUI

// The note editor: column, bar and footer.

extension VaultView {
    @ViewBuilder
    var editorColumn: some View {
        if let note = selected {
            WorkspaceInspector {
                WorkspaceChromeBar {
                    TextField("Title", text: binding(for: note).title)
                        .textFieldStyle(.plain)
                        .font(BeruType.heading3)
                        .foregroundStyle(BeruColor.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SettingsSegmented(
                        selection: $showingPreview,
                        options: [
                            SettingsPickerOption(value: false, title: "Edit"),
                            SettingsPickerOption(value: true, title: "Preview"),
                        ],
                        accessibilityLabel: "Editor mode"
                    )
                    SettingsIconButton(icon: "trash-2", help: "Delete note") {
                        pendingDeleteID = note.id
                    }
                }
            } main: {
                Group {
                    if showingPreview {
                        ScrollView {
                            MarkdownPreview(text: note.body)
                                .padding(BeruMetrics.workspaceInspectorPadding)
                                .frame(maxWidth: BeruMetrics.formMaxWidth, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        TextEditor(text: binding(for: note).body)
                            .font(BeruType.control)
                            .foregroundStyle(BeruColor.textPrimary)
                            .scrollContentBackground(.hidden)
                            .dashboardEditorCanvas()
                            .padding(BeruMetrics.workspaceInspectorPadding)
                            .frame(maxWidth: BeruMetrics.formMaxWidth)
                            .frame(maxWidth: .infinity)
                    }
                }
            } footer: {
                editorFooter(for: note)
            }
        } else {
            BeruEmptyState(
                icon: "sticky-note",
                title: "No note selected",
                message: "Create a note to start writing."
            ) {
                SettingsPrimaryButton(title: "New Note", icon: "plus") {
                    selection = store.createNote().id
                }
            }
        }
    }

    func editorFooter(for note: VaultNote) -> some View {
        let hasBody = !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let words = note.body.split { $0.isWhitespace }.count
        return WorkspaceChromeBar {
            SettingsPrimaryButton(
                title: "Enhance this note",
                icon: "sparkles",
                enabled: hasBody
            ) {
                model.enhanceNote(note.id)
            }
            SettingsPillButton(title: "Pin note", enabled: hasBody, leadingIcon: "pin") {
                let pin = store.pinResult(
                    title: note.title,
                    body: note.body,
                    noteID: note.id
                )
                showPin(pin)
            }
            Spacer(minLength: 0)
            if hasBody {
                Text("\(words) \(words == 1 ? "word" : "words")")
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .lineLimit(1)
            }
            Text(note.updatedAt, style: .relative)
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
                .lineLimit(1)
                .layoutPriority(-1)
        }
    }

    func binding(for note: VaultNote) -> Binding<VaultNote> {
        Binding(
            get: { store.note(id: note.id) ?? note },
            set: { store.updateNote($0) }
        )
    }

    // MARK: - Pins
}
