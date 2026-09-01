<p align="center">
  <img src="beru-github-banner.png" alt="Beru - turn a rough idea into a prompt your LLM will follow" width="100%">
</p>

# Beru

Select a rough idea, press a hotkey, and Beru turns it into a prompt your LLM will actually follow, aimed at Cursor, Claude, Codex, Gemini, ChatGPT, and the rest.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

Beru lives in the menu bar. It does not take over the app you are writing in. On macOS 26 it floats as **Liquid Glass**: one HUD slab over the host app, not a frosted card and not a second window you live in. Settings uses the same system window material, with Vault, Actions, Targets, and Runs as native source lists.

## How it works

1. Select the rough thought, notes, or half-written prompt, in Notes, Cursor, a browser, anywhere.
2. Press **⌃⌥⌘P** (you can change this).
3. Pick a chip. **Enhance Prompt** rewrites it as a clear prompt for that tool. **⌘↩ Replace** writes it back. **Copy** takes it to the clipboard.

Too lazy to type? Press **⌃⌥⌘L**. Beru opens, listens on this Mac, and writes down what you say. Speak the rough idea; Enhance still turns it into a prompt. Press the shortcut again, or the mic, to stop. Audio is transcribed on-device and never leaves the machine.

Pick the target (Cursor, Claude, ChatGPT, …) so the prompt matches how that model wants to be asked. Add Codex, Gemini, or your own in Settings → Targets.

With no selection, the panel opens on **AI Search**. Type a one-off ask into the composer and an **Instruction** chip appears for that run. Ask a follow-up on Search and answers stack until you close the panel.

On Search the result footer is **Copy** and **Pin** — no Replace, no token chip. Smart Reply keeps **Insert** but also hides the token chip (an answer, not a tighter prompt). Grammar hides it too (a copy-edit, not a cheaper prompt). On Enhance Prompt, Summarize, Explain, and Instruction it is **⌘↩ Replace**, **Copy**, **Pin**, and the token chip. A bare Return never overwrites the host selection. Enhance a vault note and **Apply** writes back into that note.

## Install

macOS 26+ only.

### Download (recommended)

1. Download **Beru-1.1.12.dmg** from [Releases](https://github.com/rahulsharmadesign/beru/releases).
2. Open the DMG and drag **Beru** into **Applications**.
3. macOS will block it (unsigned). Allow it once:

```bash
xattr -cr /Applications/Beru.app
```

4. Open Beru from Applications.

No Xcode, Homebrew, or Apple Developer account. Dependencies are inside the app.

No Terminal? Control-click Beru → **Open**.

**Optional:** if you use the **Ollama** provider, install [Ollama](https://ollama.com) separately and pull a model. Cloud providers (Groq, Anthropic, etc.) only need an API key in Settings.

### Build from source (developers)

```bash
xcode-select --install          # skip if Xcode tools are already installed
brew install xcodegen
git clone https://github.com/rahulsharmadesign/beru.git
cd beru
./scripts/make-signing-cert.sh  # once
./scripts/install.sh
```

That builds Beru, signs it on *your* Mac, installs it to `/Applications`, and launches it. The certificate script is one-time. After that, `./scripts/install.sh` is enough.

To publish a DMG, push a version tag (`v1.1.0`). GitHub Actions builds it. Locally: `./scripts/make-dmg.sh`.

## First run (Get Started)

Three steps only. There is no microphone page.

1. **Welcome** — Beru lives in the menu bar. Select text, press the shortcut, improve it in place.
2. **Allow Accessibility** — required to read and replace the selection. **Open System Settings** if the grant is not there yet, then Continue.
3. **Start Beru** — press the shortcut (default **⌃⌥⌘P**). The welcome window closes and the panel opens.

Then open **Settings** from the menu bar and choose a provider (Ollama with a pulled model, or a cloud key). Enhance and Grammar need that before they can run.

Microphone and Speech Recognition are optional. The system prompt appears the first time you press the mic or **⌃⌥⌘L**, not during Get Started. Speech is recognized on this Mac.

**Reduce Transparency** (System Settings → Accessibility → Display) swaps the glass panel for an opaque card without relaunching.

## Providers

| Provider | Best for | What you need |
|---|---|---|
| **Ollama** | Everything stays on this Mac | [Ollama](https://ollama.com) and a pulled model |
| **Groq** | Fast and free to start | API key from [console.groq.com](https://console.groq.com) |
| **Anthropic** | Claude quality | API key from [console.anthropic.com](https://console.anthropic.com) |
| **Custom** | OpenAI, OpenRouter, LM Studio, anything `/v1` | Base URL, model id, key if the host wants one |

## Panel chips

Always on the left: **AI Search**. Then **Enhance Prompt** and **Grammar**. New installs also get **Smart Reply**, **Summarize**, and **Explain**. Your own chips from Settings → Actions sit in the same row. **Instruction** appears only while a one-off ask is in the composer.

| Chip | What it does |
|---|---|
| **AI Search** | Ask without rewriting the selection. Follow-ups stack until the panel closes. Regenerating rewrites only the latest answer. Footer is Copy and Pin — no Replace, no token chip. |
| **Enhance Prompt** | Turn a rough idea into a prompt aimed at the current target (Cursor, Claude, ChatGPT, …). |
| **Grammar** | Copy-edit. Meaning and tone stay. Shown as a word diff when enough of the original survived. |
| **Smart Reply** | Six tones (Formal, Casual, Funny, Professional, Witty, Sharp). Pick a card, then Insert or Copy that body only. Matches the script of the incoming message. |
| **Summarize** | Compress the selection. |
| **Explain** | Make the selection clear. |
| **Instruction** | Run whatever you typed in the composer against the current selection or question. Not a saved action. |
| **Custom** | Any verb you add under Settings → Actions — a workplace voice, a house style, a one-line rewrite. Built-in Enhance Prompt and Grammar cannot be overridden by a saved prompt that would make the chip a lie. |

**Remember recent turns** (on by default): Enhance Prompt, Instruction, and Search can see earlier requests in the same app until you click the chip, switch apps, or turn the setting off. The panel shows **Using N prior turns**. Grammar and Smart Reply never see that history. Turns live in memory only.

## Menu bar

Click the Beru extra:

- **Enhance Clipboard** — runs the default action on clipboard text; empty clipboard opens Search.
- **Dictate** — opens Search and starts listening (**⌃⌥⌘L**).
- **Vault** — opens Settings on Vault.
- Provider switch — only configured providers.
- **Settings** — the dashboard below.

## Settings

Open from the panel gear or the menu bar. Sidebar, top to bottom:

### General

Name (greetings on this Mac only), accent color, **Open Beru** and **Dictate** shortcuts, launch at login, default action, **Explain what changed**, and **Remember recent turns**.

### Models

Active provider (Ollama, Anthropic, or a custom `/v1` host such as Groq), base URL, API key, Enhance and Grammar model ids, and **Test connection**. Pull a local model here; the download continues if you leave the page.

### Permissions

Accessibility (required for capture and Replace) and Dictation (on-device speech). Granted / Needed badges; Grant opens System Settings. No Keychain prompt just from visiting this page.

### Data

Token savings from accepted results. **Record usage** is off until you turn it on — then input and results stay in `~/Library/Application Support/Beru/`. Retention, Reveal in Finder, export JSONL/CSV, clear history. API keys are never recorded.

### Vault

Local markdown notes and pins. Notes is a list plus editor; Pins is a list plus inspector. Pin a result or a link (`example.com` is fine; `javascript:` and `file:` are not). **Enhance this note** opens the panel; **Apply** writes the result back into that note. Export/import a zip. Point the folder at iCloud or Dropbox if you want the files to sync — Beru does not host them.

### Runs

Every recorded invocation (only if Data → Record usage is on), grouped by day. Open a run to see the diff and rationale. **Enhance again**, **Pin**, or **Save as note**.

### Actions

Verb chips in the panel. Search, reorder (drag when search is empty), +/− at the bottom of the list. Built-ins keep their prompt; custom actions have Name, Icon, Kind, and Prompt. Import and export from More.

### Targets

Where an enhanced prompt is going. Cursor, ChatGPT, Claude, and Kimi ship as starters; add Codex, Gemini, or your own. Each target has conventions so Enhance Prompt speaks that dialect.

### About

Version and build, MIT license, privacy note, GitHub, issues, tip jar, and **Check for Updates** against GitHub Releases. If a newer DMG is there, Install appears on About and a download icon sits beside About in the sidebar. Local `install.sh` builds explain that they do not replace themselves with a release.

## What’s next

- **Meeting Notes** — a dedicated workspace for capturing and shaping notes from a meeting. Not in this build; it is the next surface after this freeze.
- **Windows** is in progress. macOS is the supported build today.
- **Cloud storage** for settings and runs is on the list, so the same setup could follow you across machines. Local-only remains the default.

## Feature requests

Have an idea? [Open a feature request](https://github.com/rahulsharmadesign/beru/issues/new?template=feature.yml). Check [existing issues](https://github.com/rahulsharmadesign/beru/issues) first so we don’t double up.

## Privacy

Everything stays on this Mac.

- Settings, actions, targets, vault notes, and run history are stored locally. Nothing is uploaded to a Beru server, there isn’t one.
- No analytics, telemetry, or crash reporting.
- API keys live in the Keychain on this Mac.
- Selected text goes only to the LLM provider you configure.
- Run history is off until you turn it on, then it lives in `~/Library/Application Support/Beru/`.
- Beru is not sandboxed. Accessibility cannot work inside the App Sandbox.

Cloud sync for settings and runs is a later idea, not in this build.

Details: [SECURITY.md](SECURITY.md).

## Support

If Beru saves you time: [send a tip](https://razorpay.me/@rahulsharmadesign).

Bugs and ideas: [open an issue](https://github.com/rahulsharmadesign/beru/issues). Security problems: [private advisory](https://github.com/rahulsharmadesign/beru/security/advisories/new), not a public issue.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).

```bash
brew install xcodegen
./scripts/make-signing-cert.sh
./scripts/install.sh
./scripts/qa.sh
```

## License

[MIT](LICENSE) © 2026 Rahul Sharma
