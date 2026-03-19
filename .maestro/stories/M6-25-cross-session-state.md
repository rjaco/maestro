---
id: M6-25
slug: cross-session-state
title: "Cross-session state persistence — survive unexpected termination"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced state management to survive unexpected termination:
   - **Atomic writes**: State file updates use write-to-temp-then-rename pattern
   - **Backup**: Keep .maestro/state.local.md.bak as previous state
   - **Recovery**: On session start, if state file is corrupted, restore from backup
   - **Checksum**: Store SHA-256 of state file, verify on read
2. Enhanced `hooks/session-start-hook.sh`:
   - Check for state file corruption on session start
   - If corrupted, attempt restore from .bak
   - If both corrupted, reset to safe defaults
3. Enhanced `skills/checkpoint/SKILL.md`:
   - Named checkpoints include state file snapshot
   - Restore includes state recovery
4. State file integrity logged in `.maestro/logs/state-integrity.md`
5. Mirror: changes in both root and plugins/maestro/

## Context for Implementer

The current state management writes directly to .maestro/state.local.md. If the process crashes mid-write, the file can be corrupted (partial write, truncated YAML).

Fix with atomic writes pattern:
```bash
# Instead of: sed -i 's/...' state.local.md
# Do:
tmp=$(mktemp)
cp state.local.md "$tmp"
sed 's/...' "$tmp" > state.local.md.new
mv state.local.md state.local.md.bak
mv state.local.md.new state.local.md
```

For the session-start-hook, add a corruption check:
```bash
# Verify YAML frontmatter is valid (has opening and closing ---)
if ! grep -q '^---$' .maestro/state.local.md; then
  echo "[MAESTRO] State file corrupted, restoring from backup" >&2
  cp .maestro/state.local.md.bak .maestro/state.local.md
fi
```

Reference: hooks/session-start-hook.sh (current)
Reference: skills/checkpoint/SKILL.md (current)
Reference: scripts/opus-daemon.sh for state reading patterns
