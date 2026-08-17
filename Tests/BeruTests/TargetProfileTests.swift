import XCTest
@testable import Beru

final class TargetProfileTests: XCTestCase {
    func testBuiltInsAreDistinctAndGenericIsFirst() {
        let defaults = TargetProfile.builtInDefaults
        XCTAssertEqual(defaults.count, 5)
        XCTAssertEqual(defaults.first?.id, TargetProfile.genericID)
        XCTAssertEqual(Set(defaults.map(\.id)).count, defaults.count)

        // Generic must contribute nothing; the rest must be non-empty and
        // genuinely different from one another.
        XCTAssertTrue(defaults[0].promptFragment.isEmpty)
        let fragments = defaults.dropFirst().map(\.promptFragment)
        XCTAssertTrue(fragments.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(Set(fragments).count, fragments.count)
    }

    func testGenericCompositionIsAByteIdenticalNoOp() {
        let generic = TargetProfile.builtInDefaults[0]
        XCTAssertEqual(Prompts.composeWithTarget(Prompts.enhance, profile: generic), Prompts.enhance)
        XCTAssertEqual(Prompts.composeWithTarget(Prompts.enhance, profile: nil), Prompts.enhance)
    }

    func testCursorCompositionKeepsBasePromptAndAddsFragment() {
        guard let cursor = TargetProfile.builtInDefaults.first(where: { $0.id == "target-cursor" }) else {
            return XCTFail("Missing Cursor default")
        }
        let composed = Prompts.composeWithTarget(Prompts.enhance, profile: cursor)
        XCTAssertTrue(composed.hasPrefix(Prompts.enhance))
        XCTAssertTrue(composed.contains("TARGET ENVIRONMENT: Cursor"))
        XCTAssertTrue(composed.contains("agentic coding IDE"))
    }

    func testTargetAppliesOnlyToEnhance() {
        XCTAssertTrue(Prompts.targetApplies(
            actionID: EnhancementAction.enhanceID, role: .enhance, usesBuiltInPrompt: true
        ))
        XCTAssertFalse(Prompts.targetApplies(
            actionID: EnhancementAction.grammarID, role: .grammar, usesBuiltInPrompt: true
        ))
        XCTAssertFalse(Prompts.targetApplies(
            actionID: EnhancementAction.describeID, role: .enhance, usesBuiltInPrompt: true
        ))
        XCTAssertFalse(Prompts.targetApplies(
            actionID: "tone-friendly", role: .enhance, usesBuiltInPrompt: false
        ))
    }

    /// A target fragment extends the built-in Enhance prompt and assumes its job.
    /// Bolted onto a prompt that says the opposite — the retired custom skill
    /// prompt ended "never expand the text" while the Cursor fragment demanded a
    /// coding work order with file paths and a verification command — it produces
    /// one system prompt with two contradictory jobs, and a small local model
    /// splits the difference into something that is neither.
    func testTargetIsSuppressedWhenThePromptIsNotTheBuiltInOne() {
        XCTAssertFalse(Prompts.targetApplies(
            actionID: EnhancementAction.enhanceID, role: .enhance, usesBuiltInPrompt: false
        ))
    }

    func testBundleSeedingRecognizesKnownAndForkedApps() {
        XCTAssertEqual(TargetProfile.seededID(forBundleID: "com.microsoft.VSCode"), "target-cursor")
        XCTAssertEqual(TargetProfile.seededID(forBundleID: "com.openai.chat"), "target-chatgpt")
        // Unknown bundle ids fall back to a substring match.
        XCTAssertEqual(TargetProfile.seededID(forBundleID: "com.example.Cursor-nightly"), "target-cursor")
        XCTAssertEqual(TargetProfile.seededID(forBundleID: "cn.moonshot.kimi"), "target-kimi")
        XCTAssertNil(TargetProfile.seededID(forBundleID: "com.apple.TextEdit"))
        // Cursor's focused field is an Electron helper whose bundle id has no "cursor".
        XCTAssertEqual(
            TargetProfile.seededID(
                forBundleID: "com.github.Electron.helper",
                name: "Cursor Helper (Renderer)"
            ),
            "target-cursor"
        )
        XCTAssertEqual(
            TargetProfile.seededID(
                forBundleID: "com.github.Electron.helper",
                name: "Claude Helper (Renderer)"
            ),
            "target-claude"
        )
    }

    func testResolvePrecedence() {
        let known: Set<String> = Set(TargetProfile.builtInDefaults.map(\.id))
        // Per-app memory beats the seed map.
        XCTAssertEqual(
            TargetRegistry.resolveTargetID(
                bundleID: "com.microsoft.VSCode",
                perApp: ["com.microsoft.VSCode": "target-claude"],
                lastUsed: "target-kimi",
                known: known
            ),
            "target-claude"
        )
        // Seed map beats last-used.
        XCTAssertEqual(
            TargetRegistry.resolveTargetID(
                bundleID: "com.microsoft.VSCode",
                perApp: [:],
                lastUsed: "target-kimi",
                known: known
            ),
            "target-cursor"
        )
        // Remembered Generic is not an explicit choice — Cursor still wins.
        XCTAssertEqual(
            TargetRegistry.resolveTargetID(
                bundleID: "com.todesktop.230313mzl4w4u92",
                appName: "Cursor",
                perApp: ["com.todesktop.230313mzl4w4u92": TargetProfile.genericID],
                lastUsed: TargetProfile.genericID,
                known: known
            ),
            "target-cursor"
        )
        // No bundle id at all falls back to last-used.
        XCTAssertEqual(
            TargetRegistry.resolveTargetID(bundleID: nil, perApp: [:], lastUsed: "target-kimi", known: known),
            "target-kimi"
        )
        // A target the user deleted must not be resurrected.
        XCTAssertEqual(
            TargetRegistry.resolveTargetID(
                bundleID: nil,
                perApp: [:],
                lastUsed: "target-deleted",
                known: known
            ),
            TargetProfile.genericID
        )
    }
}

/// Guards the structural rule that keeps target fragments from inventing facts.
///
/// The Cursor fragment used to demand specifics flatly — "state the stack facts:
/// language and version, framework, package manager, and the build or test
/// command", "require verification: name the command that must pass" — on inputs
/// that supply none of them. A small model reads a flat demand as a requirement
/// and meets it by making something up: measured on qwen3:8b at the app's own
/// temperature of 0.3, an input naming no path and no tooling produced "the
/// `docs/` directory" and "run `npm run build`" in 4 of 8 runs, for a project
/// with neither.
///
/// These tests pin the two halves of the fix. Neither can prove the model behaves
/// — only a run against a real model does that, and the numbers above come from
/// one — but they fail loudly if the wording that was measured gets edited back
/// into a flat demand, or if the backstop stops being attached.
final class TargetInventionRuleTests: XCTestCase {
    private var builtIns: [TargetProfile] { TargetProfile.builtInDefaults }

    /// The backstop reaches every target that asks for anything, custom ones
    /// included — they are the reason it lives in `composeWithTarget` instead of
    /// being written into each fragment.
    func testInventionRuleIsAppendedToEveryNonEmptyFragment() {
        for profile in builtIns where !profile.promptFragment.isEmpty {
            let composed = Prompts.composeWithTarget(Prompts.enhance, profile: profile)
            XCTAssertTrue(
                composed.contains(Prompts.targetInventionRule),
                "\(profile.name) composed without the anti-invention rule"
            )
        }

        let custom = TargetProfile(
            id: "target-custom-test",
            name: "Homegrown",
            icon: "star",
            promptFragment: "- Always name the exact file to edit and the command to run.",
            isBuiltIn: false
        )
        XCTAssertTrue(
            Prompts.composeWithTarget(Prompts.enhance, profile: custom)
                .contains(Prompts.targetInventionRule),
            "A custom target demanding specifics is exactly what the rule is for"
        )
    }

    /// Generic contributes no conventions, so there is nothing to fabricate in
    /// service of, and the no-op composition must stay byte-identical.
    func testGenericGetsNoInventionRule() {
        let generic = builtIns[0]
        let composed = Prompts.composeWithTarget(Prompts.enhance, profile: generic)
        XCTAssertFalse(composed.contains(Prompts.targetInventionRule))
        XCTAssertEqual(composed, Prompts.enhance)
    }

    /// Position is load-bearing: the rule qualifies the bullets above it, and the
    /// tail of the prompt is where an 8B model holds an instruction best. If it
    /// migrates above the fragment it reads as a preamble the bullets then
    /// override.
    func testInventionRuleFollowsTheFragmentItQualifies() {
        guard let cursor = builtIns.first(where: { $0.id == "target-cursor" }) else {
            return XCTFail("Missing Cursor default")
        }
        let composed = Prompts.composeWithTarget(Prompts.enhance, profile: cursor)
        guard let fragmentAt = composed.range(of: cursor.promptFragment),
              let ruleAt = composed.range(of: Prompts.targetInventionRule) else {
            return XCTFail("Expected both the fragment and the rule in the composition")
        }
        XCTAssertTrue(ruleAt.lowerBound > fragmentAt.upperBound)
    }

    /// The rule has to forbid the categories that were actually fabricated. A
    /// prohibition that omits "package manager" leaves the npm invention legal.
    func testInventionRuleNamesTheCategoriesThatWereFabricated() {
        let rule = Prompts.targetInventionRule.lowercased()
        for category in ["path", "command", "language", "framework", "version", "data"] {
            XCTAssertTrue(rule.contains(category), "Rule does not cover \(category)")
        }
        // It must also say what to do instead, or the model has only a
        // prohibition and no legal way to satisfy the bullet above it.
        XCTAssertTrue(rule.contains("instruct the reader to establish"))
    }

    /// A prompt must ask for the answer, never contain it.
    ///
    /// The Claude fragment used to demand "one or two concrete input/output
    /// examples whenever the desired format is not obvious" and to list
    /// `<examples>` among its XML tags. On "suggest some name and logo ideas"
    /// that produced an <examples> block holding three invented product names —
    /// the deliverable, guessed by an 8B model and frozen into the prompt.
    /// Replaying the recorded system prompt reproduces it 12 of 12; the current
    /// wording is clean 12 of 12.
    ///
    /// Naming the tag was most of the invitation, so the test guards the absence
    /// of the mention, not just the presence of a warning.
    func testNoTargetAsksForAnExampleOfTheAnswer() {
        for profile in builtIns where !profile.promptFragment.isEmpty {
            let fragment = profile.promptFragment

            for regression in [
                "Include one or two concrete input/output examples",
                "Prefer one worked example",
                "<examples>"
            ] {
                XCTAssertFalse(
                    fragment.contains(regression),
                    "\(profile.name) invites the model to write the answer: \(regression)"
                )
            }

            // Any fragment that still discusses examples or specimens must say
            // not to invent them, rather than merely asking for them.
            let lower = fragment.lowercased()
            if lower.contains("example") || lower.contains("specimen") {
                XCTAssertTrue(
                    lower.contains("do not write a specimen")
                        || lower.contains("the input") ,
                    "\(profile.name) mentions examples without tying them to what the input supplies"
                )
            }
        }
    }

    /// Both rewriting targets carry the positive form of that rule, so the model
    /// has something to do instead of demonstrating.
    func testRewritingTargetsAskForTheShapeOfTheAnswer() {
        for id in ["target-claude", "target-chatgpt"] {
            guard let profile = builtIns.first(where: { $0.id == id }) else {
                return XCTFail("Missing \(id)")
            }
            XCTAssertTrue(
                profile.promptFragment.contains("Describe the shape of the answer"),
                "\(profile.name) should ask for the shape of the answer"
            )
            XCTAssertTrue(
                profile.promptFragment.contains("a specimen is the answer"),
                "\(profile.name) should say why a specimen is not allowed"
            )
        }
    }

    /// The measured half of the fix. These exact sentences are what produced the
    /// invented `docs/` and `npm run build`; a flat demand for a specific must
    /// not come back.
    func testCursorFragmentDemandsNoSpecificTheInputMayNotSupply() {
        guard let cursor = builtIns.first(where: { $0.id == "target-cursor" }) else {
            return XCTFail("Missing Cursor default")
        }
        let fragment = cursor.promptFragment
        for regression in [
            "State the stack facts that constrain the edit:",
            "Require verification: name the command that must pass"
        ] {
            XCTAssertFalse(
                fragment.contains(regression),
                "Unconditional demand restored, which fabricated a path and a build command in 4/8 runs: \(regression)"
            )
        }

        // Each surviving bullet that asks for a fact about the user's project has
        // to carry its own escape hatch, since the backstop alone measured only
        // 7/8. Matched on the categories that were actually fabricated, not on
        // "file" — "apply edits directly to files" names no project fact and
        // needs no guard.
        let factCategories = ["path", "glob", "directory", "stack", "language",
                              "framework", "package manager", "command"]
        let bullets = fragment.split(separator: "\n").map(String.init)
        let asksForSpecifics = bullets.filter { bullet in
            factCategories.contains { bullet.lowercased().contains($0) }
        }
        XCTAssertFalse(asksForSpecifics.isEmpty, "Cursor should still ask for specifics when they exist")
        for bullet in asksForSpecifics {
            let lower = bullet.lowercased()
            let isConditional = ["if the input", "the input states", "as the input",
                                 "input supports", "when the input", "otherwise",
                                 "does not", "never mentions", "do not"]
                .contains { lower.contains($0) }
            XCTAssertTrue(
                isConditional,
                "Bullet asks for a specific with no conditional guard: \(bullet)"
            )
        }
    }
}

/// A fragment fix that never reaches the user is not a fix.
///
/// Target profiles are seeded into UserDefaults on first launch, and the registry
/// only ever re-appended ids the stored copy predated. So a fragment was frozen
/// at whatever shipped when the app first ran: correcting the Cursor wording
/// would have been a no-op on the very machine that reported the invented paths.
final class TargetRegistryRefreshTests: XCTestCase {
    private func shipped(_ id: String) -> TargetProfile {
        TargetProfile.builtInDefaults.first { $0.id == id }!
    }

    func testUneditedBuiltInAdoptsShippedWording() {
        var stale = shipped("target-cursor")
        stale.promptFragment = "- State the stack facts: package manager and the build command."

        let refreshed = TargetRegistry.refreshingUneditedBuiltIns([stale], userEdited: [])
        XCTAssertEqual(refreshed.first?.promptFragment, shipped("target-cursor").promptFragment)
    }

    func testEditedBuiltInKeepsTheUsersWording() {
        var mine = shipped("target-cursor")
        mine.promptFragment = "- Just give me the diff."

        let refreshed = TargetRegistry.refreshingUneditedBuiltIns(
            [mine],
            userEdited: ["target-cursor"]
        )
        XCTAssertEqual(refreshed.first?.promptFragment, "- Just give me the diff.")
    }

    func testCustomProfilesAreNeverRewritten() {
        let custom = TargetProfile(
            id: "target-custom-abc",
            name: "Mine",
            icon: "star",
            promptFragment: "- Whatever I want.",
            isBuiltIn: false
        )
        let refreshed = TargetRegistry.refreshingUneditedBuiltIns([custom], userEdited: [])
        XCTAssertEqual(refreshed, [custom])
    }

    /// Refreshing must not reorder or drop anything — the order is what the
    /// picker shows.
    func testRefreshPreservesOrderAndMembership() {
        var stale = TargetProfile.builtInDefaults
        stale[1].promptFragment = "drifted"
        let custom = TargetProfile(
            id: "target-custom-xyz", name: "Mine", icon: "star",
            promptFragment: "- Mine.", isBuiltIn: false
        )
        stale.append(custom)

        let refreshed = TargetRegistry.refreshingUneditedBuiltIns(stale, userEdited: [])
        XCTAssertEqual(refreshed.map(\.id), stale.map(\.id))
        XCTAssertEqual(refreshed.dropLast(), TargetProfile.builtInDefaults[...])
        XCTAssertEqual(refreshed.last, custom)
    }
}
