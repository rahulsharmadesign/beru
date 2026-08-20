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

    @State private var showChanges = true
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DashboardMetrics.md) {
                    header
                    textBlock(title: "Your text", text: run.inputText)
                    resultBlock
                    if let rationale = run.rationale {
                        why(rationale)
                    }
                    factsBar
                }
                .padding(SettingsChrome.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, minHeight: 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)

            SettingsHeaderRule()
            actionsBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsTheme.window)
        .id(run.id)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(run.actionName ?? run.actionID ?? "Run")
                    .font(BeruSans.section)
                    .foregroundStyle(SettingsTheme.textPrimary)
                    .lineLimit(1)
                if let app = run.hostAppName {
                    Text(app)
                        .font(BeruSans.footnote)
                        .foregroundStyle(SettingsTheme.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, BeruSpace.xs)
                        .padding(.vertical, BeruSpace.hair)
                        .background(SettingsTheme.badgeBg, in: Capsule())
                        .fixedSize()
                }
                Spacer(minLength: 8)
                Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(BeruSans.footnote)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Text blocks

    private func textBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
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
            VStack(alignment: .leading, spacing: 8) {
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
            spacing: 12
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
        HStack(spacing: 8) {
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
        .padding(.horizontal, SettingsChrome.contentPadding)
        .padding(.vertical, BeruSpace.sm)
        .fixedSize(horizontal: false, vertical: true)
        .background(SettingsTheme.window)
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
