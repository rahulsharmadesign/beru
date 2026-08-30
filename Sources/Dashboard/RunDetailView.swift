import AppKit
import SwiftUI

/// One run in full: what you wrote, what came back, what changed, and why.
///
/// The diff is computed here rather than stored. `WordDiff` is deterministic,
/// so recomputing costs nothing that storing would save, and it keeps the log
/// free of a derived field that would have to be versioned alongside the
/// algorithm.
struct RunDetailView: View {
    let run: UsageRun
    var dashboard: DashboardModel

    @State private var showChanges = true
    @State private var copied = false
    @State private var pinned = false

    var body: some View {
        WorkspaceInspector {
            WorkspaceChromeBar {
                header
            }
        } main: {
            ScrollView {
                VStack(alignment: .leading, spacing: BeruSpace.md) {
                    textBlock(title: "Your text", text: run.inputText)
                    resultBlock
                    if let rationale = run.rationale {
                        why(rationale)
                    }
                    factsBar
                }
                .padding(BeruMetrics.workspaceInspectorPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } footer: {
            actionsBar
        }
        .id(run.id)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: BeruSpace.sm) {
            VStack(alignment: .leading, spacing: BeruSpace.xxs) {
                Text(run.actionName ?? run.actionID ?? "Run")
                    .font(BeruType.section)
                    .lineLimit(1)
                if let app = run.hostAppName {
                    Text(app)
                        .font(BeruType.footnote)
                        .foregroundStyle(BeruColor.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(BeruType.footnote)
                .foregroundStyle(BeruColor.textSecondary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    // MARK: - Text blocks

    private func textBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: BeruSpace.xs) {
            sectionLabel(title)
            Text(text.isEmpty ? "—" : text)
                .textSelection(.enabled)
                .font(BeruSans.rowCaption)
                .foregroundStyle(SettingsTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsEditorSurface()
        }
    }

    @ViewBuilder
    private var resultBlock: some View {
        if let output = run.outputText {
            let ops = diffOps(original: run.inputText, revised: output)
            VStack(alignment: .leading, spacing: BeruSpace.xs) {
                HStack(spacing: BeruSpace.xs) {
                    sectionLabel("Result")
                    Spacer()
                    if ops != nil {
                        SettingsTogglePill(title: "Show changes", isOn: $showChanges)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                DiffView(
                    ops: ops,
                    revised: output,
                    showDiff: showChanges && ops != nil,
                    scrolls: false
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsEditorSurface()

                if ops == nil {
                    Text("No change view — the result keeps too little of your original wording for a readable word-by-word comparison.")
                        .font(BeruSans.footnote)
                        .foregroundStyle(SettingsTheme.textSecondary)
                }
            }
        } else if case .failed(let message) = run.outcome {
            VStack(alignment: .leading, spacing: BeruSpace.xs) {
                sectionLabel("What happened")
                Text(message ?? "The generation failed.")
                    .font(BeruSans.rowCaption)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .settingsEditorSurface()
            }
        }
    }

    /// Mirrors the panel's rule: below the legibility floor the two texts share
    /// no skeleton and the renderer interleaves unrelated sentences, which looks
    /// corrupted even when the result is correct.
    private func diffOps(original: String, revised: String) -> [DiffOp]? {
        guard !original.isEmpty, !revised.isEmpty else { return nil }
        let ops = WordDiff.diff(original: original, revised: revised)
        guard WordDiff.retentionRatio(ops) >= PanelEngine.diffLegibilityFloor else { return nil }
        guard ops.contains(where: { if case .equal = $0 { return false } else { return true } }) else {
            return nil
        }
        return ops
    }

    private func why(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: BeruSpace.hair) {
            Text("Why this changed")
                .font(BeruSans.rowTitle)
                .foregroundStyle(SettingsTheme.textPrimary)
            Text(text)
                .font(BeruSans.rowCaption)
                .foregroundStyle(SettingsTheme.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsEditorSurface()
    }

    // MARK: - Facts

    private var factsBar: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 92), alignment: .leading)],
            alignment: .leading,
            spacing: BeruSpace.sm
        ) {
            fact("Model", run.model ?? "—")
            fact("Target", targetName)
            fact("Took", run.totalMs.map { "\(String(format: "%.1f", Double($0) / 1000)) s" } ?? "—")
            fact("Tokens", tokenSummary)
            fact("Outcome", run.outcome.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsEditorSurface()
    }

    private var targetName: String {
        guard let id = run.targetID else { return "—" }
        return TargetRegistry.shared.profile(withID: id)?.name ?? id
    }

    private var tokenSummary: String {
        guard let input = run.inputTokens, let output = run.outputTokens else { return "—" }
        return "\(input) → \(output) est."
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: BeruSpace.hair) {
            Text(label)
                .font(BeruSans.footnote)
                .foregroundStyle(SettingsTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.2)
            Text(value)
                .font(BeruSans.control)
                .foregroundStyle(SettingsTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionsBar: some View {
        WorkspaceChromeBar {
            SettingsPrimaryButton(title: "Enhance again", enabled: run.enhanceAgainText != nil) {
                guard let text = run.enhanceAgainText else { return }
                dashboard.enhanceText(text)
            }

            SettingsPillButton(title: pinned ? "Pinned" : "Pin") {
                guard let body = run.resultForVault else { return }
                _ = VaultStore.shared.pinResult(
                    title: run.suggestedVaultTitle,
                    body: body,
                    actionID: run.actionID
                )
                pinned = true
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    pinned = false
                }
            }
            .disabled(run.resultForVault == nil)

            SettingsPillButton(title: "Save as note") {
                guard let body = run.resultForVault else { return }
                let note = VaultStore.shared.createNote(
                    title: run.suggestedVaultTitle,
                    body: body
                )
                dashboard.openVaultNote(note.id)
            }
            .disabled(run.resultForVault == nil)

            SettingsPillButton(title: copied ? "Copied" : "Copy result") {
                guard let output = run.outputText else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(output, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    copied = false
                }
            }
            .disabled(run.outputText == nil)

            SettingsPillButton(title: "Copy your text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(run.inputText, forType: .string)
            }
            .disabled(run.inputText.isEmpty)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(BeruSans.footnote)
            .foregroundStyle(SettingsTheme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.3)
    }
}
