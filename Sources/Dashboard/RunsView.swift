import AppKit
import SwiftUI

/// All Runs: browse what Beru has done, with the diff and the model's
/// explanation kept alongside each result.
struct RunsView: View {
    @State private var model = RunsModel()

    var body: some View {
        SettingsWorkspace(title: "Runs", subtitle: DashboardRoute.runs.pageSubtitle) {
            Group {
                if model.isRecordingDisabled {
                    recordingOff
                } else if !model.hasLoaded {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading runs…")
                            .font(BeruSans.rowCaption)
                            .foregroundStyle(SettingsTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.runs.isEmpty {
                    nothingRecorded
                } else {
                    browser
                }
            }
        }
        .tint(DashboardTheme.accent)
        .task { await model.load() }
    }

    private var recordingOff: some View {
        VStack(spacing: 12) {
            BeruIcon(name: "pause", size: 32)
                .foregroundStyle(SettingsTheme.textSecondary)
            Text("History recording is off")
                .font(BeruSans.section)
                .foregroundStyle(SettingsTheme.textPrimary)
            Text("New runs are not being recorded. Anything recorded before still exists on disk and will reappear here when you switch recording back on.")
                .font(BeruSans.rowCaption)
                .foregroundStyle(SettingsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            SettingsPillButton(title: "Turn recording on") {
                SettingsStore.shared.usageLoggingEnabled = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsTheme.window)
    }

    private var nothingRecorded: some View {
        VStack(spacing: 12) {
            BeruIcon(name: "history", size: 32)
                .foregroundStyle(SettingsTheme.textSecondary)
            Text("No runs yet")
                .font(BeruSans.section)
                .foregroundStyle(SettingsTheme.textPrimary)
            Text("Select text in any app and press the hotkey. Each run is kept here with its changes and the reason behind them.")
                .font(BeruSans.rowCaption)
                .foregroundStyle(SettingsTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsTheme.window)
    }

    private var browser: some View {
        VStack(spacing: 0) {
            filterBar
            SettingsSplitView {
                list
            } detail: {
                detail
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsTheme.window)
    }

    private var filterBar: some View {
        SettingsWorkspaceToolbar {
            SettingsSearchField(text: $model.query, placeholder: "Search runs")
                .frame(maxWidth: 260)

            if !model.knownActions.isEmpty {
                SettingsMenuPill(
                    selection: Binding(
                        get: { model.actionFilter ?? "" },
                        set: { model.actionFilter = $0.isEmpty ? nil : $0 }
                    ),
                    label: model.knownActions.first { $0.id == model.actionFilter }?.name ?? "Any action"
                ) {
                    Button("Any action") { model.actionFilter = nil }
                    ForEach(model.knownActions, id: \.id) { action in
                        Button(action.name) { model.actionFilter = action.id }
                    }
                }
                .accessibilityLabel("Action")
            }

            if !model.knownApps.isEmpty {
                SettingsMenuPill(
                    selection: Binding(
                        get: { model.appFilter ?? "" },
                        set: { model.appFilter = $0.isEmpty ? nil : $0 }
                    ),
                    label: model.appFilter ?? "Any app"
                ) {
                    Button("Any app") { model.appFilter = nil }
                    ForEach(model.knownApps, id: \.self) { app in
                        Button(app) { model.appFilter = app }
                    }
                }
                .accessibilityLabel("App")
            }

            SettingsTogglePill(title: "Accepted only", isOn: $model.acceptedOnly)
                .help("Show only runs you replaced or copied")
        }
    }

    private var list: some View {
        Group {
            let runs = model.filtered
            if runs.isEmpty {
                VStack(spacing: 8) {
                    BeruIcon(name: "list-filter", size: 28)
                        .foregroundStyle(SettingsTheme.textSecondary)
                    Text("No matches")
                        .font(BeruSans.rowTitle)
                        .foregroundStyle(SettingsTheme.textPrimary)
                    Text("Adjust the search or filters to see more runs.")
                        .font(BeruSans.rowCaption)
                        .foregroundStyle(SettingsTheme.textSecondary)
                    SettingsPillButton(title: "Clear filters") {
                        model.query = ""
                        model.actionFilter = nil
                        model.appFilter = nil
                        model.acceptedOnly = false
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, SettingsChrome.contentPadding)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(grouped(runs), id: \.day) { section in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(BeruSans.sidebarHeader)
                                    .foregroundStyle(SettingsTheme.textSecondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 10)
                                    .padding(.bottom, 4)
                                ForEach(section.runs) { run in
                                    Button {
                                        model.selection = run.id
                                    } label: {
                                        RunRow(run: run, isSelected: model.selection == run.id)
                                    }
                                    .buttonStyle(.plain)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardChrome.sidebarSurface)
        .onChange(of: model.filtered.map(\.id)) { _, ids in
            if let selected = model.selection, ids.contains(selected) { return }
            model.selection = ids.first
        }
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            if let run = model.run(withID: model.selection) {
                RunDetailView(run: run)
            } else {
                BeruEmptyState(
                    icon: "history",
                    title: "Select a run",
                    message: "Choose a run from the list to see its diff and the reason behind it."
                )
            }
        }
        .settingsWorkspacePane()
    }

    private struct DaySection {
        let day: Date
        let title: String
        let runs: [UsageRun]
    }

    private func grouped(_ runs: [UsageRun]) -> [DaySection] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: runs) { calendar.startOfDay(for: $0.startedAt) }
        return byDay.keys.sorted(by: >).map { day in
            DaySection(day: day, title: Self.dayTitle(day), runs: byDay[day] ?? [])
        }
    }

    static func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let formatter = DateFormatter()
        if let days = calendar.dateComponents([.day], from: day, to: Date()).day, days < 7 {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateStyle = .medium
        }
        return formatter.string(from: day)
    }
}

private struct RunRow: View {
    let run: UsageRun
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(run.actionName ?? run.actionID ?? "Run")
                    .font(BeruSans.rowTitle)
                    .foregroundStyle(isSelected ? SettingsTheme.onActive : SettingsTheme.textPrimary)
                    .lineLimit(1)
                if let app = run.hostAppName {
                    Text(app)
                        .font(BeruSans.footnote)
                        .foregroundStyle(isSelected ? SettingsTheme.onActive.opacity(0.72) : SettingsTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(run.startedAt, style: .time)
                    .font(BeruSans.footnote)
                    .foregroundStyle(isSelected ? SettingsTheme.onActive.opacity(0.72) : SettingsTheme.textSecondary)
                    .fixedSize()
            }
            Text(run.summaryLine)
                .font(BeruSans.footnote)
                .foregroundStyle(isSelected ? SettingsTheme.onActive.opacity(0.72) : SettingsTheme.textSecondary)
                .lineLimit(2)
            HStack(spacing: 6) {
                SavingsBadge(saved: run.savedTokens, onAccent: isSelected)
                OutcomeBadge(outcome: run.outcome, onAccent: isSelected)
                if run.generationCount > 1 {
                    Text("\(run.generationCount) tries")
                        .badgeStyle(color: SettingsTheme.textSecondary, onAccent: isSelected)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous)
                .fill(isSelected ? SettingsTheme.active : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: SettingsChrome.rowRadius, style: .continuous))
    }
}

private struct SavingsBadge: View {
    let saved: Int?
    var onAccent: Bool

    var body: some View {
        if let saved, saved != 0 {
            Text(saved > 0 ? "↘ −\(saved) tok" : "↗ +\(abs(saved)) tok")
                .badgeStyle(color: SettingsTheme.active, onAccent: onAccent)
        }
    }
}

private struct OutcomeBadge: View {
    let outcome: UsageRun.Outcome
    var onAccent: Bool

    var body: some View {
        Text(outcome.label)
            .badgeStyle(
                color: outcome.wasAccepted ? SettingsTheme.active : SettingsTheme.textSecondary,
                onAccent: onAccent
            )
    }
}

private extension View {
    func badgeStyle(color: Color, onAccent: Bool) -> some View {
        font(BeruSans.footnote)
            .foregroundStyle(onAccent ? SettingsTheme.onActive : color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                (onAccent ? SettingsTheme.onActive.opacity(0.18) : color.opacity(0.12)),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }
}
