## Summary

-

## Blast radius

Which screens or flows can this break?

-

## Test plan

- [ ] `./scripts/qa.sh` green
- [ ] Manual pass on the [checklist](../docs/QA-CHECKLIST.md) sections that match the blast radius
- [ ] If a guard baseline moved, `scripts/qa-baseline.txt` is committed with lower numbers
- [ ] If this touches capture, replace, Keychain, or provider URLs: read [SECURITY.md](../SECURITY.md)
