# Security

Beru reads selected text in other apps and can replace it. Treat it as a privileged utility.

## Report a vulnerability

Use [GitHub Security Advisories](https://github.com/rahulsharmadesign/beru/security/advisories/new). Do not open a public issue for a vulnerability.

This is the current public build. There is no older supported release line.

## Threat model

### Accessibility and input

Beru is **not sandboxed**. It uses the Accessibility API to read the current selection and, when that fails, simulates ⌘C / ⌘V. A compromised build can read and inject text in any app.

- Grant Accessibility only to a binary you built or that is signed with a Developer ID you trust.
- Review changes under `Sources/Capture/` and `Sources/Support/` carefully.
- Do not auto-replace model output into a terminal or password field without reading it.

### Data sent to providers

Selected text, instructions, and playbook context are sent to the LLM provider you configure (Ollama, Anthropic, Groq, OpenAI, or a custom URL). Beru does not add analytics or a proxy.

- Local Ollama keeps data on the machine.
- Cloud providers receive whatever you selected. Do not run Beru on secrets you would not paste into that provider.
- Custom base URLs must be `http://` or `https://`. `file:`, `unix:`, and other schemes are rejected.

### Session context

"Remember recent turns" (General settings, **on by default**) lets Enhance, Describe and Search build on earlier requests in the same app. The turns are held in memory only and are **never written to disk at any setting** — independent of usage recording below. They are keyed by the host app's bundle id and cleared when you click the chip, switch apps, or turn the setting off; the panel shows a "Using N prior turns" chip whenever they apply. They die with the process.

Because a turn's truncated input and output are re-sent as part of the next request's system prompt, a cloud provider sees them again on each follow-up in that app. Turn the setting off if that matters for what you are working on.

### Learned preferences

Insert, Replace, and Copy on this Mac update a small preference record in UserDefaults (last Smart Reply tone, last Grammar pick, last Enhance destination and instruction digest). It is **not** usage history: no full documents, no extra folder under Application Support. It is sent only as a short block inside the next Enhance or Smart Reply provider request. Clear it in Settings → General. Grammar's copy-edit prompt never receives it.

### Local history and vault

Usage recording is **off by default**. When enabled, full input and output are written to:

`~/Library/Application Support/Beru/history/` (directory `0700`, files `0600`)

The default vault lives at `~/Library/Application Support/Beru/vault/` with the same modes. A user-chosen sync folder (iCloud, Dropbox) keeps the cloud provider’s permissions on the folder itself; note files Beru writes are still `0600`.

### Secrets

API keys are stored in the Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. They are never written to logs, history files, or UserDefaults.

### Model output

Selected text is framed as content, not as instructions to execute. That is a mitigation, not a guarantee. Hostile text can still produce output that **Replace** pastes into the host app. Read the result before replacing.

### Unsigned downloads

Release DMGs are ad-hoc signed on purpose — no Apple Developer Program. macOS Gatekeeper will block the first launch. Recipients allow it with `xattr -cr /Applications/Beru.app`, or Control-click → Open. Treat a downloaded binary like any other unsigned tool: only install from a source you trust.

### In-app updates

The About pane can download and install a new build. That code path replaces the running application bundle unattended, so it is the most dangerous component in the product and is treated as such.

What it does:

- **Source is pinned.** Only the project's own GitHub Releases host is accepted (`AppUpdateFeed.isTrustedDownload`). A feed pointing elsewhere is refused before anything is downloaded.
- **The payload is verified before the installed app is touched.** The mounted bundle must pass `codesign --verify --deep --strict`, its `CFBundleIdentifier` must match the running app, and — when the running app has a leaf certificate — the download's signing authority must match it. A build that fails any of these is discarded and the installed app is left alone.
- **The old bundle is moved aside, never deleted first.** An earlier version ran `rm -rf` on the installed app and then copied the replacement in. A failure between those two steps left the user with no application. The swap now stages the new bundle beside the destination, verifies the staged copy, moves the old one to a backup path, and swaps. Any error restores the backup.
- **The swap script is not at a predictable path.** It is written into a freshly created `0700` directory with a random name. A fixed path in the shared temporary directory could be pre-created or symlinked by another process running as the user, which would have had this script's privileges.
- **The wait for exit is bounded.** The script waits for the app's pid to disappear, but gives up after ~30s rather than looping forever if the pid is recycled.

What it does **not** protect against:

- **A compromised GitHub account or release.** Signature pinning ties the update to the same signing identity as the running app, but an ad-hoc signed build has no meaningful identity to pin. If you did not build Beru yourself, the update is only as trustworthy as the release it came from.
- **A local attacker who already runs code as you.** They do not need the updater; they can modify the app bundle directly. The hardening above narrows the updater as an *escalation* path, not as a defence against an already-compromised account.

If you would rather not use in-app updates at all, download DMGs manually and ignore the About pane's update button.
