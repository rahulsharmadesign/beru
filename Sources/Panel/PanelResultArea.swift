import AppKit
import SwiftUI

// The result module and every state it can be in: idle, provider setup,
// missing accessibility, streaming, diff, and errors.

extension PanelView {
    // MARK: - Result

    var resultModule: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.truncationNotice {
                truncationBanner
            }
            resultArea
        }
        // Inset inside clipShape so placeholder copy is not sheared by the
        // card radius. Height is intrinsic — the window sizes to the stack.
        // Every tab renders plateless on the panel wash: idle text, threads,
        // diffs, and errors alike. No outer card anywhere.
        .padding(PanelMetrics.moduleInset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassModule(scrim: .chrome)
    }

    @ViewBuilder
    var resultArea: some View {
        let state = appState.resultState(for: appState.selectedActionID)
        VStack(alignment: .trailing, spacing: 0) {
            if case .done(let revised) = state,
               appState.diffs[appState.selectedActionID] != nil {
                diffResult(revised: revised)
            } else if case .error(let message) = state {
                errorView(message: message)
            } else if case .idle = state, !hasCapturedText {
                idlePlaceholder()
            } else {
                ResultView(state: state)
            }
        }
        // Short content hugs the top of the idle-tall band instead of
        // floating centered in it.
        .frame(maxWidth: .infinity, minHeight: PanelMetrics.resultIdleMinHeight, alignment: .topLeading)
        // Do not `.id` the tab or animate this swap: that scaled the result
        // copy and, with the window animator, sheared the close strip and composer.
        .animation(nil, value: appState.selectedActionID)
    }

    /// Only shown when something blocks the job: Accessibility or no model.
    /// Otherwise the composer is the empty state.
    @ViewBuilder
    func idlePlaceholder(fillsBand: Bool = true) -> some View {
        Group {
            if !a11y.isAccessibilityTrusted {
                accessibilityPlaceholder
            } else if !SettingsStore.shared.isConfigured(SettingsStore.shared.activeProvider) {
                providerSetupPlaceholder
            }
        }
        .padding(.horizontal, EnhancifySpace.lg)
        .padding(.vertical, PanelMetrics.moduleInset)
        .frame(
            maxWidth: .infinity,
            minHeight: fillsBand ? PanelMetrics.resultIdleMinHeight : 0,
            alignment: .center
        )
        .background(PanelDragRegion())
    }

    var accessibilityPlaceholder: some View {
        VStack(spacing: EnhancifySpace.sm) {
            Text("Allow Accessibility")
                .font(EnhancifyType.placeholderTitle)
                .foregroundStyle(EnhancifyColor.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("Enhancify needs Accessibility to read and replace selected text in other apps.")
                .font(EnhancifyType.placeholderHelper)
                .foregroundStyle(EnhancifyColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            EnhancifyGlassButton(
                title: "Open System Settings",
                prominent: true,
                size: .compact
            ) {
                Permissions.requestAccessibilityIfNeeded()
                Permissions.openAccessibilitySettings()
            }
            .padding(.top, EnhancifySpace.xxs)
        }
    }

    var providerSetupPlaceholder: some View {
        VStack(spacing: EnhancifySpace.sm) {
            Text("Choose your AI model")
                .font(EnhancifyType.placeholderTitle)
                .foregroundStyle(EnhancifyColor.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("Connect an AI provider or choose a local model to start using Enhancify.")
                .font(EnhancifyType.placeholderHelper)
                .foregroundStyle(EnhancifyColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            VStack(spacing: EnhancifySpace.xs) {
                EnhancifyGlassButton(
                    title: "Connect a provider",
                    prominent: true,
                    size: .compact
                ) {
                    engine.requestProviderSetup(preferLocal: false)
                }
                EnhancifyButton(title: "Use a local model", size: .compact) {
                    engine.requestProviderSetup(preferLocal: true)
                }
            }
            .padding(.top, EnhancifySpace.xxs)
        }
    }

    var truncationBanner: some View {
        Text("Selection was truncated to \(PanelEngine.maxCapturedLength) characters")
            .font(EnhancifyType.caption)
            .foregroundStyle(EnhancifyColor.textSecondary)
            .padding(.bottom, EnhancifySpace.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func diffResult(revised: String) -> some View {
        VStack(alignment: .leading, spacing: EnhancifySpace.xs) {
            DiffView(
                ops: appState.diffs[appState.selectedActionID],
                revised: revised,
                showDiff: true,
                scrolls: false,
                style: showsFullDiff ? .full : .clean
            )
            PanelHitCapsule(
                help: showsFullDiff ? "Show the finished text" : "Show what was removed and added",
                accessibilityLabel: showsFullDiff ? "Hide changes" : "Show changes"
            ) {
                showsFullDiff.toggle()
            } label: {
                Text(showsFullDiff ? "Hide changes" : "Show changes")
                    .font(EnhancifyType.captionMedium)
                    .foregroundStyle(EnhancifyColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func errorView(message: String) -> some View {
        let actionID = appState.selectedActionID
        let fallbacks = SettingsStore.shared.fallbackProviders
        let showConnectCTA = appState.errorNeedsModelSetup.contains(actionID)
        return VStack(spacing: EnhancifySpace.sm) {
            Text(message)
                .enhancifyPrintedText()
                .foregroundStyle(EnhancifyColor.textSecondary)
                .multilineTextAlignment(.center)
            // Retry rows wrap: with fallbacks plus Connect to model the row
            // can outgrow the panel, and clipped actions are dead ends.
            WrapHStack(spacing: EnhancifySpace.xs, lineSpacing: EnhancifySpace.xs) {
                EnhancifyButton(title: "Retry", size: .compact) {
                    engine.retry(actionID: actionID)
                }

                // Connect to model: 404 / unknown model — open Models so the
                // user can install or pick one instead of retrying blindly.
                if showConnectCTA {
                    EnhancifyGlassButton(
                        title: "Connect to model",
                        prominent: true,
                        size: .compact
                    ) {
                        engine.requestProviderSetup(preferLocal: true)
                    }
                }

                // If another provider is configured, offer it here so a failed
                // request doesn't dead-end the user into opening Settings.
                ForEach(fallbacks, id: \.self) { kind in
                    EnhancifyButton(title: fallbackLabel(for: kind), size: .compact) {
                        engine.retryWithProvider(kind, actionID: actionID)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EnhancifySpace.sm)
        // The retry row can wrap onto a second line once a fallback provider
        // and Connect to model are both present, so the window has to be told.
    }

    /// Short label for the "Try with [X]" button. Takes the first word of the
    /// provider's title, so "API (Groq, OpenAI, …)" reads as "Try with API".
    func fallbackLabel(for kind: ProviderKind) -> String {
        let title = kind.title
        let firstWord = title.split(separator: " ").first.map(String.init) ?? title
        return "Try with \(firstWord)"
    }
}
