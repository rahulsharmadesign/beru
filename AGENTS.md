# Working on Beru

Beru is a macOS menu bar app: SwiftUI, XcodeGen (`project.yml` is the source of
truth, `Beru.xcodeproj` is generated and gitignored), no Package.swift.

## Before you call anything done

```bash
./scripts/qa.sh
```

Static guards, then `xcodegen generate`, build, tests, then it prints the manual
checklist. `--static` for guards only, `--fast` to skip tests.

The guards are a ratchet against `scripts/qa-baseline.txt`: a count going up
fails the gate. When you deliberately remove debt, run
`./scripts/qa.sh --update-baseline` and commit the lower numbers with the change.
Never raise a baseline to get green.

## Conventions

Detailed rules live in `.cursor/rules/` and apply to every agent:

- `beru-qa-gate.mdc` — the gate, one change per pass, what not to do unprompted
- `beru-design-tokens.mdc` — everything visual comes from `Sources/Design`
- `beru-architecture.mdc` — folder boundaries, observation, state ownership

Also read `CONTRIBUTING.md` for branch and dev-install workflow, and
`SECURITY.md` before touching capture, keystroke simulation, Keychain, or
provider URLs.

## Development install

```bash
./scripts/make-signing-cert.sh   # once
./scripts/install.sh             # build, sign, install to /Applications, launch
```

Sign with the stable local cert. Ad-hoc copies to `/Applications` reset the
Accessibility permission on every rebuild.
