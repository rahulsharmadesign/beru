# Beru — Product Requirements Document

**Product:** Beru
**Platform:** macOS 26+ (menu bar app)
**Version this document describes:** 1.1.9 (build 15)
**Bundle ID:** `com.rahul.beru`
**Status:** Shipped on macOS. Windows and cloud sync are not in this build.
**Audience:** Product, design, engineering, and anyone deciding what Beru is allowed to do.

This document describes the product **as it exists**. It is the source of truth for behavior, defaults, constraints, and what is explicitly out of scope. Implementation lives in the repo; this is the contract.

---

## 1. Problem

People write to language models the way they think: fragments, notes, half-prompts, a pasted error, a Slack thread. The model then does the wrong job, or a vague job, because the ask was not a prompt.

The usual workaround is another chat window: copy, paste, rewrite, copy back. That takes the person out of the app they were already in, and the rewrite is generic — it does not know whether the destination is Cursor, Claude, or ChatGPT.

Beru is the in-place rewrite. Select the rough thought, press a hotkey, get a prompt (or a correction, a reply, a summary) aimed at a specific tool, then put it back where the selection was.

---

## 2. Product thesis

Beru lives in the menu bar. It does **not** take over the host app. It is a privileged utility that reads the current selection, runs a local or cloud model the user chose, and can replace that selection.

Three rules the product is not allowed to violate:

1. **Stay in place.** The host app remains the host. Beru is a floating panel, not a workspace that people live in.
2. **Stay on this Mac unless the user sent it away.** No Beru server, no analytics, no telemetry, no crash reporter. Selected text goes only to the LLM provider the user configured. Speech never leaves the machine.
3. **The button does what the button says.** Grammar corrects. Enhance writes a prompt. A custom action runs its own prompt. Nothing overrides a built-in verb with a saved prompt that would make the chip a lie.

---

## 3. Who it is for

| Person | Job | What success looks like |
|---|---|---|
| Someone writing for an LLM (Cursor, Claude, ChatGPT, Codex, Gemini, Kimi) | Turn a rough idea into a prompt that tool will follow | Select → hotkey → Enhance → Replace, without leaving the editor |
| Someone writing anything | Fix grammar without changing voice | Grammar returns a copy-edit, shown as a diff, not a rewrite |
| Someone answering mail, Slack, comments | Draft a reply in a chosen voice | Smart Reply: six tones, Insert or Copy one |
| Someone who does not want to type | Speak the rough idea | ⌃⌥⌘L, talk, Enhance still does the rewrite |
| Someone who will not send work to the cloud | Same jobs, local model | Ollama + a pulled model; no API key |

**Not for:** people who need a full chat client, a prompt library in the cloud, or a sandboxed App Store app. Accessibility cannot work inside the App Sandbox, so Beru is not sandboxed.

---

## 4. Goals and non-goals

### Goals (this product)

- Capture selected text from any Mac app (Accessibility, falling back to simulated ⌘C).
- Run Enhance, Grammar, Search, and user-defined actions against a chosen provider.
- Shape Enhance for a **target** (Cursor, ChatGPT, Claude, Kimi, or a custom destination).
- Write the result back into the selection (Replace) or into a vault note (Apply).
- Let the user speak instead of type, with on-device speech only.
- Keep a local vault and optional local run history.
- Let Enhance / Describe / Search remember the last few turns **in the same host app**, in memory only.

### Non-goals (not in this build)

- Windows client (stated as in progress; macOS is the supported product).
- Cloud sync of settings, runs, or vault (local-only is the default and the only mode).
- A Beru account, Beru API, or Beru proxy in front of providers.
- Editing Context Library playbooks / author Markdown profiles in Settings (engine exists; no UI — see §16).
- Sandboxed / Mac App Store distribution.
- Apple Developer ID / notarized releases (DMGs are ad-hoc signed; Gatekeeper must be allowed once).
- Built-in Codex or Gemini target profiles (users add those under Targets).

---

## 5. Product principles

1. **One job per chip.** A Grammar result that restyles is a bug, not a feature.
2. **Empty states say what to do next.** No Accessibility → Open System Settings. No model → Connect to model. No selection on Search → Ask a question.
3. **Destructive or surprising context is visible.** Session history shows “Using N prior turns” and can be cleared in one click. Usage recording is off until turned on.
4. **Defaults are useful and conservative.** Recording off. Session context on (RAM only). Local Ollama first. Same model for Enhance and Grammar so Ollama does not swap weights on every tab.
5. **The panel sizes to its content.** Idle, error, loading, and no-Accessibility states must not clip at the top or bottom.
6. **Never prompt for Keychain when the user did not change a key.** Switching Settings tabs, especially to Models, must not ask for the password.

---

## 6. Surfaces

Beru is four surfaces. Nothing else is a window.

| Surface | Role | Notes |
|---|---|---|
| **Menu bar extra** | Always-on entry | `LSUIElement` — no Dock icon unless the user reopens from Finder/Spotlight |
| **Floating panel** | The product | Non-activating panel over the host app |
| **Get Started** | First launch only | 420×520; closes itself once Accessibility is granted and the user finishes |
| **Settings dashboard** | Configuration + workspaces | Titled “Beru”; min ~880×560; sidebar routes below |

Reopening the app from Dock / Finder / Spotlight opens the dashboard. A second launch of the binary tells the running instance to show the dashboard and quits.

---

## 7. End-to-end journeys

### 7.1 First run

```
Install → launch → Get Started
  1. Welcome
  2. Allow Accessibility  → Open System Settings if needed
  3. Start Beru           → panel opens on AI Search
```

- Get Started is gated on `hasCompletedGetStarted`. Until that is true, the invoke hotkey finishes onboarding instead of capturing.
- Accessibility is required for capture and replace. Microphone / Speech are optional and only for dictation; the system prompt appears the first time the user presses the mic or ⌃⌥⌘L, not during Get Started.
- Closing Get Started while Accessibility is already trusted also counts as complete.
- After first run, the user still needs a **provider** (Ollama running with a model, or a cloud key) before Enhance/Grammar can succeed.

**Install paths**

- **Release DMG** (unsigned / ad-hoc): drag to Applications, then `xattr -cr /Applications/Beru.app` or Control-click → Open.
- **From source:** `./scripts/make-signing-cert.sh` once, then `./scripts/install.sh` so Accessibility is not revoked on every rebuild.

### 7.2 Core loop — Enhance a prompt

```
In any app: select rough text
→ ⌃⌥⌘P (Open Beru)
→ Beru captures selection (AX, else ⌘C)
→ If the selection sits in an editable field of Cursor / ChatGPT / Claude / Kimi: land on Enhance Prompt
→ Stream result (optionally with a short “Why”)
→ Read it
→ Replace (writes back) or Copy or Pin
```

**Replace** is the primary success. The person should not have to copy-paste unless they choose to.

If the host is not a known LLM tool, routing picks the skill from context (first match wins): a chat/mail/social app → Smart Reply; an editable field → Grammar; otherwise short conversational text → Smart Reply, longer prose → Summarize. No selection anywhere, or clipboard/vault sources → AI Search.

### 7.3 Grammar

Same invoke. Chip: **Grammar**. Result is a copy-edit with an inline **word diff** when enough of the original survived. Meaning and tone must be preserved. Session context does **not** apply. “Explain what changed” does **not** apply (correction must not be traded for commentary).

### 7.4 Smart Reply

Same invoke. Chip: **Smart Reply**. Highlight the incoming message in any app (Mail, Slack, a comment in the browser) — Beru reads the selection, it does not scrape the page. One model call returns **six** ready-to-send replies (Formal, Casual, Funny, Professional, Witty, Sharp). Pick a card or the tone pill, then **Insert** or **Copy** that body only. The author markdown profile is folded in as voice; if none is active, the starter “My defaults” is used. Session context and “explain what changed” do not apply.

### 7.5 Ask without a selection

Empty selection, or menu **Dictate**, or ⌃⌥⌘L: panel opens on **AI Search**. Type or speak a question. Capture is optional.

### 7.6 Follow-up in the same app

With **Remember recent turns** on (default): Enhance, Instruction, or Search in the same host app can see the last 3 turns for ~30 minutes. The panel shows **Using N prior turns**. Click the chip to forget. Switch apps → thread cleared. Grammar never sees it.

### 7.7 Voice instead of keyboard

⌃⌥⌘L or the mic: Beru listens **on this Mac** (no Apple servers, no Beru servers). Hard stop at 60 seconds. Press the shortcut again, the mic, or Escape to stop. Spoken text lands in the instruction field (Ask) or as the working text, depending on how dictation was started. Enhance still rewrites it.

If on-device recognition is unavailable, dictation is refused. There is no cloud fallback.

### 7.8 Local model setup

Settings → Models: install Ollama if needed, pull a recommended model (Gemma 3 1B ~815 MB, Qwen 2.5 7B default, Qwen 3 8B). **Install continues if the user leaves Models.** Sidebar shows a download badge. Enhance/Grammar pickers include the recommended tags so an advertised model is actually selectable.

### 7.9 Vault note

Settings → Vault: write markdown locally. **Enhance this note** opens the panel with the note as capture. **Apply** writes the result back into the note (not into some other app).

---

## 8. Menu bar

Window-style extra, 320pt wide. Accessibility name: “Beru”.

| Element | Behavior |
|---|---|
| Brand + status | “Needs Accessibility” / “Set up a provider in Settings” / “Ready to refine your writing” |
| **Enhance Clipboard** | Runs on clipboard text; shows the invoke shortcut. Empty clipboard → Search |
| **Dictate** | Opens Ask and starts listening |
| **Vault** | Opens dashboard on Vault |
| Provider row | Only configured providers; switching here is the same as the panel picker |
| **Settings** | Opens dashboard |
| **Quit** | Quits |

---

## 9. Floating panel

The panel is the product. It is one composition: close strip → verb chips + context line → result → composer.

### 9.1 Invoke and capture

| Step | Requirement |
|---|---|
| Hotkey | Default **⌃⌥⌘P**, user-changeable in General |
| Capture | Accessibility selection first; simulated ⌘C if AX fails |
| Cap | **8000 characters**. Banner: “Selection was truncated to 8000 characters” |
| Host | Bundle ID + name used for target suggestion and session-thread key |
| Clipboard chip | Shown if pasteboard ≠ selection. **Off** until the user opts in (“Clipboard ✓”) |
| Auto-run | Non-Search actions with capture start generation immediately |

**Which chip is selected on open**

1. Provider not configured, or an empty-selection Search path → **AI Search**
2. Host matches Cursor / VS Code, ChatGPT, Claude, or Kimi seeds → **Enhance Prompt**
3. Else → **Default action** (General; shipped **Grammar**)

### 9.2 Action chips

Order: **AI Search** always first; **Instruction** only while a one-off describe is active; then registry order (Grammar, Enhance Prompt, then custom verbs).

| Chip | ID | Needs selection | Diff | Session thread | Targets |
|---|---|---|---|---|---|
| AI Search | `ai-search` | No | No | Yes | No |
| Instruction | `describe` | No | No | Yes | No |
| Grammar | `grammar` | Yes | Yes | No | No |
| Enhance Prompt | `enhance` | Yes | Yes | Yes | Yes |
| Smart Reply | `verb-reply` | Yes | No | No | No |
| Summarize / Explain (seeded customs) | `verb-*` | Yes | No | No | No |
| User-saved actions | custom | Yes | No | No | No |

Hover copy is the `summary` on each action (e.g. Grammar: “Fix spelling, grammar, and punctuation while keeping your meaning and tone”).

**⌘1–9** selects chips in the visible order.

Caption under the chips names the live skill and the host, so a Cursor invoke that landed on Enhance Prompt is not read as Grammar:

- No capture: `{skill} · {host}` (host falls back to “Mac”)
- With capture: `{skill} · {host} · N characters`

The line always occupies height (opacity only) so Search ↔ skill does not resize the toolbar.

### 9.3 Result states

| State | What the user sees |
|---|---|
| Idle, Accessibility off | “Allow Accessibility” + Open System Settings. Panel must still size to the card (no top/bottom clip) |
| Idle, no provider | “Choose your AI model” / connect CTAs |
| Idle, no selection (verbs) | “No text selected” — highlight in another app, or switch to AI Search |
| Loading | Placeholder height, not an infinite fill |
| Thinking | “Thinking…” (reasoning models; reasoning never enters the document) |
| Streaming | Visible text grows; rationale markup is not shown live |
| Done | Result, optional diff, optional Why, savings, footer actions. Smart Reply: six selectable tone cards |
| Error | Message + **Retry**. Unknown/missing model also **Connect to model**. Other configured providers: **Try with Ollama / Anthropic / API** |

### 9.4 Composer

- Intent field placeholders: “Ask anything — no selection needed” (Search), “Highlight text first” (verb, no selection), “Type what you want Beru to do” (Instruction), and per-skill hints (“Optional: e.g. ‘keep my tone’”)
- **Return** submits the intent if the field has text; otherwise Replace / Insert
- **⌘Return** Replace / Insert / Apply
- **⌘C** Copy result (when a result exists)
- **Esc** cancel / dismiss (if dictating, Escape stops the mic first)
- Send control enabled only when there is an instruction
- Mic: on-device dictation, 60s cap
- Regenerate when done or on error
- **Target** pill only on built-in Enhance Prompt
- **Tone** pill on Smart Reply; choosing a tone highlights a card and does not re-run
- **Provider** pill otherwise (Ollama / Anthropic / API)

### 9.5 Footer (done only)

- Token savings estimate: `−N tok` / `+N tok` / `±0 tok`
- **Replace** (or **Insert** on Smart Reply, or **Apply** when the source was a vault note) — transient “Replaced in [app]” / “Inserted in [app]” / “Applied to note” for 2 seconds, then the panel dismisses and the paste runs. Escape during the toast dismisses immediately and still writes.
- **Copy** — transient “Copied”. Smart Reply copies the selected card only
- **Pin** — saves a pin in the vault; transient “Pinned”

### 9.6 Session context chip

Visible on Enhance / Instruction / Search when there is at least one prior turn for this app.

- Copy: “Using 1 prior turn” / “Using N prior turns”
- Click: clears the thread immediately
- Never shown for Grammar
- Disappears immediately when General → Remember recent turns is turned off

### 9.7 Explain what changed

General toggle, **default on**. Appends a short rationale to Enhance-style jobs **except Grammar, Search, and Smart Reply**. Shown collapsed under the result as “Why”. Must not cause Grammar to echo the input unchanged. Smart Reply skips it so a `<why>` block cannot break the six-tone parse.

---

## 10. Settings dashboard

Sidebar, searchable. Menu: General, Models, Permissions, Data, Vault, Runs, Actions, Targets. Footer: About.

Every route has a **page subtitle** that is actually rendered (not discarded). Narrow window: rows reflow without an abrupt jump. Light and dark both required.

One-time **Tip** card above About (dismissible): lightweight local model (Gemma 3 1B) with **View models** → Models.

Switching routes must **not** show “Beru wants to use your confidential information” (Keychain). Keys load only for the active cloud provider.

### 10.1 General

| Setting | Default | Notes |
|---|---|---|
| Name | empty | Local greetings only |
| Primary color | Indigo | 12 accents; panel and dashboard both repaint immediately |
| Open Beru shortcut | ⌃⌥⌘P | |
| Dictate shortcut | ⌃⌥⌘L | Old bare-Space shortcut migrated once |
| Run Beru at login | Off | `SMAppService` |
| Default action | Grammar | Used for clipboard / vault / unknown hosts |
| Explain what changed | On | Not Grammar, not Search, not Smart Reply |
| Remember recent turns | On | 3 turns, 30 min idle, memory only |

### 10.2 Models

- Active provider: **Ollama (local)** / **Anthropic** / **API (Groq, OpenAI, …)**
- Ollama URL default: `http://localhost:11434/v1`
- Enhance and Grammar model pickers: recommended catalog **plus** current custom tag
- Recommended install list: Gemma 3 1B, Qwen 3 8B, Qwen 2.5 7B (**Default** label is derived from the shipped id `qwen2.5:7b` — both roles share it)
- Pull is process-lived: leaving Models does not cancel; Cancel is explicit; sidebar badge while downloading
- After a first install, if the user was still on the shipped default id, assign the new model so the panel can use it without a second trip
- **Test connection**
- Custom presets: Groq, OpenAI, OpenRouter, Custom URL. Groq default model `openai/gpt-oss-120b`. Retired Groq ids rewritten on load
- Anthropic models are fixed: enhance `claude-sonnet-5`, grammar `claude-haiku-4-5`
- API keys in Keychain only (`WhenUnlockedThisDeviceOnly`)

A provider is **configured** when: Ollama has URL + both model ids; Anthropic has a key; Custom has URL + models, and a key unless the host is localhost / 127.0.0.1.

### 10.3 Permissions

- Accessibility: **Granted** / **Needed** badge. **Grant** (primary) when needed — system prompt plus System Settings. **Open** when granted. Status refreshes when Beru becomes active again (return from System Settings), not on a timer.
- Dictation: **Granted** / **Needed** / **Unavailable**. **Grant** on first ask (system prompt). **Open** otherwise, with the reason from the speech stack.

### 10.4 Data

- Token savings summary (local estimates)
- **Record usage** default **off**
- Retention: 30 / **90** / 365 / Forever days
- Reveal in Finder, export JSONL / CSV, Clear history
- Soft cap `historyMaxMegabytes` default 200 — enforced, **no UI** (known gap)

### 10.5 Vault

Local markdown. Default folder `~/Library/Application Support/Beru/vault/` (0700 / files 0600). Optional user folder (iCloud, Dropbox) — folder permissions are the cloud provider’s; files Beru writes stay 0600.

- Empty vault seeds a Welcome note
- List + search; **Notes | Pins** segmented control; Folder menu for Choose / local reset / export / import; **+/−** on the list
- Last selected note, pin, and pane are restored when you return
- Edit / Preview; delete asks first
- Enhance this note → panel; **Apply** writes back and reopens Vault on that note
- **Pin note** switches to Pins with that pin selected
- Pins: from panel Pin, Pin note, or Pin link (http/https only); Enhance / Open / Copy / Delete; Open note when the pin came from a note

### 10.6 Runs

Only meaningful when recording is on. When off, show the recording-off empty state (files on disk are not deleted).

- Filters: search, action, host app, Accepted only
- Grouped by day
- Detail: input/output, diff when applicable, rationale
- Actions: **Enhance again** (result, or input if none), **Pin**, **Save as note** (opens that note in Vault), Copy result, Copy your text

Outcomes folded from events: Replaced, Copied, Dismissed, Cancelled, Failed, No text selected, Left open.

### 10.7 Actions

- Built-in Grammar and Enhance: prompts are the live shipped text (not a stale saved copy)
- Seeded customs: Smart Reply, Summarize, Explain — editable
- User customs: name, Lucide icon, prompt; drag reorder when search is empty
- New Action via the list **+**; More for export / import; delete with confirm; Insert Tone Preset
- AI Search and Instruction are **not** listed here

### 10.8 Targets

Where Enhance is going. Built-in: **Generic** (no extra fragment), **Cursor**, **ChatGPT**, **Claude**, **Kimi**. Built-ins can be edited and Reset to Default. Users add custom targets (list **+**; More for export / import / delete with confirm).

Applied **only** on built-in Enhance Prompt. Generic contributes nothing.

Host matching (examples): Cursor / VS Code → Cursor; ChatGPT app → ChatGPT; Anthropic apps → Claude; name heuristics for Kimi. Last target is remembered globally and per host app.

### 10.9 About

This build’s version, MIT, privacy summary, tip (Razorpay), GitHub, update check.

---

## 11. Session context (Enhance memory)

**Problem:** Every request used to be exactly `[system, user]`. A second Enhance in Mail could not mean “shorter.”

| Rule | Requirement |
|---|---|
| Who | Enhance Prompt, Instruction, AI Search |
| Who not | Grammar, custom actions |
| Cap | Last **3** turns |
| Idle | **30 minutes** then empty |
| Key | Host **bundle ID**. Switching apps clears |
| Persistence | **RAM only**. Never written to disk at any setting. Dies with the process. Independent of usage logging |
| Placement | Folded into the **system** prompt (not the user message), so it does not inflate the output token budget derived from user length |
| Budget | Whole block ~1200 characters; each output ~400; input digest ~160 |
| Control | General toggle default on; panel chip to clear |
| Privacy | Cloud providers see truncated prior turns again on the next request in that app — document this; off is the escape |

---

## 12. Privacy and security (product requirements)

These are requirements, not footnotes.

1. **No Beru backend.** Settings, actions, targets, vault, history stay on the Mac.
2. **No analytics, telemetry, or crash reporting.**
3. **Selected text, instructions, and any applied playbook/profile** go only to the configured provider (Ollama local, or Anthropic / Groq / OpenAI / custom HTTPS).
4. **Custom base URLs** must be `http://` or `https://`. `file:`, `unix:`, and other schemes are rejected.
5. **API keys** only in Keychain; never UserDefaults, logs, or history files.
6. **Usage history** off by default. When on: `~/Library/Application Support/Beru/history/` (dir 0700, files 0600), full input and output.
7. **Session context** is not history. It is RAM. See §11.
8. **Speech** on-device only; refuse if that cannot be guaranteed.
9. **Not sandboxed.** A compromised build can read and inject text in any app. Grant Accessibility only to a binary the user built or trusts.
10. **Replace is paste into the host.** Hostile selected text can still produce dangerous output. The product must frame selection as content, not instructions — mitigation, not a guarantee. Do not auto-replace into a terminal or password field without the user reading the result.
11. **Unsigned DMGs.** Gatekeeper block on first open is expected. Document `xattr -cr` and Control-click → Open.

---

## 13. Keyboard map

| Shortcut | Where | Action |
|---|---|---|
| ⌃⌥⌘P | System | Invoke / capture (user-changeable) |
| ⌃⌥⌘L | System | Toggle dictation / Ask (user-changeable) |
| Esc | Panel | Stop dictation if recording; else cancel / dismiss |
| Return | Panel | Submit intent if non-empty; else Replace |
| ⌘Return | Panel | Replace / Apply |
| ⌘C | Panel | Copy result |
| ⌘1–9 | Panel | Select visible chip |

---

## 14. Defaults (shipped)

| Key | Value |
|---|---|
| Provider | Ollama |
| Ollama models (both roles) | `qwen2.5:7b` |
| Default action | Grammar |
| Default target | Generic, then per-app memory |
| Explain what changed | On |
| Remember recent turns | On |
| Usage recording | Off |
| History retention | 90 days |
| Launch at login | Off |
| Accent | Indigo |
| Capture cap | 8000 characters |
| Dictation cap | 60 seconds |
| Panel session memory | 3 turns / 30 minutes / this process |

---

## 15. Error and empty catalog

Every row is a required UI, not a nice-to-have.

| Condition | User-facing response |
|---|---|
| Accessibility off | Placeholder + Open System Settings; panel height fits the card |
| Nothing selected (verb) | Idle copy; Search still available |
| Provider missing / Ollama down | Setup placeholder; Connect / Use local model |
| HTTP 404 / unknown model | Error copy + Retry **and** Connect to model |
| Other provider error | Retry + Try with [other configured provider] |
| Empty model response | “The model returned an empty response — try Regenerate” |
| Rate limit / bad key | Mapped provider messages (“Invalid API key — check Settings”, etc.) |
| Selection > 8000 chars | Truncation banner; still runs on the prefix |
| Dictation unavailable on-device | Dictation disabled; no silent cloud fallback |
| Download in progress, user left Models | Continues; badge in sidebar; Cancel still works |

---

## 16. Known product gaps (intentional or leftover)

| Item | Decision |
|---|---|
| Context Library (rules, playbooks, workspaces, glossary) | Engine applies seeded context; **no editor**. Do not ship a half-UI. Removing the engine is the alternative if editors never arrive |
| Author Markdown profile (“My defaults”) | Applied on Enhance and Smart Reply; no Settings page |
| Codex / Gemini as shipped targets | README mentions them as destinations people write *for*; they are custom Targets, not built-in profiles |
| `historyMaxMegabytes` | Enforced at 200; no control in Data |
| Windows | Not this product yet |
| Cloud sync | Not this product yet |

---

## 17. Quality bar (acceptance)

A change is not done until `./scripts/qa.sh` is green **and** the matching section of `docs/QA-CHECKLIST.md` has been clicked.

**Must never regress**

- Panel idle / error / loading / no-Accessibility: no clip at top or bottom
- Settings tab switch: no Keychain password prompt
- Models page: no beachball; pull progress must not freeze the window
- Accent and appearance: panel and dashboard repaint when they change
- Grammar: still a corrector after any Enhance or custom-prompt work
- Session chip: only Enhance / Instruction / Search; clears on click and on app switch

**Release**

- Version bump in `project.yml` only when explicitly releasing
- Tag `vX.Y.Z` builds the DMG on GitHub Actions
- Do not ship a local ad-hoc `/Applications` copy as the “release”; that resets Accessibility every rebuild unless signed with the stable local cert

---

## 18. Success (how we know this product works)

Qualitative, because there is no analytics:

- A person can Enhance in Cursor and Replace without touching the clipboard.
- Grammar on a messy sentence returns a diff, not a new personality.
- A second Enhance in Mail can mean “shorter” without re-pasting the first result.
- A person who refuses cloud can finish Get Started, pull Gemma 3 1B, and complete the same loop on Ollama.
- Voice: speak a rough idea, get a prompt, never leave the Mac.
- Switching Settings routes never asks for the login keychain.
- The panel never looks “broken” when Accessibility is off.

---

## 19. Glossary

| Term | Meaning |
|---|---|
| **Host app** | The app that had focus when Beru was invoked |
| **Enhance Prompt** | Built-in action that turns rough text into a prompt for a target tool |
| **Grammar** | Built-in copy-editor; one right answer; no session thread |
| **Target** | Destination dialect (Cursor, ChatGPT, …) folded into Enhance only |
| **Provider** | Where the tokens come from (Ollama, Anthropic, OpenAI-compatible API) |
| **Replace** | Write the result back into the original selection |
| **Apply** | Write the result back into a vault note |
| **Pin** | Save a snippet into the vault pins |
| **Session thread** | Last few Enhance/Search/Instruction turns in this app, RAM only |
| **Run** | One recorded invocation, if usage logging is on |

---

## 20. Document control

- **Describes:** Beru 1.1.9 as implemented in this repository.
- **Does not replace:** `README.md` (public pitch), `SECURITY.md` (threat model), `docs/QA-CHECKLIST.md` (manual pass), `CONTRIBUTING.md` (how to change it).
- **When behavior changes:** update this PRD in the same change as the code, in the section that changed — not as a separate “docs later” pass.
