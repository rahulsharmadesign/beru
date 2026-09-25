import Foundation
import os

// Building a request: which prompt, which input, which layers.

extension PanelEngine {
    func start(
        actionID: String,
        previousResult: String? = nil,
        instruction: String? = nil,
        retryHint: String? = nil,
        isQualityRetry: Bool = false
    ) {
        guard let action = EnhancementAction.action(withID: actionID) else { return }
        if !isQualityRetry {
            qualityRetries[actionID] = 0
        }
        let grammarStyle = actionID == EnhancementAction.grammarID ? appState.grammarStyle : .proofread
        // A Grammar rewrite style changes wording on purpose, so it takes the
        // enhance role's sampling: Regenerate should give a new take.
        let role: ModelRole = grammarStyle.isRewrite ? .enhance : action.role

        let resolved = EnhancementAction.resolveInput(
            capturedText: appState.capturedText,
            composerText: instruction ?? appState.describeInstruction
        )
        // Both jobs need material. Typed composer text counts as that material
        // when nothing was selected.
        guard !resolved.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appState.setResult(.idle, for: actionID)
            return
        }
        var capturedText = resolved.sourceText
        if resolved.usedComposerAsSource {
            if capturedText.count > Self.maxCapturedLength {
                capturedText = String(capturedText.prefix(Self.maxCapturedLength))
                appState.truncationNotice = true
            }
            appState.capturedText = capturedText
            appState.describeInstruction = ""
        }

        let generation = beginGeneration(for: actionID)
        appState.setResult(.loading, for: actionID)
        appState.diffs[actionID] = nil
        appState.errorNeedsModelSetup.remove(actionID)

        let provider = ProviderRegistry.activeProvider()
        // Apple's on-device base model cannot carry the composed prompt stack:
        // Grammar's three-tag skeleton and Enhance's target/framing layers are
        // where it echoes the input or invents work. On that provider the
        // short single-job prompts run and nothing is composed onto them.
        let onDevice = SettingsStore.shared.activeProvider == .apple
        let systemPrompt: String
        if grammarStyle.isRewrite {
            systemPrompt = grammarStyle.systemPrompt
        } else if onDevice {
            systemPrompt = actionID == EnhancementAction.grammarID ? Prompts.grammarOnDevice : Prompts.enhanceOnDevice
        } else {
            systemPrompt = action.systemPrompt
        }

        var userMessage = Prompts.userMessage(capturedText: capturedText)
        if let previousResult {
            // Proofread re-checks; everything else offers an alternative.
            userMessage += actionID == EnhancementAction.grammarID && !grammarStyle.isRewrite
                ? Prompts.recheckSuffix(previous: previousResult)
                : Prompts.regenerateSuffix(previous: previousResult)
        }
        if !resolved.extraInstruction.isEmpty {
            userMessage += Prompts.additionalInstruction(resolved.extraInstruction)
        }
        if let retryHint, !retryHint.isEmpty {
            userMessage += "\n\n\(retryHint)"
        }

        let finalSystemPrompt: String
        if onDevice {
            // The on-device prompts describe their own markers and carry no
            // slots for target conventions: one short instruction is all the
            // base model can hold.
            finalSystemPrompt = systemPrompt
        } else {
            let target = Prompts.targetApplies(actionID: actionID)
                ? TargetRegistry.shared.profile(withID: appState.selectedTargetID)
                : nil
            finalSystemPrompt = Prompts.composeWithFraming(
                Prompts.composeWithTarget(systemPrompt, profile: target),
                framing: Prompts.framing(actionID: actionID, usesBuiltInPrompt: !grammarStyle.isRewrite)
            )
        }

        attempts[actionID] = attempts[actionID].map { $0 + 1 } ?? 0
        runStream(
            PanelRequest(
                actionID: actionID,
                role: role,
                provider: provider,
                systemPrompt: finalSystemPrompt,
                userMessage: userMessage,
                capturedText: capturedText,
                instruction: resolved.extraInstruction,
                generation: generation,
                grammarStyle: grammarStyle
            )
        )
    }

    /// Retries the current action with a specific provider, switching the active
    /// provider for this run. Used by the panel's "Try with [X]" error action so
    /// a failed provider doesn't dead-end the user into Settings.
    func retryWithProvider(_ kind: ProviderKind, actionID: String) {
        SettingsStore.shared.selectProvider(kind)
        start(actionID: actionID)
    }
}
