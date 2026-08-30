import AppKit
import SwiftUI

// Pins as a Vault mode: source list + inspector.

extension VaultView {
    var pinsList: some View {
        WorkspaceSourceList(
            selection: $pinSelection,
            isEmpty: filteredPins.isEmpty,
            emptyIcon: searchText.isEmpty ? "pin-off" : "search",
            emptyTitle: searchText.isEmpty ? "No pins yet" : "No matches",
            emptyMessage: searchText.isEmpty
                ? "Pin a panel result, or save a link here."
                : "Try a different search term."
        ) {
            ForEach(filteredPins) { pin in
                WorkspaceListRow(
                    title: pin.title,
                    subtitle: pinSubtitle(pin),
                    icon: pin.kind == .link ? "link" : "pin"
                )
                .tag(pin.id)
                .workspaceSourceRow()
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        pendingDeletePinID = pin.id
                    }
                }
            }
        } footer: {
            SettingsListFooter {
                SettingsIconButton(icon: "plus", help: "Pin a link") {
                    linkTitle = ""
                    linkURL = ""
                    showingLinkSheet = true
                }
                SettingsIconButton(
                    icon: "minus",
                    enabled: pinSelection != nil,
                    help: "Delete pin"
                ) {
                    pendingDeletePinID = pinSelection
                }
            }
        }
    }

    @ViewBuilder
    var pinInspector: some View {
        if let pin = selectedPin {
            WorkspaceInspector {
                WorkspaceChromeBar {
                    Text(pin.title)
                        .font(BeruType.section)
                        .foregroundStyle(BeruColor.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SettingsIconButton(icon: "trash-2", help: "Delete pin") {
                        pendingDeletePinID = pin.id
                    }
                }
            } main: {
                ScrollView {
                    pinBody(for: pin)
                        .padding(BeruMetrics.workspaceInspectorPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } footer: {
                pinFooter(for: pin)
            }
        } else {
            BeruEmptyState(
                icon: "pin",
                title: "No pin selected",
                message: "Pin a panel result, or save a link."
            ) {
                SettingsPillButton(title: "Pin link", leadingIcon: "link") {
                    showingLinkSheet = true
                }
            }
        }
    }

    @ViewBuilder
    func pinBody(for pin: VaultPin) -> some View {
        SettingsSection(
            title: pin.kind == .link ? "Link" : "Snippet",
            subtitle: pin.kind == .link
                ? "Opens in the browser."
                : "Saved from a panel result or a note."
        ) {
            if pin.kind == .link, let url = pin.url, !url.isEmpty {
                Text(url)
                    .font(BeruType.body)
                    .foregroundStyle(BeruColor.link)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .settingsEditorSurface()
            } else {
                Text(pin.body?.isEmpty == false ? (pin.body ?? "") : "—")
                    .font(BeruType.body)
                    .foregroundStyle(BeruColor.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .settingsEditorSurface()
            }
        }
    }

    func pinFooter(for pin: VaultPin) -> some View {
        WorkspaceChromeBar {
            if pin.kind == .run, let body = pin.body, !body.isEmpty {
                SettingsPrimaryButton(title: "Enhance", icon: "sparkles") {
                    model.enhanceText(body)
                }
            }
            if pin.kind == .link, let url = pin.url {
                SettingsPrimaryButton(title: "Open", icon: "arrow-up-right") {
                    openURL(url)
                }
            }
            SettingsPillButton(title: "Copy") {
                let text = pin.kind == .link ? (pin.url ?? pin.title) : (pin.body ?? pin.title)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                store.flashStatus("Copied pin")
            }
            if let noteID = pin.sourceNoteID, store.note(id: noteID) != nil {
                SettingsPillButton(title: "Open note") {
                    pane = .notes
                    selection = noteID
                }
            }
            Spacer(minLength: 0)
        }
    }

    func pinSubtitle(_ pin: VaultPin) -> String {
        if pin.kind == .link {
            return pin.url ?? "Link"
        }
        guard let body = pin.body, !body.isEmpty else { return "Snippet" }
        return body.replacingOccurrences(of: "\n", with: " ")
    }

    func deletePin(id: String) {
        store.deletePin(id: id)
        pinSelection = store.pins.first?.id
        VaultSelectionMemory.persistPin(pinSelection)
    }

    var canPinLink: Bool {
        VaultLink.normalizedURL(from: linkURL) != nil
    }

    var linkSheet: some View {
        VStack(alignment: .leading, spacing: BeruSpace.md) {
            Text("Pin link")
                .font(BeruType.section)
                .foregroundStyle(BeruColor.textPrimary)
            SettingsField(placeholder: "Title", text: $linkTitle, width: 364)
            SettingsField(placeholder: "https://", text: $linkURL, width: 364)
            Text("Only http and https links can be pinned.")
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
            HStack {
                Spacer()
                SettingsPillButton(title: "Cancel") { showingLinkSheet = false }
                    .keyboardShortcut(.cancelAction)
                SettingsPrimaryButton(
                    title: "Pin",
                    enabled: canPinLink
                ) {
                    if let pin = store.addLinkPin(title: linkTitle, url: linkURL) {
                        showPin(pin)
                    }
                    showingLinkSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(BeruSpace.lg)
        .frame(width: 420)
    }

    func openURL(_ string: String) {
        guard let url = VaultLink.normalizedURL(from: string) else {
            store.flashStatus("Only http and https links can be opened")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
