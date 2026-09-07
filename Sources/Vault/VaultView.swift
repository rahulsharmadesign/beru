import AppKit
import SwiftUI

/// Local vault: Notes or Pins, never both at once.
struct VaultView: View {
    @Bindable var model: DashboardModel
    /// @Bindable, not @State: a shared singleton held in @State is captured once
    /// and never re-observed, so the list could miss a note saved elsewhere.
    @Bindable var store = VaultStore.shared
    @State var pane: VaultPane = .notes
    @State var selection: String?
    @State var pinSelection: String?
    @State var showingPreview = false
    @State var showingLinkSheet = false
    @State var linkTitle = ""
    @State var linkURL = ""
    @State var searchText = ""
    @State var pendingDeleteID: String?
    @State var pendingDeletePinID: String?

    var selected: VaultNote? {
        store.note(id: selection ?? "")
    }

    var selectedPin: VaultPin? {
        store.pins.first { $0.id == pinSelection }
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

    var filteredPins: [VaultPin] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return store.pins }
        return store.pins.filter { pin in
            pin.title.lowercased().contains(needle)
                || (pin.url?.lowercased().contains(needle) ?? false)
                || (pin.body?.lowercased().contains(needle) ?? false)
        }
    }

    var body: some View {
        SettingsWorkspace(
            title: DashboardRoute.vault.title,
            subtitle: DashboardRoute.vault.pageSubtitle,
            icon: DashboardRoute.vault.lucideIcon
        ) {
            VStack(spacing: 0) {
                toolbar
                Group {
                    if pane == .notes {
                        SettingsSplitView {
                            notesColumn
                        } detail: {
                            editorColumn
                        }
                    } else {
                        SettingsSplitView {
                            pinsList
                        } detail: {
                            pinInspector
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .tint(BeruColor.accent)
        .onAppear(perform: prepare)
        .onChange(of: model.pendingVaultNoteID) { _, id in
            applyPendingVaultNote(id)
        }
        .sheet(isPresented: $showingLinkSheet) {
            linkSheet
        }
        .onChange(of: selection) { _, id in
            VaultSelectionMemory.persist(id)
        }
        .onChange(of: pinSelection) { _, id in
            VaultSelectionMemory.persistPin(id)
        }
        .onChange(of: pane) { _, newPane in
            VaultSelectionMemory.persistPane(newPane)
            if newPane == .pins { ensurePinSelection() }
        }
        .confirmationDialog(
            "Delete this note?",
            isPresented: deleteConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID { deleteNote(id: id) }
                pendingDeleteID = nil
            }
        } message: {
            Text("The markdown file is removed from this Mac.")
        }
        .confirmationDialog(
            "Delete this pin?",
            isPresented: deletePinConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeletePinID { deletePin(id: id) }
                pendingDeletePinID = nil
            }
        } message: {
            Text("The pin is removed. Notes are unchanged.")
        }
    }

    func prepare() {
        store.reload()
        pane = VaultSelectionMemory.restoredPane()
        pinSelection = VaultSelectionMemory.restoredPinID(from: store.pins)
        if applyPendingVaultNote(model.pendingVaultNoteID) { return }
        if store.notes.isEmpty {
            let welcome = store.createNote(
                title: "Welcome",
                body: """
                # Welcome to your vault

                Write notes here. They stay on this Mac as markdown files.

                - Click **Enhance this note** to open Beru on this text
                - **Apply** in the panel writes the result back here
                - **Pin** saves a result or link under Pins

                Choose a folder above to keep the vault in iCloud Drive or Dropbox.
                """
            )
            selection = welcome.id
            return
        }
        if let restored = VaultSelectionMemory.restoredID(from: store.notes),
           store.note(id: restored) != nil {
            selection = restored
            return
        }
        if selection == nil || store.note(id: selection ?? "") == nil {
            selection = store.notes.first?.id
        }
    }

    @discardableResult
    func applyPendingVaultNote(_ id: String?) -> Bool {
        guard let id, store.note(id: id) != nil else { return false }
        pane = .notes
        selection = id
        model.pendingVaultNoteID = nil
        return true
    }

    func showPin(_ pin: VaultPin) {
        pane = .pins
        pinSelection = pin.id
    }

    func ensurePinSelection() {
        if let pinSelection, filteredPins.contains(where: { $0.id == pinSelection }) { return }
        pinSelection = filteredPins.first?.id
    }

    var deleteConfirmPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteID != nil },
            set: { if !$0 { pendingDeleteID = nil } }
        )
    }

    var deletePinConfirmPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletePinID != nil },
            set: { if !$0 { pendingDeletePinID = nil } }
        )
    }

    // MARK: - Toolbar

    var toolbar: some View {
        SettingsWorkspaceToolbar {
            SettingsSearchField(
                text: $searchText,
                placeholder: pane == .notes ? "Search notes" : "Search pins"
            )
            .frame(maxWidth: BeruMetrics.toolbarSearchWidth)

            SettingsSegmented(
                selection: $pane,
                options: VaultPane.allCases.map {
                    SettingsPickerOption(value: $0, title: $0.title)
                },
                accessibilityLabel: "Vault"
            )

            Spacer(minLength: BeruSpace.xs)

            if let status = store.statusMessage {
                Text(status)
                    .font(BeruType.footnote)
                    .foregroundStyle(BeruColor.textSecondary)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }

            SettingsOverflowMenu(title: "Folder", items: folderMenuItems)
                .help(store.rootURL.path)
        }
    }

    var displayPath: String {
        store.rootURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var folderMenuItems: [DropdownItem] {
        var items: [DropdownItem] = [
            DropdownItem(title: displayPath, isEnabled: false),
            .separator(),
            DropdownItem(title: "Choose folder…") { store.chooseRootFolder() },
        ]
        if !store.isUsingDefaultRoot {
            items.append(DropdownItem(title: "Use local folder") { store.resetToDefaultRoot() })
        }
        items.append(contentsOf: [
            .separator(),
            DropdownItem(title: "Export vault…") { store.exportZip() },
            DropdownItem(title: "Import vault…") { store.importZip() },
        ])
        return items
    }

    // MARK: - Notes list
}
