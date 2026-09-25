<p align="center">
  <img src="beru-github-banner.png" alt="Enhancify - turn a rough idea into a prompt your LLM will follow" width="100%">
</p>

# Enhancify

Select a rough idea, press a hotkey, and Enhancify turns it into a prompt your LLM will actually follow, aimed at Cursor, Claude, Codex, Gemini, ChatGPT, and the rest.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

Enhancify lives in the menu bar. It does not take over the app you are writing in. Every surface is native **Liquid Glass**: the panel floats as one refractive slab, the composer is a real glass field, the menu-bar extra sits on system glass, and Settings is a glass window with an accent-tinted sidebar. No custom frosted cards, no painted-over blur.

## How it works

1. Select the rough thought, notes, or half-written prompt, in Notes, Cursor, a browser, anywhere.
2. Press **⌃⌥⌘P** (you can change this).
3. Pick a chip. **Enhance Prompt** rewrites it as a clear prompt for that tool. **⌘↩ Replace** writes it back. **Copy** takes it to the clipboard.

Press **Tab** in the panel to flip between **Enhance Prompt** and **Grammar** on the same selection.

Grammar has a style row: **Proofread** (the classic copy edit), **Shorten**, **To English** (Hinglish, Hindi, or any language into natural English), and **Humanize** (strips the AI-sounding filler from pasted ChatGPT text). **More ▾** adds tones (Formal, Friendly, Confident, LinkedIn post) and some just-for-fun rewrites (Gen Z, Shakespearean, Pirate, Stand-up comedian, News anchor, Bollywood dialogue, Emoji madness). Picking a style re-runs on the same text; **⌘↩ Replace** writes it back.

By default the panel is focused: just Enhance Prompt and Grammar. Enhancify picks one from where you pressed the shortcut — Enhance in Cursor, Claude, ChatGPT and other AI tools, Grammar in text fields and chat or mail apps. With a selection there is no text box: the result is the panel. Start typing, press **⌘L**, or click Refine to add a note ("shorter", "mention the tests") and Return regenerates with it. With nothing selected, the text box is where you type or dictate the rough idea. Settings → General → **Show all actions** brings back AI Search, Smart Reply, Summarize, Explain, and custom actions.

Too lazy to type? Press **⌃⌥⌘L**. Enhancify opens, listens on this Mac, and writes down what you say. Speak the rough idea; Enhance still turns it into a prompt. Press the shortcut again, or the mic, to stop. Audio is transcribed on-device and never leaves the machine.

Pick the target (Cursor, Claude, ChatGPT, …) so the prompt matches how that model wants to be asked. Add Codex, Gemini, or your own in Settings → Targets.

With no selection, the panel opens on **AI Search**. Type a one-off ask into the composer and an **Instruction** chip appears for that run. Ask a follow-up on Search and answers stack until you close the panel.

On Search the result footer is **Copy** and **Pin** — no Replace, no token chip. Smart Reply keeps **Insert** but also hides the token chip (an answer, not a tighter prompt). Grammar hides it too (a copy-edit, not a cheaper prompt). On Enhance Prompt, Summarize, Explain, and Instruction it is **⌘↩ Replace**, **Copy**, **Pin**, and the token chip. A bare Return never overwrites the host selection. Enhance a vault note and **Apply** writes back into that note.

Confirmations ("Replaced in …", "Pinned") float over the composer and never move the layout.

## Pick a model that can do the job

Enhancify's prompts are demanding instruction sets — tagged multi-output formats, layered constraints, strict output shapes. A vision or embedding model will give weak replies, ignore bans, and echo prompt vocabulary. **Use a text instruct model.**

Settings → Models warns you when Enhance or Grammar runs on a vision, embedding, speech, or filter model, and offers a one-tap switch to the first installed text model. Good local choices:

| Model | Size | Note |
|---|---|---|
| **Qwen 2.5 3B** | ~2 GB | Default on Macs with less than 24 GB of memory. |
| **Qwen 2.5 7B** | ~4.7 GB | Default on 24 GB+. No reasoning pass; faster first token. |
| **Qwen 3 8B** | ~5 GB | Strongest local pick. Reasoning suppressed automatically. |
| **Gemma 3 1B** | ~815 MB | Lightweight. Works, but expect simpler output. |

A loaded model shares memory with every other app. On a 16 GB Mac a 7B model next to an editor and a browser can push macOS into swap and stall the machine, so Settings → Models warns when the model is heavy for this Mac. Enhancify only loads the model when you press the shortcut (not at login) and lets Ollama unload it after 5 idle minutes. On 8 GB Macs, use Apple on-device or an API model.

Cloud providers (Groq, Anthropic, …) sidestep this entirely — any current chat model follows the formats.

## Install

macOS 26+ only.

### Download (recommended)

1. Download the latest **Enhancify-<version>.dmg** from [Releases](https://github.com/rahulsharmadesign/beru/releases). Only the latest release is kept; older versions and their downloads are removed.
2. Open the DMG and drag **Enhancify** (the file is still named `Beru.app`) into **Applications**.
3. macOS will block it (unsigned). Allow it once:

```bash
xattr -cr /Applications/Beru.app
```

4. Open Enhancify from Applications.

No Xcode, Homebrew, or Apple Developer account. Dependencies are inside the app.

No Terminal? Control-click Enhancify → **Open**.

> **Formerly Beru.** The app was renamed to Enhancify. Behind the scenes it keeps the old bundle id (`com.rahul.beru`), file name (`Beru.app`), Keychain entries and `Application Support/Beru/` folder, so existing installs keep their settings, API keys, vault, Accessibility grant, and in-app updates.

**Optional:** if you use the **Ollama** provider, install [Ollama](https://ollama.com) separately and pull a model (see above for which). Cloud providers (Groq, Anthropic, etc.) only need an API key in Settings.

### Build from source (developers)

```bash
xcode-select --install          # skip if Xcode tools are already installed
brew install xcodegen
git clone https://github.com/rahulsharmadesign/beru.git
cd beru
./scripts/make-signing-cert.sh  # once
./scripts/install.sh
```

That builds Enhancify, signs it on *your* Mac, installs it to `/Applications`, and launches it. The certificate script is one-time. After that, `./scripts/install.sh` is enough.

To publish a DMG, push a version tag (`v1.1.0`). GitHub Actions builds it. Locally: `./scripts/make-dmg.sh`.

## First run (Get Started)

Three steps only. There is no microphone page.

1. **Welcome** — Enhancify lives in the menu bar. Select text, press the shortcut, improve it in place.
2. **Allow Accessibility** — required to read and replace the selection. **Open System Settings** if the grant is not there yet, then Continue.
3. **Start Enhancify** — press the shortcut (default **⌃⌥⌘P**). The welcome window closes and the panel opens.

Then open **Settings** from the menu bar and choose a provider (Ollama with a pulled model, or a cloud key). Enhance and Grammar need that before they can run.

Microphone and Speech Recognition are optional. The system prompt appears the first time you press the mic or **⌃⌥⌘L**, not during Get Started. Speech is recognized on this Mac.

**Reduce Transparency** (System Settings → Accessibility → Display) swaps every glass surface for an opaque card without relaunching.

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

Click the Enhancify extra:

- **Enhance Clipboard** — runs the default action on clipboard text; empty clipboard opens Search.
- **Dictate** — opens Search and starts listening (**⌃⌥⌘L**).
- **Vault** — opens Settings on Vault.
- Provider switch — only configured providers.
- **Settings** — the dashboard below.

## Settings

Open from the panel gear or the menu bar. Sidebar, top to bottom:

### General

Name (greetings on this Mac only), accent color, **Open Enhancify** and **Dictate** shortcuts, launch at login, default action, **Explain what changed**, and **Remember recent turns**.

### Models

Active provider (Ollama, Anthropic, or a custom `/v1` host such as Groq), base URL, API key, Enhance and Grammar model ids, and **Test connection**. A fit warning appears if a role runs on a vision, embedding, speech, or filter model, with a one-tap switch to a text model. Pull a local model here; the download continues if you leave the page.

### Permissions

Accessibility (required for capture and Replace) and Dictation (on-device speech). Granted / Needed badges; Grant opens System Settings. No Keychain prompt just from visiting this page.

### Data

Token savings from accepted results. **Record usage** is off until you turn it on — then input and results stay in `~/Library/Application Support/Beru/`. Retention, Reveal in Finder, export JSONL/CSV, clear history. API keys are never recorded.

### Vault

Local markdown notes and pins. Notes is a list plus editor; Pins is a list plus inspector. Pin a result or a link (`example.com` is fine; `javascript:` and `file:` are not). **Enhance this note** opens the panel; **Apply** writes the result back into that note. Export/import a zip. Point the folder at iCloud or Dropbox if you want the files to sync — Enhancify does not host them.

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

- Settings, actions, targets, vault notes, and run history are stored locally. Nothing is uploaded to a Enhancify server, there isn’t one.
- No analytics, telemetry, or crash reporting.
- API keys live in the Keychain on this Mac.
- Selected text goes only to the LLM provider you configure.
- Run history is off until you turn it on, then it lives in `~/Library/Application Support/Beru/`.
- Enhancify is not sandboxed. Accessibility cannot work inside the App Sandbox.

Cloud sync for settings and runs is a later idea, not in this build.

Details: [SECURITY.md](SECURITY.md).

## Support

If Enhancify saves you time: [send a tip](https://razorpay.me/@rahulsharmadesign).

Bugs and ideas: [open an issue](https://github.com/rahulsharmadesign/beru/issues). Security problems: [private advisory](https://github.com/rahulsharmadesign/beru/security/advisories/new), not a public issue.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).

```bash
brew install xcodegen
./scripts/make-signing-cert.sh
./scripts/install.sh
./scripts/qa.sh
```

The QA gate (`./scripts/qa.sh`) is the definition of done: static guards, codegen, build, tests, then a manual checklist.

## License

[MIT](LICENSE) © 2026 Rahul Sharma
