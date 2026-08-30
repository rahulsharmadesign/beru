import AppKit
import SwiftUI

/// All Runs: browse what Beru has done, with the diff and the model's
/// explanation kept alongside each result.
struct RunsView: View {
    var dashboard: DashboardModel
    @State private var model = RunsModel()

    var body: some View {
        SettingsWorkspace(title: "Runs", subtitle: DashboardRoute.runs.pageSubtitle) {
            Group {
                if model.isRecordingDisabled {
                    recordingOff
                } else if !model.hasLoaded {
                    VStack(spacing: BeruSpace.sm) {
                        ProgressView()
                        Text("Loading runs…")
                            .font(BeruType.footnote)
                            .foregroundStyle(BeruColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.runs.isEmpty {
                    nothingRecorded
                } else {
                    browser
                }
            }
        }
        .tint(BeruColor.accent)
        .task { await model.load() }
    }

    private var recordingOff: some View {
        BeruEmptyState(
            icon: "pause",
            title: "History recording is off",
            message: "New runs are not being recorded. Anything recorded before still exists on disk and will reappear here when you switch recording back on."
        ) {
            SettingsPrimaryButton(title: "Turn recording on") {
                SettingsStore.shared.usageLoggingEnabled = true
            }
        }
    }

    private var nothingRecorded: some View {
        BeruEmptyState(
            icon: "history",
            title: "No runs yet",
            message: "Select text in any app and press the hotkey. Each run is kept here with its changes and the reason behind them."
        )
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
        let runs = model.filtered
        return Group {
            if runs.isEmpty {
                BeruEmptyState(
                    icon: "search",
                    title: "No matches",
                    message: "Adjust the search or filters to see more runs."
                ) {
                    SettingsPillButton(title: "Clear filters") {
                        model.query = ""
                        model.actionFilter = nil
                        model.appFilter = nil
                        model.acceptedOnly = false
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DashboardChrome.sidebarSurface)
            } else {
                WorkspaceSourceList(
                    selection: $model.selection,
                    isEmpty: false,
                    emptyIcon: "search",
                    emptyTitle: "No matches",
                    emptyMessage: "Adjust the search or filters to see more runs."
                ) {
                    ForEach(grouped(runs), id: \.day) { section in
                        Section(section.title) {
                            ForEach(section.runs) { run in
                                RunRow(run: run)
                                    .tag(run.id)
                                    .workspaceSourceRow()
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: model.filtered.map(\.id)) { _, ids in
            if let selected = model.selection, ids.contains(selected) { return }
            model.selection = ids.first
        }
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            if let run = model.run(withID: model.selection) {
                RunDetailView(run: run, dashboard: dashboard)
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

    var body: some View {
        WorkspaceListRow(
            title: run.actionName ?? run.actionID ?? "Run",
            subtitle: run.summaryLine,
            icon: ActionRegistry.shared.action(withID: run.actionID ?? "")?.icon ?? "history",
            accessory: {
                HStack(spacing: BeruSpace.xs) {
                    if let app = run.hostAppName {
                        Text(app)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Text(run.startedAt, style: .time)
                        .fixedSize()
                }
            }
        )
    }
}
