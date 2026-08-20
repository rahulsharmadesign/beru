import AppKit
import SwiftUI

// Moved out of Sources/Settings/SettingsView.swift, which held five
// unrelated pages in one 622-line file and no longer contained a
// SettingsView at all. These are dashboard pages, so they live with the
// dashboard; SettingsStore stays the single place they read and write.

struct HistorySettingsTab: View {
    @Bindable private var settings = SettingsStore.shared
    @State private var stats: UsageLogWriter.Stats?
    @State private var showClearConfirmation = false

    var body: some View {
        SettingsPage(title: "Data", subtitle: DashboardRoute.data.pageSubtitle) {
            SettingsSection(title: "Savings", subtitle: "Token estimates from accepted panel results.") {
                SavingsSummaryView(style: .plain)
            }

            SettingsSection(title: "Recording", subtitle: "Local usage history on this Mac.") {
                SettingsRow(
                    title: "Record usage on this Mac",
                    caption: "Off until you turn it on. Saves input and results locally. API keys are never recorded."
                ) {
                    SettingsSwitch(
                        isOn: $settings.usageLoggingEnabled,
                        accessibilityLabel: "Record usage on this Mac"
                    )
                }
                if let stats {
                    SettingsRow(title: "Entries") {
                        SettingsValue(text: "\(stats.entryCount)")
                    }
                    SettingsRow(title: "Size") {
                        SettingsValue(
                            text: ByteCountFormatter.string(fromByteCount: Int64(stats.totalBytes), countStyle: .file)
                        )
                    }
                    if let oldest = stats.oldestDate {
                        SettingsRow(title: "Oldest") {
                            SettingsValue(text: oldest.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
            }

            SettingsSection(title: "Retention", subtitle: "How long day-files are kept before deletion.") {
                SettingsRow(title: "Keep for", caption: "Whole day-files are deleted past this window.") {
                    Picker("", selection: $settings.historyRetentionDays) {
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("1 year").tag(365)
                        Text("Forever").tag(36_500)
                    }
                    .labelsHidden()
                    .accessibilityLabel("History retention")
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }

            SettingsSection(title: "Export", subtitle: "Browse or download recorded runs.") {
                SettingsRow(title: "Reveal in Finder", caption: "Opens the local history folder.") {
                    SettingsPillButton(title: "Reveal") {
                        let url = UsageLogWriter.shared.directoryURL
                        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                SettingsRow(title: "Export JSONL") {
                    SettingsPillButton(title: "Export…", action: export)
                }
                SettingsRow(title: "Export CSV") {
                    SettingsPillButton(title: "Export…", action: exportCSV)
                }
            }

            SettingsSection(title: "Danger", subtitle: "Permanent actions that cannot be undone.") {
                SettingsRow(title: "Clear history", caption: "Deletes every recorded run. Cannot be undone.") {
                    SettingsPillButton(title: "Clear…", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
            }
        }
        .task { await refreshStats() }
        .confirmationDialog(
            "Delete all recorded history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await UsageLogWriter.shared.clearAll()
                    await refreshStats()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func refreshStats() async {
        stats = await UsageLogWriter.shared.stats()
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "beru-history.jsonl"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            let data = await UsageLogWriter.shared.exportAll()
            try? data.write(to: url)
        }
    }

    /// Spreadsheet-friendly export of every session. Adds a CSV path alongside
    /// the raw JSONL so the history is usable by people who never want to see a
    /// JSON line.
    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "beru-history.csv"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            let runs = await UsageLogReader.shared.allRuns()
            let csv = Self.csv(from: runs)
            try? csv.data(using: .utf8)?.write(to: url)
        }
    }

    /// Rows for each session. Columns are what a spreadsheet user would filter
    /// for: when, which app, which action, which outcome, token accounting.
    private static func csv(from runs: [UsageRun]) -> String {
        var lines = [
            "Date,App,Action,Model,Outcome,Input chars,Output chars,Input tokens,Output tokens,Saved tokens,Generation count,Total ms,Input text,Output text"
        ]
        for run in runs {
            let date = run.startedAt.formatted(date: .abbreviated, time: .shortened)
            // Escape quotes and commas; cells that contain either get quoted.
            func cell(_ value: String?) -> String {
                guard let value, !value.isEmpty else { return "" }
                let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
                return escaped.contains(",") || escaped.contains("\n") ? "\"\(escaped)\"" : escaped
            }
            let tokens = [
                cell(run.hostAppName),
                cell(run.actionName),
                cell(run.model),
                cell(run.outcome.label),
                cell(run.inputText.count.description),
                cell(run.outputText.map { $0.count.description }),
                cell(run.inputTokens.map { $0.description }),
                cell(run.outputTokens.map { $0.description }),
                cell(run.savedTokens.map { $0.description }),
                cell(run.generationCount.description),
                cell(run.totalMs.map { $0.description }),
                cell(run.inputText),
                cell(run.outputText)
            ]
            lines.append("\(date),\(tokens.joined(separator: ","))")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
