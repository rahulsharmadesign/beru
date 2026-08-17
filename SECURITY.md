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

### Local history and vault

Usage recording is **off by default**. When enabled, full input and output are written to:

`~/Library/Application Support/Beru/history/` (directory `0700`, files `0600`)

The default vault lives at `~/Library/Application Support/Beru/vault/` with the same modes. A user-chosen sync folder (iCloud, Dropbox) keeps the cloud provider’s permissions on the folder itself; note files Beru writes are still `0600`.

### Secrets

API keys are stored in the Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. They are never written to logs, history files, or UserDefaults.

### Model output

Selected text is framed as content, not as instructions to execute. That is a mitigation, not a guarantee. Hostile text can still produce output that **Replace** pastes into the host app. Read the result before replacing.

### Unsigned downloads

`scripts/make-dmg.sh` signs with a local development certificate. Other Macs will treat that binary as unidentified. Do not distribute it as a public installer until it is notarized with an Apple Developer ID.
