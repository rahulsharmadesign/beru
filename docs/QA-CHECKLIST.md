# Manual QA checklist

`scripts/qa.sh` proves the code compiles and the logic holds. It cannot see the
screen. Run this list against the installed build (`./scripts/install.sh`) before
calling a change done.

Scope it: check the section for what changed, plus **Panel states** and
**Settings routes**, which are where regressions have historically landed.

## Panel states

Invoke with the hotkey and confirm nothing is clipped at the top or bottom and
the window height fits the content:

- [ ] Idle, with Accessibility granted (text selected, before running)
- [ ] Idle, with Accessibility **not** granted (the placeholder card)
- [ ] Loading / streaming: 32pt accent ring spinner in the result (selected primary, 50% track, 0.8s spin); send / Replace use a compact ring
- [ ] Long result: window grows up to **75%** of the visible screen; close disc, chips, and composer (Replace / Copy / Pin) stay visible; only the result scrolls
- [ ] Copy: icon pops to a green check, label reads Copied, then the panel closes after ~1.4s
- [ ] Result with a diff, and result long enough to scroll
- [ ] Error, with Retry visible
- [ ] Error from an unknown model, with Retry **and** Connect to model
- [ ] Provider setup (no model configured)
- [ ] Close disc on the leading edge; gear (no “Settings” label) opens Settings
- [ ] Close disc and composer sit 10pt in from the window on every side; idle tabs have no gray fill; selected tab is accent
- [ ] Open the panel and switch Search ↔ Enhance: inset does not collapse then snap; composer never crops
- [ ] In Cursor with a selection: context line reads “Enhance Prompt · Cursor · N characters”; switching to Grammar updates the skill name; no selection after switching: “Grammar · Cursor” (not “No text selected” on that line)
- [ ] Replace: footer shows “Replaced in [app]” for ~2s, then the panel closes and the host text updates; a second click during the toast does nothing; Escape during the toast still writes
- [ ] Select text on a webpage and invoke: **Summarize** is selected and already visible in the chip row (no horizontal swipe)
- [ ] AI Search: ask twice — both Q&As stack; window grows to 75% then scrolls; thread clears when the panel closes
- [ ] AI Search regenerate rewrites only the latest answer; earlier turns stay
- [ ] AI Search answers use `##` headings and body that read as distinct (size, weight, spacing)
- [ ] AI Search result footer is **Copy** and **Pin** only — no Replace, no token chip; composer does not crop; switching to Enhance Prompt brings Replace and the token chip back without jumping height

## Get Started

Reset by clearing `hasCompletedGetStarted` (or a fresh install):

- [ ] Three steps only: Welcome → Allow Accessibility → Start Beru. No microphone page
- [ ] After Start Beru, first mic click (or ⌃⌥⌘L) shows the system Microphone prompt; Allow starts listening. Settings → Permissions is not opened first

## Liquid Glass

- [ ] Panel over a light document and a dark window: floating HUD glass (refraction, not a frosted fill); host does not show through as holes between modules
- [ ] Result markdown and diffs stay readable on both hosts
- [ ] Reduce Transparency on: panel becomes opaque canvas without relaunching
- [ ] Reduce Transparency off: glass returns
- [ ] Settings uses the system window material (not a grey card, not a blur of the host); General → About twice with no stacked pages
- [ ] Window close traffic light has no square fill; shortcut recorder × has no dark bezel
- [ ] Menu bar extra keeps the original row layout on system chrome; Enhance Clipboard, Dictate, Vault, Settings still work

## Settings routes

Open Settings and visit every sidebar route twice, in this order:

- [ ] General, Models, Actions, Targets, Vault, Runs, Data, Permissions, About
- [ ] Permissions: Accessibility and Dictation show Granted/Needed badges; Needed shows a primary Grant; Open after a grant. Toggle Accessibility in System Settings, click back — badge updates without waiting
- [ ] No "Beru wants to use your confidential information" prompt at any point
- [ ] No beachball or lag when landing on Models
- [ ] Resize the window narrow: rows reflow without jumping or clipping
- [ ] Light mode and dark mode
- [ ] General → Open Beru / Dictate: both recorders are the same width as Name, right edges and × buttons line up
- [ ] About → Check for Updates: latest version copy, or Install plus a download icon beside About in the sidebar; local signing explains it will not replace itself

## Runs and Vault

Recording must be on (Data → Record usage):

- [ ] Open a finished run: **Enhance again** opens the panel on the result; **Pin** adds a vault pin; **Save as note** jumps to Vault with that note selected
- [ ] A failed run with no result: Enhance again uses the original text; Pin and Save as note stay disabled
- [ ] Enhance a vault note, Apply: toast “Applied to note”, panel closes, Settings opens on Vault with that note selected and the new body

## Workspace pages

Vault, Actions, Targets, Runs should read as macOS Settings (source list + inspector), not a custom app:

- [ ] Each list is a system source list: click, arrow keys, and selection use the system highlight (not a solid accent pill with inverted text)
- [ ] Hairlines are full-bleed: title rule, toolbar rule, split, inspector bars. About sits in the same 48pt footer as list +/−; selected About uses the same row highlight as General / Models
- [ ] Toolbar is always **search first**, then filters / Notes–Pins / More. Workspace inset is 16pt (not 32pt form padding)
- [ ] Actions / Targets / Vault: **+/−** at the bottom of the list. More/Folder for import and export
- [ ] Drag to reorder actions when search is empty (no grip handle)
- [ ] Inspector is grouped settings rows (Name, Icon, Kind, Prompt) — no hero icon header
- [ ] Conventions / Prompt editor wells use the system text-field fill (same as Name/Icon), not a navy canvas patch. Conventions, Prompt, and Vault notes have no leftover black scrollbar strip
- [ ] Runs group by day with native section headers; recording-off and empty states still explain themselves
- [ ] Delete a custom action, a custom target, and a note: confirmation, then gone. Built-ins have no Delete
- [ ] Leave Vault on a note, go to Actions, come back: the same note is selected
- [ ] Vault toolbar: **Notes | Pins**. Notes is list + editor (no third column). Pins is list + inspector
- [ ] Pin note: jumps to Pins with that pin selected. Open note on a snippet pin returns to Notes
- [ ] Pin link: `example.com` and `https://example.com` work; `javascript:` and `file:` stay disabled / rejected

## Models

- [ ] Install a model, then navigate away from Models: download continues
- [ ] Sidebar shows the download badge while it runs
- [ ] Return to Models: progress is still accurate, Cancel works
- [ ] Installed model appears in the Enhance and Grammar pickers

## Session context (when touched)

- [ ] Enhance twice in the same app: the second result builds on the first
- [ ] Chip reads "Using 1 prior turn", then "Using N prior turns" as you keep going
- [ ] Click the chip: it disappears and the next result ignores history, even if a stream was in flight
- [ ] Switch to a different app and invoke: no chip
- [ ] Grammar shows no chip even with turns recorded
- [ ] Toggle "Remember recent turns" off in General: chip gone immediately

## Accent and appearance

- [ ] Change the accent color: panel and Settings both repaint immediately
- [ ] Switch system appearance while the panel is open: it follows

## Smart Reply

Highlight a message in another app, invoke, then tap **Smart Reply**:

- [ ] Funny and Witty mention a concrete detail from the selected message; Formal stays non-jokey
- [ ] Tone pill jumps the highlight; clicking a card does the same; neither re-runs the model
- [ ] Copy / Insert send only the selected card, not the tagged blob; icon-only copy on a card copies that card
- [ ] Hotkey with a comment selected in Chrome/Safari opens **Smart Reply** automatically
- [ ] Roman Hinglish comment → all six replies stay in Roman/Latin (not Devanagari or German)
- [ ] If the model mixes languages across cards, a language notice appears — try Regenerate
- [ ] No selection on Grammar: idle says “Type or paste text”; composer matches; not “ask instead”. Type a sentence, Return → Grammar result; context line shows character count; composer is empty optional extras
- [ ] With a selection, Grammar still auto-runs; composer stays optional extras; Replace unchanged
- [ ] Type on Search with no selection, then click Enhance: Enhance runs on that text without a second Return
- [ ] Grammar shows Corrected / Clearer / Tighter as stacked cards like Smart Reply; selected card has the accent border; icon-only copy sits bottom-right on each card; clicking a card selects it without re-running; Replace / footer Copy send the selected body; no token savings pill
- [ ] Switching tabs slides the accent pill left/width over 0.4s (cubic-bezier 0.65, 0, 0.35, 1), not the window; close disc and composer move with the window immediately

## Before release only

- [ ] `./scripts/qa.sh` green
- [ ] Version bumped in `project.yml` (only when explicitly releasing)
