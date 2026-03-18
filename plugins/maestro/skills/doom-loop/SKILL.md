---
name: doom-loop
description: "Detect and interrupt agent doom-loops — repeated identical tool calls, oscillation, expanding retries, and unresolved NEEDS_CONTEXT chains. Triggers progressive intervention to restore forward progress."
---

# Doom-Loop Detection

Identifies and breaks the failure mode where agents make repeated identical calls without making progress. Based on the OpenDev (2026) paper's taxonomy of agent stall patterns.

## Doom-Loop Patterns

### Pattern 1: Exact Repeat

The same tool is called with identical arguments 3 or more times in sequence.

```
Edit("skills/auth/SKILL.md", old_string="## Auth")
Edit("skills/auth/SKILL.md", old_string="## Auth")   ← repeat
Edit("skills/auth/SKILL.md", old_string="## Auth")   ← doom-loop
```

**Common cause:** `old_string` not found in file. The edit silently fails and the agent retries with no new information.

### Pattern 2: Oscillation

The agent alternates between 2-3 distinct actions without net progress.

```
Read("src/index.ts") → Edit("src/index.ts") → Read("src/index.ts") → Edit("src/index.ts") → ...
```

Detected when the sliding window contains alternating call signatures with no net state change (same file content after read/edit pairs, or same error after repeated fix attempts).

### Pattern 3: Expanding Retry

The same logical action is retried with slightly different arguments, but each attempt produces the same error result.

```
Bash("npm install lodash")    → error: permission denied
Bash("npm install -g lodash") → error: permission denied
Bash("sudo npm install")      → error: permission denied
```

Detected when: same tool, varying arguments, identical error output across 3+ calls.

### Pattern 4: Context Chase

The agent escalates NEEDS_CONTEXT 3 or more times in succession without resolving the underlying gap.

```
Agent → NEEDS_CONTEXT: "need schema"
Dispatch with schema → NEEDS_CONTEXT: "need auth types"
Dispatch with auth types → NEEDS_CONTEXT: "need test fixtures"
```

Signals that the story spec is fundamentally underspecified, not that context is merely missing.

## Detection Mechanism

Maintain a sliding window of the last 10 tool calls. After each call:

1. Compute the **call signature**: `tool_name + JSON.stringify(key_args)` where key args are the first 2-3 parameters (file path, old_string, command — not full content).
2. Scan the window for pattern matches:
   - **Exact repeat**: 3+ consecutive identical signatures
   - **Oscillation**: A-B-A-B or A-B-C-A-B-C cycle within the window
   - **Expanding retry**: 3+ calls to same tool with different args but same error substring
   - **Context chase**: 3+ NEEDS_CONTEXT statuses with different stated needs
3. On pattern match: increment `doom_loop.count` in state.
4. At threshold: trigger the intervention for the current level.

## Progressive Intervention

### Level 1 — Warning (count = 3)

Log a warning and inject a system reminder into the agent's next prompt:

```
[DOOM-LOOP WARNING]
You appear to be repeating the same action without progress.
Pattern detected: exact-repeat
Action: Edit skills/auth/SKILL.md (same old_string 3 times)
Consider a different approach before retrying.
```

The agent should re-read the file, verify the target string exists, then retry with the correct content.

### Level 2 — Model Escalation (count = 5)

Force model escalation via the delegation skill:

- `haiku` → `sonnet`
- `sonnet` → `opus`
- `opus` → PAUSE (already at ceiling)

Re-dispatch the agent at the higher model tier with the same context package plus the doom-loop warning. The stronger model is more likely to recognize the failure and change strategy.

### Level 3 — Halt and Report (count = 8)

Stop execution, save state, and present a diagnostic to the user:

```
Doom-loop detected in Story 03.
Pattern:    exact-repeat
Action:     Edit skills/auth/SKILL.md (same old_string 5 times)
Likely cause: old_string not found in file
Recommendation: Read the file first, then retry with correct content

Options:
  [1] I will fix this manually, then resume
  [2] Re-dispatch with a fresh context package
  [3] Skip this story
  [4] Abort execution
```

State is written to disk before displaying the halt message so the session is resumable.

## StopFailure Hook Integration

The `StopFailure` hook (Claude Code v2.1.78) fires when API errors occur. This is the missing fallback path for doom-loop detection — catching failures that happen outside the agent's normal tool call flow.

### Hook Behavior

When `StopFailure` fires during an active Maestro session:

1. Read `.maestro/state.local.md` to check if a session is active
2. Increment `doom_loop.count` by 2 (API failures are more serious than tool-level repeats)
3. Log the failure to `.maestro/logs/doom-loop.md`:
   ```
   [ISO timestamp] StopFailure during story [story_id]
   Error: [error type from hook input]
   Phase: [current phase from state]
   Action: Incremented doom_loop.count to [N]
   ```
4. If `doom_loop.count >= 8`: set `doom_loop.intervention_level: 3` (halt)
5. If `doom_loop.count >= 5`: set `doom_loop.intervention_level: 2` (escalate)

### Hook Script Reference

The `StopFailure` hook is registered in `hooks/hooks.json` and handled by `hooks/stop-failure-hook.sh`. The script:

```bash
# Input (JSON on stdin):
# { "error": "rate_limit|server_error|authentication_failed|...", "session_id": "..." }
#
# Actions:
# 1. Read .maestro/state.local.md
# 2. If active session: increment doom_loop.count, log failure
# 3. Output: { "systemMessage": "API failure detected. doom_loop.count=[N]" }
```

This ensures that even transient API failures are tracked as potential doom-loop indicators, preventing infinite retry loops when the API itself is the bottleneck.

## Integration Points

### dev-loop/SKILL.md

After each dispatch in Phase 3 (IMPLEMENT) and Phase 4 (SELF-HEAL), check the doom-loop window. On a `NEEDS_CONTEXT` response, increment `doom_loop.context_chase_count`; if it reaches 3, trigger Level 3 with pattern `context-chase`. The Phase 4 auto-fix cap of 3 and the doom-loop window are independent guards — both can fire.

### opus-loop/SKILL.md

When `doom_loop.level >= 2` during a story, increment `consecutive_failures` (same weight as a full story failure) and reset doom-loop state for the next story. The existing `consecutive_failures >= 5` safety valve in opus-loop then applies normally.

### delegation/SKILL.md

Level 2 intervention routes through delegation's existing model escalation: haiku → sonnet → opus. Log `"Model escalated due to doom-loop (level 2)"` alongside the normal escalation log so the delegation skill's token accounting captures it.

### retrospective/SKILL.md

Doom-loop occurrences map to existing friction signals:

- `exact-repeat` or `oscillation` on Edit calls → **REPETITION** signal → improvement candidate: add "Read before Edit" to implementer prompt
- `context-chase` 2+ times in a feature → **SKILL_SUPPLEMENT** signal → improvement candidate: update decompose template to require explicit file lists

## State Tracking

Store doom-loop state in `.maestro/state.local.md` under the `doom_loop:` key:

```yaml
doom_loop:
  pattern_type: exact-repeat       # exact-repeat | oscillation | expanding-retry | context-chase
  count: 4                         # current repeat count in sliding window
  last_action: "Edit skills/auth/SKILL.md old_string='## Auth'"
  intervention_level: 1            # 0 = none, 1 = warning, 2 = escalation, 3 = halt
  story: "03-auth-skill"           # which story triggered this
  window: []                       # last 10 call signatures (populated at runtime)
```

Reset `doom_loop.count` and `doom_loop.intervention_level` to 0 at the start of each new story. Preserve `pattern_type` and `last_action` for retrospective analysis.

## Common Causes and Fixes

| Pattern | Common Cause | Fix |
|---------|--------------|-----|
| Exact repeat on Edit | `old_string` not found in file | Read the file first. Verify the exact string exists before editing. |
| Exact repeat on Bash | Command fails silently, agent retries identically | Check exit code and stderr. If same error, change the command. |
| Oscillation on Read/Edit | Edit produces an unexpected state the agent immediately re-reads | Inspect the file after editing. Confirm the change took effect before re-reading. |
| Expanding retry on install | Permission denied or network error | Escalate to user — these are environment issues, not code issues. |
| Context chase on NEEDS_CONTEXT | Story spec missing file lists, interfaces, or schema | Re-read the story spec. If information genuinely does not exist, report BLOCKED rather than NEEDS_CONTEXT. |
| Expanding retry on test | Test is incorrect, not the code | Read the test. Verify the assertion is testing the right thing before modifying implementation. |
