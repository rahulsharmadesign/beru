import SwiftUI

/// Lifetime savings for Data.
struct SavingsSummaryView: View {
    enum Style {
        case plain
        case card
    }

    var style: Style = .card

    @Bindable private var savings = SavingsStore.shared
    @State private var showResetConfirmation = false

    var body: some View {
        standardBody
        .confirmationDialog(
            "Reset lifetime token savings?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { savings.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The running totals go back to zero. Recorded history is not touched.")
        }
    }

    private var standardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: BeruSpace.xs) {
                Text(headline)
                    .font(BeruSans.rowTitle)
                    .foregroundStyle(SettingsTheme.textPrimary)
                    .monospacedDigit()
                Spacer(minLength: 8)
                if savings.hasData {
                    SettingsPillButton(title: "Reset") { showResetConfirmation = true }
                }
            }

            if savings.hasData {
                meter
                Text(subtitle)
                    .font(BeruSans.footnote)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Replace or Copy a result and the savings land here.")
                    .font(BeruSans.footnote)
                    .foregroundStyle(SettingsTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(style == .card ? BeruSpace.md : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if style == .card {
                BeruRadius.shape()
                    .fill(SettingsTheme.badgeBg)
            }
        }
    }

    private var headline: String {
        guard savings.hasData else { return "No savings recorded yet" }
        return tokenHeadline
    }

    private var tokenHeadline: String {
        Self.number(abs(savings.totalSavedTokens))
    }

    private var subtitle: String {
        var parts = [
            "\(Self.number(savings.acceptedRuns)) accepted "
                + (savings.acceptedRuns == 1 ? "result" : "results")
        ]
        if let since = savings.trackingSince {
            parts.append("since \(since.formatted(date: .abbreviated, time: .omitted))")
        }
        let direction = savings.totalSavedTokens < 0 ? "longer" : "leaner"
        parts.append("\(savings.percent)% \(direction) overall")
        return parts.joined(separator: " · ")
    }

    private var meter: some View {
        VStack(alignment: .leading, spacing: BeruSpace.xxs) {
            GeometryReader { geometry in
                let share = savings.totalInputTokens > 0
                    ? min(1, Double(savings.totalOutputTokens) / Double(savings.totalInputTokens))
                    : 1
                Capsule()
                    .fill(SettingsTheme.border)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(SettingsTheme.active)
                            .frame(width: max(3, geometry.size.width * share))
                    }
            }
            .frame(height: 5)

            HStack {
                Text("\(Self.number(savings.totalInputTokens)) in")
                Spacer()
                Text("\(Self.number(savings.totalOutputTokens)) out")
            }
            .font(BeruSans.footnote)
            .foregroundStyle(SettingsTheme.textSecondary)
            .monospacedDigit()
        }
    }

    private static func number(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}
