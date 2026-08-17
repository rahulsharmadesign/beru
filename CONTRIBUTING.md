# Contributing

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities via [SECURITY.md](SECURITY.md), not public issues.

## Development

```bash
brew install xcodegen
./scripts/make-signing-cert.sh
./scripts/install.sh
```

`scripts/install.sh` signs with a stable local certificate so macOS does not revoke Accessibility on every rebuild. Do not copy an ad-hoc build into `/Applications` and expect the grant to persist.

```bash
xcodegen generate
xcodebuild -scheme Beru -destination 'platform=macOS' test
```

## Pull requests

1. Fork and branch from `ship`.
2. Keep the change scoped. Capture, keystroke simulation, Keychain, and provider URL handling need extra care — see [SECURITY.md](SECURITY.md).
3. Run the test command above.
4. Do not commit secrets, signing certificates, or `.env` files.

## Product constraints

- Swift and SwiftUI only. AppKit only for `NSPanel` and `NSStatusItem`.
- No analytics, telemetry, or crash reporting.
- API keys only in Keychain.
- No network calls except to the configured provider endpoint.
