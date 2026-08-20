import AppKit
import SwiftUI

// Pinned snippets and the add-link sheet.

extension VaultView {
    var pinsColumn: some View {
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

    func pinRow(_ pin: VaultPin) -> some View {
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

    var linkSheet: some View {
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

    func openURL(_ string: String) {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") {
            value = "https://\(value)"
        }
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}
