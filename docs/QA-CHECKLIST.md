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
- [ ] Idle placeholder copy stays centered between chips and composer when leftover height grows; panel is 480pt wide
- [ ] A finished Enhance has no graduation / “why” line under the result
- [ ] Idle, with Accessibility **not** granted (the placeholder card)
- [ ] Loading: pixel dots in the result; send disc uses muted fill when idle, accent when the field can submit; no spinner on the button
- [ ] Streaming: words print one by one with a blinking caret, newest word settling out of blur; Reduce Motion shows text as it arrives; composer does not bounce. Done Search answers gain markdown; history turns do not replay the typewriter
- [ ] Long result: window grows up to **75%** of the visible screen; close disc, chips, outcome icons, and composer stay visible; only the result scrolls
- [ ] Copy: icon morphs to a green check, then the panel closes after ~1.4s
- [ ] Result with a diff, and result long enough to scroll
- [ ] Error, with Retry visible
- [ ] Error from an unknown model, with Retry **and** Connect to model
- [ ] Provider setup (no model configured)
- [ ] Close disc on the leading edge; gear (no “Settings” label) opens Settings
- [ ] Close disc and composer sit 10pt in from the window on every side; idle tabs have no gray fill; selected tab is accent
- [ ] Open the panel and switch Search ↔ Enhance: inset does not collapse then snap; composer never crops
- [ ] In Cursor with a selection: no character count under the chips; “Using N prior turns” appears only when session context applies, and clicking it clears the thread
- [ ] Replace: footer shows “Replaced in [app]” for ~0.8s, then the panel closes and the host text updates; a second click during the toast does nothing; Escape during the toast still writes
- [ ] Select text on a webpage and invoke: **Enhance Prompt** is selected and already visible in the chip row (no horizontal swipe)
- [ ] Each answered turn shows copy / regenerate / like / dislike / pin icons; votes persist for the session and log as training signal; pin flashes a check without dismissing
- [ ] AI Search regenerate rewrites only the latest answer; earlier turns stay
- [ ] AI Search answers use `##` headings and body that read as distinct (size, weight, spacing)
- [ ] AI Search has no footer — turns own every outcome; turn copy never dismisses (close disc / Escape close instead); switching to Enhance Prompt brings the icon row and the token chip back without jumping height
- [ ] Outcome row lives only on Enhance and the verb tabs: Replace keeps icon + label in the same muted color as copy (no accent fill); then copy / retry / like / dislike / pin plus token pill. Composer has no regenerate — retry is on this row only. Grammar and Reply rows own all six each, and their tabs have no footer; row votes teach that row's tone/kind even when another is selected
- [ ] Composer well sits in the slab (quiet wash, not a bright card); Reduce Transparency still opaque
- [ ] Enhance + Cursor on a short UI ask: result restates the asks as a short work order — no locate-the-file steps and no invented “confirm after these changes” checklist

## Get Started

Reset by clearing `hasCompletedGetStarted` (or a fresh install):

- [ ] Three steps only: Welcome → Allow Accessibility → Start Beru. No microphone page
- [ ] After Start Beru, first mic click (or ⌃⌥⌘L) shows the system Microphone prompt; Allow starts listening. Settings → Permissions is not opened first

## Liquid Glass

- [ ] Panel over a light document and a dark window: floating HUD glass (refraction, not a black fill); host does not show through as holes between modules
- [ ] Composer field is a quiet well on the glass (not a bright card); Reduce Transparency: opaque well, type still readable
- [ ] Selected tab is a solid accent fill; idle tabs are outlined with primary type (no gray fill)
- [ ] Result markdown and diffs stay readable on both hosts
- [ ] Reduce Transparency on: panel becomes opaque canvas without relaunching
- [ ] Reduce Transparency off: glass returns
- [ ] Increase Contrast on: composer well, settings cards, and hairlines stay distinct on the glass without relaunching
- [ ] System Settings Liquid Glass intensity: panel and Settings follow without relaunching; no second glass lens on the composer, toast, or chips
- [ ] Composer Target and Provider menus keep their icons (they name an object). Reply tone, Delete, and action menus stay text + checkmark
- [ ] Settings uses the same refractive slab as the panel (not a grey card, not a blur of the host); General → About twice with no stacked pages
- [ ] Clicking panel chips, footer icons, Replace, or Send does not bounce the window
- [ ] Hovering Replace / Copy / Pin shows the helper pill above the control, fully visible (not cropped by the composer)
- [ ] Window close traffic light has no square fill; shortcut recorder × has no dark bezel
- [ ] Menu bar extra keeps the original row layout on system chrome; Enhance Clipboard is a solid accent CTA (no gradient) with the shortcut chip; Dictate, Vault, Settings, and Quit are outlined Haze pills; provider options use solid accent when selected; ready state is name + green dot only (no “Ready to refine…”); blocked states still say Needs Accessibility / Set up a provider

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

- [ ] Each list is a source list: click and arrow keys select; the row paints a Haze accent wash with primary text (not the system blue highlight, not a solid inverted pill). Sidebar nav uses a solid accent pill with inverted text; Lucide tiles stay colored squircles
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

- [ ] Installed Ollama models list with sizes; Use points both roles at one model (no per-role split, no weight-swap stall)
- [ ] A weak model (vision, ≤3B, embedding/speech) serving a role shows the banner with a working "Use X for Both"
- [ ] Typing any installed id into the Local model field works; Ollama stopped shows the start-server row
- [ ] API preset + key in Models (or `BERU_API_KEY` when launched from a terminal): Test connection succeeds; panel provider picker enables API

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
- [ ] Menu bar mark is the SVG ant at 22.5pt, black in Light and white in Dark, switching appearance without relaunching. Dock, About, Get Started, and the menu extra header show the same color mark (not the old winged bee). Spotlight / Dock may cache the old icon until Beru is reinstalled or the icon cache is cleared.

## Smart Reply

Highlight a message in another app, invoke, then tap **Smart Reply**:

- [ ] Funny and Witty mention a concrete detail from the selected message; Formal stays non-jokey
- [ ] Tone pill jumps the highlight; clicking a card does the same; neither re-runs the model
- [ ] Copy / Insert send only the selected card, not the tagged blob; every card owns Insert first (icon + label in the same muted color as copy), then copy / regenerate / like / dislike / pin on its own row, left-aligned; no footer on the tab
- [ ] After Smart Reply, Enhance in the same app must not see `<reply` tags in prior-turn context
- [ ] Grammar Corrected that paraphrases (synonym swaps) rechecks once, then keeps the original rather than replacing it
- [ ] Summarize / Explain / Instruction: if the result is the source unchanged, the panel shows Retry — not a success
- [ ] Hotkey with a comment selected in Chrome/Safari opens **Smart Reply** automatically
- [ ] Roman Hinglish comment → all six replies stay in Roman/Latin (not Devanagari or German)
- [ ] No selection on Grammar: idle says “Type or paste text”; composer matches; not “ask instead”. Type a sentence, Return → Grammar result; no character count under the chips; composer is empty optional extras
- [ ] With a selection, Grammar still auto-runs; composer stays optional extras; Replace unchanged
- [ ] Type on Search with no selection, then click Enhance: Enhance runs on that text without a second Return
- [ ] Grammar shows Corrected / Clearer / Tighter as borderless rows like Smart Reply; selected row has the accent wash and edge; every row owns Replace first (icon + label in the same muted color as copy), then copy / regenerate / like / dislike / pin, left-aligned; clicking a row selects it without re-running; row Replace sends that row's body; no footer and no token savings pill
- [ ] Switching tabs slides the accent highlight between chips with no bounce; type cross-fades in place; close disc and composer move with the window immediately

## Before release only

- [ ] `./scripts/qa.sh` green
- [ ] Version bumped in `project.yml` (only when explicitly releasing)
