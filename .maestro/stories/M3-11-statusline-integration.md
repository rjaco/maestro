---
id: M3-11
slug: statusline-integration
title: "StatusLine integration — real-time Maestro progress in Claude Code status bar"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. `scripts/statusline.sh` enhanced to show Maestro-specific information
2. When an Opus session is active, StatusLine shows: `[Maestro] M2/7 S3/5 | opus | 42% ctx`
3. When no Opus session, shows: `[Maestro] v1.4.0 | 109 skills | 42% ctx`
4. Format: `[model] context% | [Maestro info]`
5. Reads from `.maestro/state.local.md` for session state
6. Falls back gracefully when state file doesn't exist
7. Executes in <100ms (no slow operations)
8. No external dependencies (no jq, no python)

## Context for Implementer

Claude Code's StatusLine receives JSON on stdin with these fields:
```json
{
  "model": {"display_name": "Opus 4.6"},
  "context_window": {
    "used_percentage": 42,
    "remaining_percentage": 58,
    "context_window_size": 200000
  }
}
```

The script reads stdin, parses with bash/sed, and outputs a single line.

Current `scripts/statusline.sh` already exists. Read it first, then enhance it to include Maestro session status.

Key constraints:
- Must execute fast (<100ms) — this runs after every assistant message
- Cache the state file read in /tmp/maestro-statusline-cache with 5s TTL
- Use pure bash — no jq, no python
- Handle missing state file gracefully (just show version)

Reference: scripts/statusline.sh (current version)
Reference: skills/context-autopilot/SKILL.md for context awareness patterns
