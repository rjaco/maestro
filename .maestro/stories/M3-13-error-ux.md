---
id: M3-13
slug: error-ux
title: "Error UX improvements — actionable messages with suggested fixes"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. All 8 hook scripts enhanced with better error messages
2. Error format standardized across all scripts:
```
[MAESTRO ERROR] <what went wrong>
  → Cause: <why it happened>
  → Fix: <what to do about it>
  → Docs: <relevant skill or command>
```
3. Specific improvements in each hook:
   - `session-start-hook.sh`: Handle missing .maestro/ dir gracefully with init suggestion
   - `branch-guard.sh`: Explain WHY branch is protected and how to switch
   - `delegation-hook.sh`: Explain what delegation means and when it's OK to bypass
   - `opus-loop-hook.sh`: Handle missing state file, missing vision file
   - `stop-hook.sh`: Better explanation of why stop was intercepted
   - `stop-failure-hook.sh`: Actionable recovery steps
   - `post-compact-hook.sh`: Explain what compaction means and what was preserved
   - `notification-hook.sh`: Handle missing notification providers
4. All error messages use consistent styling (same prefix, same structure)
5. No changes to happy path behavior — only error paths improved

## Context for Implementer

Read all 8 hook scripts in `hooks/`. For each one, identify error conditions (if statements that echo errors or exit non-zero) and improve the messages.

Current error messages are often terse: "State file not found" or "Not on development branch." Make them actionable: tell the user what happened, why, and how to fix it.

Pattern to follow:
```bash
echo "[MAESTRO ERROR] State file not found at .maestro/state.local.md" >&2
echo "  → Cause: No active Maestro session in this project" >&2
echo "  → Fix: Run /maestro init to initialize, then /maestro \"your task\"" >&2
```

Also enhance scripts/ error messages where applicable:
- scripts/opus-daemon.sh
- scripts/self-test.sh

Mirror all changes to plugins/maestro/hooks/ and plugins/maestro/scripts/.

IMPORTANT: Work on the development branch. Do NOT commit.
