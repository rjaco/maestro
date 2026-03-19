# QR-M4: Documentation & Mirror Sync

## Focus
Fix all documentation drift between root and plugins/maestro mirror. Ensure perfect sync.

## Stories

### S11: Full mirror sync of documentation files
- Sync CHANGELOG.md, FEATURES.md, README.md from root to plugins/maestro/
- Fix templates/state.md command hint mismatch (opus vs magnum-opus)
- Sync test-opus-daemon.sh to mirror
- Update FEATURES.md counts to match reality (138 skills, 43 commands)
- Acceptance: `diff -rq` between root and plugins/maestro shows zero differences for all synced files

### S12: Fix companion setup credential exposure
- Mask secret input in companion/scripts/setup.ts line 19
- Acceptance: Secret input is not displayed in plain text during setup
