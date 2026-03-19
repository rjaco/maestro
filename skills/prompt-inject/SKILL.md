---
name: prompt-inject
description: "UserPromptSubmit hook that injects a compact Maestro context block (phase, story, milestone, squad, SOUL principles) into every user prompt, keeping all Claude responses Maestro-aware without explicit /maestro commands."
---

# Prompt Inject

Injects a lightweight Maestro context block into the system context on every user prompt submission. This makes every Claude response Maestro-aware without requiring the user to issue explicit `/maestro` commands.

## When to Inject

Inject on every UserPromptSubmit **except**:

- No active Maestro session (`active: false` in state file, or state file absent)
- CI mode (`CI=true` or `MAESTRO_CI=true` in environment)
- The prompt starts with `/btw` (ambient background notes — Maestro-agnostic by design)
- The state file has been recently injected in the same turn (idempotency guard)

## Hook Handler

The injection is executed by `hooks/prompt-inject-hook.sh`, a lightweight bash script that reads `.maestro/state.local.md` and outputs a compact context string in under 100ms.

**Registration in `hooks/hooks.json`:**

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/prompt-inject-hook.sh"
          }
        ]
      }
    ]
  }
}
```

## Injection Format

The injected block is a compact XML fragment appended to the system context (not inserted into the user's message):

```xml
<maestro-context>
  <session active="true" feature="Auth Refactor" phase="IMPLEMENT" />
  <progress story="3/7" milestone="2/5" />
  <squad name="full-stack-duo" agents="implementer,qa-reviewer" />
  <soul ship-working-code="true" tdd="true" minimal-changes="true" ask-on-doubt="true" />
</maestro-context>
```

### Field Descriptions

| Field | Source | Description |
|-------|--------|-------------|
| `session.active` | `state.local.md → active` | Whether a session is live |
| `session.feature` | `state.local.md → feature` | Current feature name |
| `session.phase` | `state.local.md → phase` | Current dev-loop phase |
| `progress.story` | `state.local.md → current_story / total_stories` | Story position |
| `progress.milestone` | `state.local.md → current_milestone / total_milestones` | Milestone position (Opus only) |
| `squad.name` | `.maestro/squad.yaml → name` | Active squad name |
| `squad.agents` | `.maestro/squad.yaml → agents[].role` | Comma-separated agent roles |
| `soul.*` | `.maestro/soul.md` | Core decision principles as boolean attributes |

If a field is unavailable (file missing, key absent), omit that attribute rather than emitting `""` or `null`.

## Performance Budget

The hook must complete in under 100ms. To meet this budget:

- Read only `.maestro/state.local.md` and `.maestro/squad.yaml` (skip SOUL deep parse — use cached booleans)
- No subprocess chains — the hook is a single bash script, no piped interpreters
- No network calls
- Exit immediately (code 0) if no active session

The `hooks/prompt-inject-hook.sh` script stays under 60 lines. Any logic that cannot fit within that budget belongs in a separate skill invoked at session start, not on every prompt.

## Skip Conditions (Detailed)

| Condition | Check | Behavior |
|-----------|-------|----------|
| No DNA file | `.maestro/dna.md` absent | Silent exit (Maestro not installed) |
| No state file | `.maestro/state.local.md` absent | Silent exit |
| Session inactive | `active != "true"` in state | Silent exit |
| CI mode | `CI=true` or `MAESTRO_CI=true` | Silent exit |
| `/btw` prompt | First word of user message is `/btw` | Silent exit |

## Output Contract

```yaml
output_contract:
  writes: none
  reads:
    - .maestro/state.local.md
    - .maestro/squad.yaml (optional)
  side_effects: system context injection (via UserPromptSubmit hook return value)
  latency_budget_ms: 100
```

## Integration Points

- **hooks-integration/SKILL.md** — registers this hook in the hooks summary table
- **session-start-hook.sh** — session-start injection is coarser (human-readable); prompt-inject is machine-readable XML for per-prompt Maestro-awareness
- **squad/SKILL.md** — squad name and agents sourced from active squad configuration
- **demo-mode/SKILL.md** — when demo mode is active, inject demo session context instead of real state
