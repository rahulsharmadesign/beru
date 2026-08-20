# Contributing

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities via [SECURITY.md](SECURITY.md), not public issues.

## Development

```bash
brew install xcodegen
./scripts/make-signing-cert.sh
./scripts/install.sh
```

`scripts/install.sh` signs with a stable local certificate so macOS does not revoke Accessibility on every rebuild. Do not copy an ad-hoc build into `/Applications` and expect the grant to persist.

## QA

```bash
./scripts/qa.sh
```

One gate for everything: static guards, `xcodegen generate`, build, tests, then it prints [docs/QA-CHECKLIST.md](docs/QA-CHECKLIST.md) for the manual pass. Use `--static` for guards only or `--fast` to skip tests.

The guards are a ratchet against `scripts/qa-baseline.txt`. A count going up fails the gate, so new raw color literals, off-grid spacing, oversized files, or extra singletons are blocked. When you remove debt on purpose, run `./scripts/qa.sh --update-baseline` and commit the lower numbers alongside the change. Never raise a baseline to get green.

## Pull requests

1. Fork and branch from `main`.
2. Keep the change scoped. Capture, keystroke simulation, Keychain, and provider URL handling need extra care — see [SECURITY.md](SECURITY.md).
3. Run `./scripts/qa.sh` and work the manual checklist section that matches your change.
4. Do not commit secrets, signing certificates, or `.env` files.

## Product constraints

- Swift and SwiftUI only. AppKit only for `NSPanel` and `NSStatusItem`.
- No analytics, telemetry, or crash reporting.
- API keys only in Keychain.
- No network calls except to the configured provider endpoint.
