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
- [ ] Loading / streaming
- [ ] Result with a diff, and result long enough to scroll
- [ ] Error, with Retry visible
- [ ] Error from an unknown model, with Retry **and** Connect to model
- [ ] Provider setup (no model configured)
- [ ] Switch action tabs repeatedly: only the tab pill animates, not the whole panel

## Settings routes

Open Settings and visit every sidebar route twice, in this order:

- [ ] General, Models, Actions, Targets, Vault, Runs, Data, Permissions, About
- [ ] No "Beru wants to use your confidential information" prompt at any point
- [ ] No beachball or lag when landing on Models
- [ ] Resize the window narrow: rows reflow without jumping or clipping
- [ ] Light mode and dark mode

## Models

- [ ] Install a model, then navigate away from Models: download continues
- [ ] Sidebar shows the download badge while it runs
- [ ] Return to Models: progress is still accurate, Cancel works
- [ ] Installed model appears in the Enhance and Grammar pickers

## Session context (when touched)

- [ ] Enhance twice in the same app: the second result builds on the first
- [ ] Indicator chip shows the turn count and clears on demand
- [ ] Switch to a different app: chip resets
- [ ] Toggle the setting off: no context is used

## Accent and appearance

- [ ] Change the accent color: panel and Settings both repaint immediately
- [ ] Switch system appearance while the panel is open: it follows

## Before release only

- [ ] `./scripts/qa.sh` green
- [ ] Version bumped in `project.yml` (only when explicitly releasing)
