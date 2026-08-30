# Beru "Liquid Glass" — Full Re-Audit & Remediation Plan

**Target of audit:** `main` @ `1d02e69` — *the former `liquid-glass`, fast-forwarded to `main` on
2026-08-30. `origin/main` and `origin/liquid-glass` are now identical (0/0 divergence).*
**Superseded baseline:** old `main` @ `4647f28`
**Plan authored:** 2026-08-30
**Scope of authority:** full — audit *and* remediation, including breaking changes where justified.

## Ratified product decisions

These are settled and bind the whole plan. Where the plan previously left them open, they are now
closed:

| # | Decision | Consequence |
|---|---|---|
| **D1** | **Liquid Glass is `main`.** Fast-forwarded, no history rewrite, nothing lost. | The audit target *is* the release line. Risk **R10** (branch divergence) is closed. |
| **D2** | **macOS 26 now, macOS 27 on release.** Hard floor, no back-compat to 14/15. | Risk **R2** is closed as *intentional*. Replaces "decide the floor" with "declare and document the floor", plus forward-compat readiness for 27. |
| **D3** | **macOS only. Windows `.exe` is out of scope** — later, not now. | No cross-platform abstraction work. Do **not** pre-emptively portability-proof; it would directly fight D4. Recorded as a non-goal in §6.7. |
| **D4** | **100% Liquid Glass UI using 100% native components.** | New **Workstream 1.6** and remediation **Wave N**. This is now the single largest body of work in the plan and reframes §1.4. |

**On D2 and macOS 27:** targeting 26 while intending 27 means the codebase must be *forward*-tolerant,
not *backward*-tolerant. Concretely — no reliance on undocumented material behaviour, no hard-coded
assumptions about glass rendering internals, and a documented annual OS-bump procedure. The current
tree has **zero `if #available` guards**, which is correct for a hard floor but means a 27 bump has no
staging mechanism. W N.7 addresses this.

---

## 0. Why this plan exists

A prior audit was run against `main` and produced 41 impact-ranked findings. That audit was
**mis-scoped**: it never enumerated branches. `liquid-glass` is the real head of this project and
carries two commits that `main` does not:

| Commit | Subject |
|---|---|
| `0a24083` | Ship liquid glass panel with stable height and Search thread. |
| `1d02e69` | Rebuild workspace pages as native Settings source lists. |

Delta: **80 files, +3,391 / −1,562**. The branch also performs an **OS-target migration**
(`macOS 14.0 → 26.0`), which invalidates the framing of the earlier UI analysis rather than merely
adding to it. This plan therefore treats `liquid-glass` as the authoritative tree and re-audits from
first principles, carrying forward only findings re-verified against the branch.

### Measured size of the audit target

| Metric | Value |
|---|---|
| Swift files in `Sources/` | 121 |
| LOC in `Sources/` | 17,542 |
| Test files | 38 |
| Test LOC | 4,694 |
| Test:source LOC ratio | 0.27 |
| Files added vs `main` | 7 |
| Files deleted vs `main` | 1 (`Sources/Panel/GlassModule.swift`) |

### What the branch already fixed (do not re-report)

Verified by direct inspection, not assumption:

- **Panel height contract** — `qa-baseline.txt` ratchets `panel_infinite_height` from `4 → 0`. The
  contract is now documented as *frozen* in `.cursor/rules/beru-design-tokens.mdc` with an explicit
  do-not list, and `maxViewportFraction` moved `0.8 → 0.75`.
- **Glass reinstated as a token** — `Sources/Panel/GlassModule.swift` (deleted) →
  `Sources/Design/GlassModule.swift` (+84) plus new `Sources/Design/GlassSlab.swift`. The earlier
  audit read `glassChip` naming as vestigial dead code; that was **wrong** — it was a landing pad.
- **Documentation kept in lockstep** — `README.md` badge and install section updated to macOS 26+,
  CI runners `macos-15 → macos-26`, design-token rule rewritten, `docs/QA-CHECKLIST.md` +59 lines.
- **New regression tests** — `PanelViewportCapTests`, `SearchThreadTests`, `TextReplaceTests`, plus
  additions to `AppStateTests`, `VaultTests`, `DictationTests`, `RunsFilterTests`.
- **Reduce Transparency is handled by design** — both new glass files branch on
  `accessibilityReduceTransparency` and paint an opaque surface. This is a genuine accessibility
  strength and should be protected by tests, not "fixed".

This branch is materially more disciplined than `main`. The plan below is calibrated accordingly:
it is a hardening pass, not a rescue.

---

## 1. Audit scope

Five workstreams. Each has explicit in-scope artifacts and explicit exclusions, so "done" is
decidable.

### 1.1 Code review

**In scope:** all 121 files in `Sources/`, all 38 in `Tests/`, `project.yml`, `scripts/*.sh`,
`.github/workflows/*.yml`, `.cursor/rules/*.mdc`.

Specific lines of inquiry:

- **macOS 26 migration correctness.** Exactly one `.glassEffect(` call site exists
  (`Sources/Panel/GlassStyles.swift:35`) and there are **zero `if #available` guards anywhere in
  `Sources/`**. With `deploymentTarget: 26.0` that compiles, but it means the codebase has no
  deliberate stance on availability. Audit whether that is intentional (hard floor) or accidental.
- **Contract-vs-enforcement gap.** `scripts/qa.sh` is **byte-identical to `main`** while the panel
  contract it is supposed to protect was rewritten. The new "Do not" list (no
  `intrinsicContentSize`, no chrome inside the result `ScrollView`, no animated resize on tab change,
  no re-imposed comfort `minHeight`) is enforced only by prose and reviewer memory.
- **Carried-forward findings.** Re-verify each of the 41 prior findings against branch content.
  Already re-verified as *still present*: bare-`Return` fall-through
  (`Sources/Panel/PanelView.swift:73–84`), discarded push-to-talk callbacks
  (`Sources/Speech/PushToTalkMonitor.swift:15–17`), `PowerActivity.streamBegan()` never called,
  no Dynamic Type in `BeruType.swift`, updater `rm -rf` in `AppUpdateService.swift`, O(n·m)
  `WordDiff`, Context Library with no editor, weak `isConfigured`, AccentColor divergence.
- **Concurrency.** `SWIFT_STRICT_CONCURRENCY: complete` is set; audit `@MainActor` boundaries and
  the `UsageLogWriter` actor for correctness under it.
- **File-size discipline.** The 400-line rule holds — largest file is
  `Sources/App/AppCoordinator.swift` at 395 lines. Four files sit in the 380–395 band and are
  effectively at ceiling; flag as maintainability pressure, not a violation.

**Out of scope:** the `LandmarksBuildingAnAppWithLiquidGlass/` sample (newly gitignored as a nested
repo — it is a local cookbook, not product code). Also out of scope per **D3**: any Windows/cross-platform
abstraction.

### 1.6 Native-component & 100% Liquid Glass conformance (NEW — per D4)

This is the highest-effort workstream and the one most likely to change the shipped product. It exists
because the codebase's current state is **materially at odds with the stated goal**, and the gap is
measurable.

#### Measured baseline — where "100% native / 100% glass" actually stands today

| Signal | Measured on `main` @ `1d02e69` | Reading |
|---|---|---|
| `.glassEffect(` call sites in `Sources/` | **1** (`Sources/Panel/GlassStyles.swift:35`) | One chip capsule is real Liquid Glass. Nothing else is. |
| `GlassEffectContainer` uses | **0** | No glass grouping/merging — Apple's container is how sibling glass elements blend and morph. Its absence means glass cannot behave natively at scale. |
| `glassEffectID` / `glassEffectUnion` | **0** | No morph identity, so no native transitions between glass states. |
| `NavigationSplitView` | **0** | The dashboard's sidebar is hand-built. |
| `Form {` | **0** | Settings pages are hand-assembled, not native forms. |
| `LabeledContent` / `GroupBox` / `Table(` | **0** / **0** / **0** | Native settings idioms unused. |
| `List(` | 7 | Partially adopted — `WorkspaceChrome.swift` is the good pattern. |
| Custom control structs in `SettingsControls.swift` | **13** | `SettingsPillButton`, `PrimaryButton`, `TogglePill`, `IconButton`, `InlineButton`, `Value`, `StatusBadge`, `Field`, `SecretField`, `Switch`, `SearchField`, `MenuPill`, `OverflowMenu` — most reimplement a native control. |
| `Toggle(` vs custom `SettingsSwitch` | 3 vs 1 custom wrapper | Mixed idiom. |
| Third-party icon dependency | `Lucide` (14 files reference `BeruIcon`/Lucide) | **Directly contradicts "100% native."** SF Symbols is the native icon system and is what Liquid Glass materials are designed against. |
| Stray `Image(systemName:)` | 2 (`DashboardView.swift:147`, `PanelChrome.swift:43`) | Ironically the only *native* icon usage, previously logged as a defect to remove. **D4 inverts this finding.** |

**The honest conclusion:** the branch is named "liquid glass" and has *architected for* it correctly —
`Sources/Design/GlassModule.swift` and `GlassSlab.swift` encode Apple's real rules (no glass-on-glass,
Reduce Transparency fallbacks) with unusual discipline. But adoption is roughly **one call site**. The
naming and the token layer are ready; the surface area is not. Reaching "100%" is a substantial
migration, not a polish pass.

**Two findings from the earlier audit are now inverted by D4** and must be withdrawn rather than fixed:
- Removing the 2 remaining `Image(systemName:)` (was W3.1) — now the *target* state, not the defect.
- Treating Lucide as the sanctioned icon system — now the defect.

#### Audit questions for this workstream

- Which of the 13 custom controls have a native equivalent that supports Liquid Glass automatically
  (`.buttonStyle(.glass)`, `.glassEffect`, native `Toggle`/`Picker`/`TextField`/`Menu`)? Replace those.
- Which are genuinely irreplaceable (e.g. `SettingsSecretField` behaviour, the `DictationPressView`
  AppKit hit-target for press-and-hold)? Keep, document, and justify each survivor.
- Can the dashboard's hand-built sidebar become `NavigationSplitView`, inheriting native glass sidebar
  material, system highlight, and full keyboard/VoiceOver behaviour for free?
- Can settings pages become native `Form`/`Section`/`LabeledContent`, which on macOS 26 pick up glass
  styling automatically?
- Does the fixed-420pt borderless `NSPanel` remain the right vessel, or does it fight native glass?
  **This is the highest-risk question in the plan** — the panel is the product's core surface and its
  height contract was just frozen.
- Is `GlassEffectContainer` required for correct blending once multiple glass elements coexist?
  (Apple's guidance: yes.)
- Does Lucide get removed entirely, or retained only where SF Symbols has no equivalent? Removal
  deletes an SPM dependency and ~50 entries of `IconNames.legacy` mapping.

**Note on the QA ratchet:** `system_fonts`, `raw_colors`, and `raw_radius` guards all exclude
`Sources/Design` and forbid raw values elsewhere. Adopting native components *helps* these counters.
But `offgrid_spacing` may fight native adoption, since system components carry Apple's own metrics
rather than Beru's 4/8pt grid. Expect to relax that guard's scope for native-component files — a
legitimate, documented baseline change, not a loosening.

### 1.2 Performance testing

**In scope:** panel invoke-to-visible latency, streaming-token render cost, window resize behaviour
at the 75% viewport cap, diff computation, log/vault I/O.

Known algorithmic risks to measure rather than assume:

- `WordDiff.lcsDiff` allocates an `(n+1)×(m+1)` `Int32` buffer. For two 5,000-word documents that is
  ~100 MB. Two call sites: the panel diff and `Sources/Dashboard/RunDetailView.swift`.
- `VaultStore.updateNote` re-sorts the note collection on **every keystroke**.
- The 1-second Accessibility permission polling loop in `PanelView`.
- `PowerActivity.streamBegan()` is never called, so App Nap is never suppressed during streams —
  a *latency* bug, not merely dead code.

### 1.3 Security assessment

**In scope:** `Sources/Support/AppUpdateService.swift`, `Sources/Settings/KeychainStore.swift`,
`SettingsStore.KeyCache`, `Sources/Capture/*`, `Resources/Info.plist`,
`Resources/PrivacyInfo.xcprivacy`, entitlements in `project.yml`, `SECURITY.md`, `scripts/install.sh`
(changed on this branch, +25/−?), `scripts/notarize.sh`, `scripts/make-signing-cert.sh`.

Priority items:

- **Auto-updater is the highest-severity security surface.** It fetches from the GitHub Releases
  feed, writes a bash script to a **fixed** temp path (`beru-apply-update.sh`), and that script
  `rm -rf`s the app bundle before `cp -R`. Fixed path + destructive verb = local privilege-escalation
  and TOCTOU exposure. `SECURITY.md` does **not** cover the updater at all.
- **Not sandboxed, by design.** `docs/PRD.md:407` states a compromised build can read and inject
  text in any app. Audit that the documented threat model matches actual capability.
- **Secure field capture.** `Sources/Capture/TextCapture.swift` includes `AXSecureTextField` in
  `editableRoles` — i.e. password fields are in scope for capture. Verify intent and document.
- **Key handling.** Keychain uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (good). Audit
  `KeyCache` for in-memory key lifetime and the `keychain_reach=0` guard's real coverage.
- **On-device speech claim.** `requiresOnDeviceRecognition = true` — verify no fallback path defeats
  it, since the privacy manifest asserts no data collection.

### 1.4 UI/UX evaluation

**In scope:** all of `Sources/Design/`, `Sources/Panel/`, `Sources/Dashboard/` (+ `Pages/`),
`Sources/Vault/`, `Sources/App/OnboardingWindow.swift`, `Resources/Assets.xcassets/`.

Priority items:

- **Re-evaluate every UI finding against macOS 26.** Recommendations premised on macOS 14
  capabilities may now be satisfied natively by Liquid Glass materials. This is the single biggest
  correction versus the prior audit.
- **Glass-on-glass rule.** Both new files assert "Apple forbids stacking glass on glass." Audit for
  violations and make the rule machine-checkable.
- **Dynamic Type.** `BeruType.swift` is entirely fixed-point `.system(size:)`; zero
  `dynamicTypeSize`/`ScaledMetric`/`relativeTo` in the tree. Single-file fix vector.
- **Keyboard navigability.** One production `.focused(` in the panel; toolbar chips are not
  `.focusable()`.
- **Localization.** Zero `NSLocalizedString`/`LocalizedStringKey`, no `.lproj`. Scope the cost;
  do not necessarily fix.
- **SF Symbol leakage got slightly worse.** `ActionsView.swift` was rewritten and lost its
  `Image(systemName:)`, but two new ones appeared — `Sources/Dashboard/DashboardView.swift` and
  `Sources/Panel/PanelChrome.swift`. Net 1 → 2 in an all-Lucide UI.
- **Onboarding.** `GetStartedStep` = `welcome | accessibility | microphone | startBeru` — still no
  provider-configuration step, so a user can complete onboarding and reach a non-functional app.
  `OnboardingWindow.swift` changed (−20) on this branch; re-verify.

### 1.5 Documentation verification

**In scope:** `README.md`, `docs/PRD.md`, `docs/QA-CHECKLIST.md`, `SECURITY.md`, `AGENTS.md`,
`CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `.cursor/rules/*.mdc`, issue/PR templates.

Priority items:

- **Version drift persists.** `docs/PRD.md:5` says *"Version this document describes: 1.1.9
  (build 15)"* and line 533 repeats *"Beru 1.1.9 as implemented in this repository"*, while
  `project.yml` says `MARKETING_VERSION 1.1.10` / `CURRENT_PROJECT_VERSION 16`. The PRD is the
  declared behavioural contract, so this is a contract-integrity defect, not a typo.
- **PRD has not absorbed the glass rebuild.** +39 lines only, against an 80-file redesign.
- **`SECURITY.md` gap** — no updater coverage (see 1.3).
- **PRD §16 "Known product gaps"** — reconcile against reality; some may now be closed.

---

## 2. Phases & schedule

Sequential phases, 22 working days. Phase gates are hard: a phase does not open until the prior
phase's exit criteria are met.

| Phase | Name | Days | Calendar |
|---|---|---|---|
| **P0** | Preparation & environment | 2 | D1–D2 |
| **P1** | Data collection (static + dynamic) | 5 | D3–D7 |
| **P2** | Analysis & triage | 3 | D8–D10 |
| **P3** | Remediation (W1, W2, **WN**, W3) | 18 | D11–D28 |
| **P4** | Verification & regression | 4 | D29–D32 |
| **P5** | Sign-off & release readiness | 1 | D33 |

**Schedule revised from 22 → 33 days** to absorb D4. The native-component migration (Wave N, 8 days)
is the largest single block of work in the plan; P1 gains a day for the conformance inventory and P4
gains a day because native adoption touches every visual surface and demands a full re-verification
rather than a targeted one.

### P0 — Preparation & environment (D1–D2)

**Hard blocker to surface immediately:** this audit was prepared in a Linux sandbox.
`xcodebuild`, `xcodegen`, and the macOS 26 SDK are **unavailable here** — the entire prior audit was
static. Phases requiring a build (P1 dynamic, P3 verification, P4) **require a macOS 26 machine or
`macos-26` CI runner**. CI is already pointed at `macos-26` on this branch, which is the sanctioned
path.

| # | Task | Owner | Days |
|---|---|---|---|
| P0.1 | Provision macOS 26 build host; `brew install xcodegen`; confirm `xcodegen generate` + `xcodebuild` succeed on `liquid-glass` | Release Eng | 1 |
| P0.2 | Establish green baseline: `./scripts/qa.sh --static`, then `./scripts/qa.sh`, then full test suite. Record results verbatim | QA Lead | 0.5 |
| P0.3 | Confirm `macos-26` runner availability in GitHub Actions; if unavailable, escalate — the OS migration cannot be validated without it | Release Eng | 0.5 |
| P0.4 | Freeze audit ref (`1d02e69`); create `audit/liquid-glass` working branch | Tech Lead | 0.25 |
| P0.5 | Stand up findings register (ID, area, severity, file:line, status, owner, fix commit, test ref) | Audit Lead | 0.25 |
| P0.6 | Confirm the 41 prior findings' fix sites exist on this branch; mark each carried / resolved / stale | Audit Lead | 0.5 |

**Exit criteria:** clean build on macOS 26; baseline QA + test results recorded; register populated.

**If P0.1/P0.3 fail:** stop and renegotiate scope. A static-only audit is deliverable but cannot
validate the macOS 26 migration, which is this branch's central risk. Say so explicitly rather than
shipping false confidence.

### P1 — Data collection (D3–D6)

| # | Task | Owner | Days |
|---|---|---|---|
| P1.1 | Full read of all 121 `Sources/` files; log every deviation from `.cursor/rules/` | Senior iOS/macOS Eng ×2 | 2 |
| P1.2 | Availability sweep: enumerate every macOS-26-only API; decide hard-floor vs guarded | Senior Eng | 0.5 |
| P1.3 | Enforcement-gap sweep: for each "Do not" in the frozen panel contract, determine whether any static check exists | QA Lead | 0.5 |
| P1.4 | Manual `docs/QA-CHECKLIST.md` pass on macOS 26 — light+dark, Reduce Transparency, Reduce Motion, 12 accents | QA Eng | 1 |
| P1.5 | Perf capture: panel invoke→visible, streaming render, resize at cap, `WordDiff` at 1k/5k/20k words, vault typing latency | Perf Eng | 1 |
| P1.6 | Security review of updater, Keychain/KeyCache, capture paths, install/notarize scripts | Security Eng | 1.5 |
| P1.7 | Accessibility pass: VoiceOver traversal of panel + dashboard, keyboard-only operation, Dynamic Type behaviour | Accessibility Spec | 1 |
| P1.8 | Doc-vs-code diff: PRD/README/SECURITY/QA-CHECKLIST vs actual behaviour | Tech Writer | 1 |
| P1.9 | Multi-provider functional matrix (Ollama, Groq, OpenAI, LM Studio, Anthropic) × actions × targets | QA Eng | 1 |
| P1.10 | **Native-conformance inventory (D4).** Per-view table: current control → native equivalent → glass support → replace/keep/justify. Covers all 13 custom controls, sidebar, settings pages, panel chrome | Senior Eng + Design | 1.5 |
| P1.11 | **SF Symbols coverage test.** Map every Lucide icon in use to an SF Symbol; list gaps. Determines whether Lucide can be removed outright | Design | 0.5 |
| P1.12 | **Glass-container spike.** Prototype `GlassEffectContainer` + `glassEffectID` on the panel chip row; confirm native blending/morph works within the frozen height contract | Senior Eng | 1 |

**Exit criteria:** every workstream has written output in the register; no area unexamined; the
native-conformance inventory is complete and costed per view.

### P2 — Analysis & triage (D7–D9)

| # | Task | Owner | Days |
|---|---|---|---|
| P2.1 | Deduplicate/merge findings; discard any not reproducible on `liquid-glass` | Audit Lead | 0.5 |
| P2.2 | Severity assignment (rubric §2.1) with a named second reviewer per finding | Audit Lead + Tech Lead | 0.5 |
| P2.3 | Root-cause clustering — fix causes, not symptoms | Tech Lead | 0.5 |
| P2.4 | Assign each finding to remediation wave W1/W2/W3; define per-finding acceptance test | Tech Lead | 1 |
| P2.5 | Publish interim audit report; explicit go/no-go per wave | Audit Lead | 0.5 |

#### 2.1 Severity rubric

| Severity | Definition | Wave |
|---|---|---|
| **S1 Critical** | Data loss, security exposure, or user-visible destructive action | W1 |
| **S2 High** | Core journey broken/misleading; accessibility barrier; documented contract violated | W1 |
| **S3 Medium** | Degraded UX, perf cliff under plausible load, inconsistency a user would notice | W2 |
| **S4 Low** | Dead code, cosmetic drift, internal-only inconsistency | W3 |

Pre-seeded from re-verified findings:

- **S1:** updater fixed-path `rm -rf`; `SECURITY.md` updater gap.
- **S2:** bare-`Return` fall-through (destructive replace on a keystroke users press to mean
  "submit"); no Dynamic Type; panel not keyboard-navigable; onboarding permits a non-functional
  end state; PRD version drift.
- **S3:** `WordDiff` memory; `streamBegan()` never called; `VaultStore` re-sort per keystroke; 1s
  Accessibility poll; Context Library with no editor; `qa.sh` not enforcing the frozen contract.
- **S4:** two stray SF Symbols; AccentColor divergence; dead symbols; `DashboardMetrics.lg = 28`
  off-grid.

### P3 — Remediation (D10–D18)

Three waves. **One logical change per commit**, per `.cursor/rules/beru-qa-gate.mdc`
("one change per pass"). Every commit runs the §3 gate before merge.

#### Wave 1 — Critical & High (D10–D13)

| # | Task | Owner | Days |
|---|---|---|---|
| W1.1 | Harden updater: unpredictable temp path, verify download before destroy, move-aside instead of `rm -rf`, validate signature/checksum | Security Eng | 1.5 |
| W1.2 | Document updater threat model in `SECURITY.md` | Security Eng + Writer | 0.25 |
| W1.3 | Fix bare-`Return`: never destructively replace on unmodified Return; require ⌘↩ for replace | Senior Eng | 0.5 |
| W1.4 | Add `PanelKeyBindingTests` covering ↩ / ⌘↩ / ⌘C / ⌘1-9 | Senior Eng | 0.5 |
| W1.5 | Dynamic Type in `BeruType.swift` via `relativeTo:`; audit layouts at XXL | Senior Eng | 1.5 |
| W1.6 | Keyboard navigability: `.focusable()` on chips, focus ring via existing `GlassModule(focusRing:)`, logical tab order | Senior Eng | 1 |
| W1.7 | Add provider-configuration step to onboarding; block "Start Beru" until a provider validates | Senior Eng | 1 |
| W1.8 | Strengthen `SettingsStore.isConfigured` beyond non-empty-string | Senior Eng | 0.5 |
| W1.9 | Reconcile PRD to 1.1.10/build 16; absorb the glass rebuild into PRD + §16 | Tech Writer | 1 |

#### Wave 2 — Medium (D14–D16)

| # | Task | Owner | Days |
|---|---|---|---|
| W2.1 | Extend `scripts/qa.sh` with guards for the frozen contract: `intrinsicContentSize`/`sizingOptions` use, chrome-inside-ScrollView, animated resize on tab change, `maxViewportFraction` drift, glass-on-glass nesting | QA Lead | 1.5 |
| W2.2 | Close `offgrid_spacing` blind spot — guard currently greps only `spacing:`/`padding(`, missing 37 raw `.frame(width:height:)` literals outside `Sources/Design` | QA Lead | 0.75 |
| W2.3 | Bound `WordDiff` memory: cap input, chunk, or band the LCS; graceful degradation past threshold | Senior Eng | 1.5 |
| W2.4 | Call `PowerActivity.streamBegan()` at stream start; assert pairing with `streamEnded()` | Senior Eng | 0.25 |
| W2.5 | Replace 1s Accessibility poll with notification-driven observer, mirroring `AppearanceObserver` | Senior Eng | 0.5 |
| W2.6 | Debounce/incrementally-insert in `VaultStore.updateNote` instead of full re-sort | Senior Eng | 0.5 |
| W2.7 | Close replace/restore race: replace open-loop `Task.sleep(250ms)`/`(300ms)` with confirmed-state waits | Senior Eng | 1 |
| W2.8 | Surface `ProviderError` as actionable UI copy with remediation per case | Senior Eng + Writer | 0.75 |
| W2.9 | Clear `VaultStore.statusMessage` (set in 10 places, cleared in 0) | Mid Eng | 0.25 |
| W2.10 | Ship a Context Library editor, or gate the feature until one exists — it reaches the live system prompt invisibly today | Senior Eng | 1.5 |

#### Wave N — Native components & 100% Liquid Glass (D17–D24) — per D4

Runs **after** W1/W2 deliberately: correctness and security fixes land on the current UI before the UI
is replaced underneath them. Sequenced inside-out — tokens, then containers, then leaf controls, then
the panel last, because the panel is the riskiest surface and benefits from lessons learned elsewhere.

| # | Task | Owner | Days |
|---|---|---|---|
| WN.1 | Adopt `GlassEffectContainer` around sibling glass elements; add `glassEffectID` for morph identity. Foundation for everything after | Senior Eng | 1 |
| WN.2 | Migrate the hand-built dashboard sidebar to `NavigationSplitView`; inherit native glass sidebar, system highlight, keyboard + VoiceOver behaviour | Senior Eng | 1.5 |
| WN.3 | Convert settings pages to native `Form` / `Section` / `LabeledContent` / `GroupBox`, extending the `WorkspaceChrome.swift` pattern that already does this correctly | Senior Eng | 2 |
| WN.4 | Replace the replaceable custom controls in `SettingsControls.swift` with native `Button` (`.glass`/`.glassProminent`), `Toggle`, `Picker`, `TextField`, `Menu`. Retain and **document a justification for** each survivor | Senior Eng ×2 | 2 |
| WN.5 | **Icon system reversal:** migrate Lucide → SF Symbols; drop the `Lucide` SPM dependency and `IconNames.legacy`; keep `BeruIcon` as a thin SF-Symbols wrapper so call sites are stable | Mid Eng | 1 |
| WN.6 | Panel glass conformance — apply native materials to chrome/toolbar/composer **without** violating the frozen height contract. Highest-risk task; land alone, behind its own gate | Senior Eng | 1.5 |
| WN.7 | **macOS 27 readiness (D2):** document the annual OS-bump procedure; remove any reliance on undocumented material behaviour; add a `deploymentTarget`-vs-CI-runner consistency check | Tech Lead | 0.5 |
| WN.8 | Update `.cursor/rules/beru-design-tokens.mdc` to make *native-first* the written rule: prefer the system control, and require written justification for any custom one | Tech Lead + Writer | 0.5 |
| WN.9 | Add `qa.sh` guards for the new direction: `Image(systemName:)` **floor** (must not decrease toward 0), zero Lucide imports, zero new custom `ButtonStyle`/`ToggleStyle`, `glassEffect`-outside-`Design` check | QA Lead | 1 |

**WN.9 note — the ratchet must be inverted for icons.** The existing gate only ever counts *down*.
Under D4, SF Symbol usage should count *up*, and Lucide usage down to zero. This needs a new
floor-style guard rather than a reused ceiling guard; do not bolt the new intent onto the old
counter's semantics.

#### Wave 3 — Low & polish (D25–D26)

| # | Task | Owner | Days |
|---|---|---|---|
| ~~W3.1~~ | ~~Replace the 2 remaining `Image(systemName:)` with Lucide~~ — **WITHDRAWN per D4.** SF Symbols is now the target; this task was pointing the wrong way. Superseded by WN.5 | — | — |
| W3.2 | Reconcile `AccentColor.colorset` with `PrimaryColor.indigo` | Mid Eng | 0.25 |
| W3.3 | Remove verified dead symbols (`strongBorder`, `softShadow`, `formMaxWidth`, `contentWidth`, `AppState.showDiff`, `errorProviders`, unreachable `PushToTalkMonitor` params) | Mid Eng | 0.75 |
| W3.4 | Resolve `PushToTalkMonitor` discarded callbacks — wire `fieldHasText`/`onPress` to the 6-times-tested `shouldStartDictation`, or delete both param and tests | Senior Eng | 0.75 |
| W3.5 | Move `DashboardMetrics.lg = 28` onto the grid or document why it is off it | Mid Eng | 0.25 |
| W3.6 | Extract pure helpers from `PanelController` (`clampedOrigin`, `maxPanelHeight`, `applyHeight`) and unit-test | Senior Eng | 0.75 |
| W3.7 | Relieve the 380–395-line files nearing the 400 ceiling | Senior Eng | 1 |
| W3.8 | Decide localization: scope it or record an explicit non-goal in the PRD | Tech Lead | 0.5 |

### P4 — Verification & regression (D19–D21)

| # | Task | Owner | Days |
|---|---|---|---|
| P4.1 | Full test suite on macOS 26; zero failures | QA Lead | 0.5 |
| P4.2 | `./scripts/qa.sh` — confirm every counter ≤ baseline and that tightened guards hold | QA Lead | 0.25 |
| P4.3 | Complete manual `docs/QA-CHECKLIST.md`, including new cases from this audit | QA Eng | 1 |
| P4.4 | Perf re-measurement vs P1.5 numbers; confirm no regression | Perf Eng | 0.5 |
| P4.5 | Security re-test of updater incl. adversarial temp-path cases | Security Eng | 0.5 |
| P4.6 | Accessibility re-test: VoiceOver, keyboard-only, Dynamic Type XXL, Reduce Transparency/Motion | Accessibility Spec | 0.75 |
| P4.7 | Install/upgrade dry run: DMG → `xattr -cr` → launch → self-update | Release Eng | 0.5 |
| P4.8 | Doc re-verification: every claim in README/PRD/SECURITY matches shipped behaviour | Tech Writer | 0.5 |

### P5 — Sign-off (D22)

| # | Task | Owner | Days |
|---|---|---|---|
| P5.1 | Final report: findings, dispositions, residual risk | Audit Lead | 0.5 |
| P5.2 | Completion-criteria attestation (§6) — signed per workstream | All leads | 0.25 |
| P5.3 | Version bump; regenerate baseline if legitimately lowered; tag | Release Eng | 0.25 |

---

## 3. Testing & validation after every fixing iteration

Applied per commit, not per wave. A change that cannot pass this gate does not merge.

### 3.1 Per-commit gate

1. `xcodegen generate` — project regenerates (`Beru.xcodeproj` is generated and gitignored).
2. `xcodebuild` clean build, macOS 26, warnings-as-errors where configured.
3. `./scripts/qa.sh --static` then `./scripts/qa.sh` — **ratchet may only decrease**. Any increase
   fails the commit.
4. Full unit suite. New behaviour requires a new test in the same commit.
5. Targeted manual check of the touched surface from `docs/QA-CHECKLIST.md`.
6. Confirm one-logical-change scope per `beru-qa-gate.mdc`.

### 3.2 Regression protection by risk class

| Risk class | Required validation |
|---|---|
| Panel geometry/height | `PanelViewportCapTests` + manual: short/long/streaming result, tab switch, cap behaviour, composer never clipped |
| Glass / visual tokens | Light + dark × Reduce Transparency on/off × 12 accents; assert no glass-on-glass |
| Keyboard/input | `PanelKeyBindingTests`; manual ↩ / ⌘↩ / ⌘C / ⌘1-9 / Esc; **explicitly verify no destructive replace on bare ↩** |
| Text capture/replace | `TextReplaceTests` + manual across host apps incl. an editable field and a secure field |
| Provider/streaming | Provider matrix; stream start/cancel/error; verify `streamBegan`/`streamEnded` pairing |
| Security/updater | Signature+checksum verification; adversarial pre-created temp path; interrupted update leaves a working app |
| Accessibility | VoiceOver traversal; keyboard-only completion of the core journey; Dynamic Type XXL |
| Perf | Compare to P1.5 baseline; no metric worse by >10% |

### 3.3 Wave-exit regression run

At each wave end: full suite + full manual checklist + perf re-measure + install/upgrade dry run.
Any S1/S2 regression reverts the offending commit rather than stacking a follow-up fix.

---

## 4. Risk assessment & mitigation

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **No macOS 26 build environment.** Audit prepared on Linux; `xcodebuild`/`xcodegen`/SDK absent. Dynamic, perf, security, and accessibility verification are all blocked | High | Critical | P0.1/P0.3 are hard gates. Use the `macos-26` CI runner already configured. If unobtainable, downgrade the deliverable to static-only **and say so in the report** — never imply dynamic validation that did not happen |
| R2 | ~~macOS 26 hard floor undeclared~~ — **CLOSED by D2.** Floor is intentional (26 now, 27 on release) | — | — | Residual work is documentation + WN.7 forward-readiness, not a decision |
| R3 | **Frozen panel contract is prose-only** — `qa.sh` unchanged while the contract was rewritten. Regression is a matter of time | High | High | W2.1 converts each "Do not" into a static guard |
| R4 | **Dynamic Type retrofit breaks fixed-size glass layouts** — the panel is a fixed 420pt wide with a 75% height cap | Medium | High | Land W1.5 early in its own wave; test at every size class; be willing to cap scaling in the panel while honouring it in the dashboard |
| R5 | **Updater fix bricks installs.** Touching a component that deletes the app bundle risks leaving users with no app | Medium | Critical | Move-aside-then-restore instead of `rm -rf`; verify before destroy; mandatory interrupted-update test (§3.2); staged rollout |
| R6 | **Ratchet gamed rather than satisfied** — `--update-baseline` exists and can paper over regressions | Medium | Medium | Baseline changes require a second reviewer and a written justification; increases are never accepted |
| R7 | **Fix-induced regressions** across an 80-file redesign | Medium | High | One logical change per commit; per-commit gate; revert-not-patch on S1/S2 |
| R8 | **Prior-audit findings are stale** and waste remediation effort | Medium | Medium | P0.6/P2.1 re-verify each on-branch before any work; discard non-reproducible ones (already corrected one such error re: `glassChip`) |
| R9 | **Provider testing needs live credentials/models** for 5 providers | Medium | Medium | Prioritize local Ollama (no key); mock/replay HTTP for the rest; mark untested paths as residual risk |
| R10 | ~~`liquid-glass` diverges from `main`~~ — **CLOSED by D1.** Fast-forwarded; `origin/main` == `origin/liquid-glass` (0/0) | — | — | Single release line. Consider deleting `origin/liquid-glass` to prevent accidental re-divergence |
| **R14** | **Native migration regresses the frozen panel height contract.** WN.6 touches the product's core surface; native components bring their own intrinsic sizing, which is exactly what the contract forbids driving height from | **High** | **Critical** | Land WN.6 alone behind its own gate, after all other native work. `PanelViewportCapTests` must pass unmodified — if the test needs changing, the contract is being broken. Revert-not-patch |
| **R15** | **Native controls override the design-token system.** System components carry Apple's metrics, not Beru's 4/8pt grid and `BeruType` roles, so `offgrid_spacing` will fight WN.3/WN.4 | High | Medium | Scope the guard to exclude native-component files; document as a deliberate baseline change with second-reviewer approval. Do **not** fork native controls to force token compliance — that recreates the custom-control problem D4 exists to remove |
| **R16** | **"100%" is unfalsifiable as written.** Without a definition, the goal cannot be signed off | High | Medium | §6.8 defines it as a measurable checklist. Some AppKit remains legitimately necessary (`FloatingPanel: NSPanel`, `DictationPressView` press-and-hold); these are declared *sanctioned exceptions* rather than counted as failures |
| **R17** | **Dropping Lucide loses icons with no SF Symbols equivalent** (~50 legacy mappings exist) | Medium | Medium | P1.11 does the coverage test **before** WN.5 commits. Any gap is filled with a custom SF-Symbol-styled asset, not by retaining the whole dependency |
| **R18** | **Dynamic Type work (W1.5) collides with native migration (WN.3/WN.4)**, since native controls handle Dynamic Type themselves — W1.5 may be partly wasted effort | Medium | Medium | Accept some rework: W1.5 fixes today's shipping UI; native adoption then supersedes parts of it. Alternative — defer W1.5 for surfaces scheduled for WN.3/WN.4, and fix only surfaces that stay custom. Tech Lead decides at P2.4 |
| R11 | **Secure-field capture** (`AXSecureTextField` in `editableRoles`) may be an unintended password-exposure path | Low | Critical | P1.6 determines intent; if unintended, exclude and add a test; if intended, document prominently |
| R12 | **Scope creep** — "authority to improve" invites unbounded redesign | High | Medium | Waves are fixed; new ideas go to a backlog, not the current wave; `beru-qa-gate.mdc` do-not-do-unprompted list is binding |
| R13 | **Single-maintainer bandwidth** — the role table below assumes more people than this project likely has | High | Medium | Roles are *hats*, not headcount. One engineer may wear several; serialize waves and extend the calendar proportionally rather than skipping gates |

---

## 5. Roles

Roles are functions. On a small team one person wears several; the timeline then stretches rather
than the gates loosening.

| Role | Responsibility |
|---|---|
| Audit Lead | Register ownership, severity calls, interim/final reports, completion attestation |
| Tech Lead | Root-cause clustering, wave assignment, architectural decisions, baseline-change approval |
| Senior macOS Eng (×2) | Panel/design-system/engine remediation, unit tests |
| Mid Eng | Low-severity cleanup, dead-code removal, token reconciliation |
| QA Lead | Ratchet ownership, `qa.sh` extension, gate enforcement |
| QA Eng | Manual checklist, provider matrix |
| Security Eng | Updater, Keychain, capture paths, install scripts |
| Perf Eng | Baseline + re-measurement |
| Accessibility Spec | VoiceOver, keyboard, Dynamic Type, Reduce Transparency/Motion |
| Tech Writer | PRD/README/SECURITY reconciliation, user-facing error copy |
| Release Eng | macOS 26 host + CI, DMG/notarization, install-upgrade validation |

---

## 6. Completion criteria — when is it "good"?

The audit is complete and the product deemed good only when **all** of the following hold. Each is
objectively checkable; none is a judgement call.

### 6.1 Process completion

- [ ] All 121 `Sources/` files reviewed and logged.
- [ ] All five workstreams (§1.1–1.5) have written findings.
- [ ] Each of the 41 prior findings marked **carried / resolved / stale**, with on-branch evidence.
- [ ] Every finding has a disposition: fixed, deferred-with-justification, or won't-fix-with-rationale.
- [ ] Every deferred/won't-fix item is recorded in `docs/PRD.md` §16 "Known product gaps" — nothing
      silently dropped.

### 6.2 Quality bars

- [ ] **S1 = 0** and **S2 = 0** outstanding. Non-negotiable.
- [ ] S3 either fixed or explicitly accepted by the Tech Lead in writing.
- [ ] Clean build on macOS 26 with no new warnings.
- [ ] Full test suite green.
- [ ] `./scripts/qa.sh` — every counter ≤ recorded baseline, with **no baseline increases**.
- [ ] New guards added for: glass-on-glass, `intrinsicContentSize` misuse, chrome-in-ScrollView,
      `maxViewportFraction` drift, `Image(systemName:)` at 0, and `.frame` off-grid literals.
- [ ] Test:source LOC ratio ≥ 0.27 (no dilution from this baseline).

### 6.3 Functional bars

- [ ] Core journey — select → hotkey → result → replace — passes on all 5 providers, or unavailable
      providers are documented as untested.
- [ ] No destructive action reachable from a single unmodified keystroke.
- [ ] Every `ProviderError` case renders actionable user-facing copy.
- [ ] Onboarding cannot complete into a non-functional state.
- [ ] Interrupted update always leaves a launchable app (tested adversarially).

### 6.4 Accessibility bars

- [ ] Core journey completable **keyboard-only**.
- [ ] VoiceOver traverses panel and dashboard with meaningful labels; toggles expose toggle traits.
- [ ] Dynamic Type honoured to XXL with no clipping or overlap.
- [ ] Reduce Transparency and Reduce Motion both verified across light/dark.

### 6.5 Performance bars

- [ ] No metric >10% worse than the P1.5 baseline.
- [ ] `WordDiff` bounded — no unbounded allocation on adversarial input.
- [ ] No polling loop where a notification-driven observer is available.
- [ ] App Nap suppressed for the full duration of streaming.

### 6.6 Documentation bars

- [ ] PRD version header and footer match `project.yml` exactly.
- [ ] PRD reflects the glass rebuild and the macOS 26 floor.
- [ ] `SECURITY.md` covers the updater threat model.
- [ ] README claims verified against shipped behaviour.
- [ ] `docs/QA-CHECKLIST.md` extended with this audit's new cases.
- [ ] `.cursor/rules/` matches enforced reality — no prose-only contracts left unguarded.

### 6.7 Explicit non-goals

Recorded so absence is not later mistaken for oversight:

- **Windows `.exe` / any cross-platform work** — per **D3**, later scope, explicitly not now. No
  portability abstraction is to be introduced, as it would work against D4.
- **Backward compatibility below macOS 26** — per **D2**, the floor is deliberate.
- Localization (scope decided at W3.8).
- App Sandbox adoption — PRD documents non-sandboxed by design.
- iOS/iPadOS support; provider additions; features beyond those already partially built (Context
  Library editor, `historyMaxMegabytes` UI).

### 6.8 "100% Liquid Glass / 100% native" — definition of done (per D4, closes R16)

"100%" is meaningless unless falsifiable, so it is defined as this checklist. All items must hold:

- [ ] **Zero** third-party UI dependencies: `Lucide` removed from `project.yml`; zero Lucide imports
      in `Sources/`.
- [ ] **All** iconography is SF Symbols.
- [ ] Every remaining custom control in `Sources/Design/` carries a written justification naming the
      native control it replaces and why the native one is insufficient. Target: **≤ 4 survivors** of
      today's 13.
- [ ] Zero custom `ButtonStyle`/`ToggleStyle` where a native style exists.
- [ ] Dashboard navigation is `NavigationSplitView`.
- [ ] Settings pages are native `Form`/`Section`/`LabeledContent`.
- [ ] Sibling glass elements are wrapped in `GlassEffectContainer`; glass state transitions use
      `glassEffectID`.
- [ ] No glass-on-glass nesting anywhere (statically guarded).
- [ ] Reduce Transparency verified on every glass surface — the existing
      `GlassModule`/`GlassSlab` fallbacks extended to all new surfaces, not just the two original files.
- [ ] Visual audit against Apple's Liquid Glass HIG, signed by Design.
- [ ] **Sanctioned AppKit exceptions** — declared, justified, and finite. Current expected list:
      `FloatingPanel: NSPanel` (a non-activating borderless panel has no SwiftUI equivalent),
      `DictationPressView` (press-and-hold hit-target), `NSMenu.popUp` for target/provider pickers if
      no native equivalent preserves behaviour. Anything not on this list is a failure.
- [ ] `docs/PRD.md` and `.cursor/rules/beru-design-tokens.mdc` both state native-first as the rule.

**Deliberately not claimed:** that zero AppKit remains. A menu-bar utility that injects text into
other apps cannot be pure SwiftUI. "100% native" means *no third-party UI and no custom
reimplementation of anything the system provides* — not the elimination of AppKit.

---

## 7. Immediate next actions

**Done:**
- ~~Confirm release target~~ — **D1 executed.** `main` fast-forwarded to `1d02e69`; `origin/main` ==
  `origin/liquid-glass` (0/0).
- ~~Ratify the macOS floor~~ — **D2 ratified.** 26 now, 27 on release.
- ~~Windows scope~~ — **D3 ratified.** Out of scope.
- ~~UI direction~~ — **D4 ratified.** 100% Liquid Glass, 100% native.

**Open, in priority order:**

1. **R1 — the only true blocker.** No macOS 26 build host exists in this environment
   (`xcodebuild`/`xcodegen`/SDK absent; all analysis to date is static). D4 makes this *worse*, not
   better: a native-component migration cannot be validated by grep. Wave N is unshippable without a
   macOS 26 machine or the already-configured `macos-26` CI runner.
2. **Delete `origin/liquid-glass`?** Now identical to `main`. Keeping it invites accidental
   re-divergence; deleting it makes the single release line unambiguous. Recommend deleting.
3. **Decide R18** — whether Dynamic Type (W1.5) is done twice or deferred for surfaces heading into
   Wave N. Affects ~1.5 days.
4. **Confirm the ≤4 custom-control survivor target** in §6.8, and the sanctioned AppKit exception
   list. These are the numbers "100%" will be judged against.
5. **Approve the 33-day schedule**, or instruct that Wave N ship as a separate release after a
   W1/W2 correctness release. Given the panel-contract risk (**R14**), a two-release split is the
   lower-risk path and is the recommendation.

---

*This plan describes work to be done; no source file has been modified in producing it. Every factual
claim above was verified against `origin/liquid-glass` @ `1d02e69` by direct inspection — file counts,
LOC, diffstats, ratchet values, version strings, API call sites, and line numbers are measured, not
estimated. Directives D1-D4 are ratified product decisions from the maintainer and take precedence over any earlier recommendation in this document.*
