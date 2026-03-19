---
name: heartbeat
description: "Write heartbeat data to .maestro/logs/heartbeat.json for progress monitoring. Called by opus-loop and dev-loop after each significant action."
---

# Heartbeat

Write a heartbeat snapshot and append a progress event. Used by the daemon and monitoring tools to detect stalls and track autonomous run progress.

## When to Write a Heartbeat

Write a heartbeat:
- After dispatching each implementer or background agent
- At each phase transition in the dev-loop (entering VALIDATE, DELEGATE, IMPLEMENT, SELF-HEAL, QA REVIEW, GIT CRAFT, CHECKPOINT)
- At each milestone boundary in the opus-loop (start, decompose complete, eval, checkpoint)
- After any significant state change (story complete, milestone complete, fix cycle start)

## Step 1: Write heartbeat.json

Write (overwrite) `.maestro/logs/heartbeat.json` with the current state snapshot:

```json
{
  "timestamp": "2026-03-18T14:32:00Z",
  "phase": "implement",
  "milestone": "M1",
  "milestone_total": 6,
  "story": "M1-01",
  "story_total": 4,
  "last_action": "dispatched implementer for M1-01",
  "agent_dispatches": 3,
  "session_id": "opus-wave6-20260318"
}
```

Field definitions:

| Field | Source | Notes |
|-------|--------|-------|
| `timestamp` | Current time | ISO 8601 format (`new Date().toISOString()` equivalent) |
| `phase` | Current dev-loop or opus-loop phase | e.g. `validate`, `implement`, `qa_review`, `milestone_start`, `decompose`, `checkpoint` |
| `milestone` | `current_milestone` from state | e.g. `M1`. Omit if not in opus mode |
| `milestone_total` | `total_milestones` from state | Omit if not in opus mode |
| `story` | Current story ID | e.g. `M1-01` or `03-frontend-ui` |
| `story_total` | `total_stories` from state | Total stories in current milestone (opus) or session |
| `last_action` | Description of the action just taken | Plain English, one sentence |
| `agent_dispatches` | Cumulative count of agents dispatched this session | Increment on each dispatch |
| `session_id` | `session_id` from state | Full session ID string |

If a field is unavailable (e.g. not in opus mode, no milestone), omit it from the JSON rather than writing `null`.

## Step 2: Append to progress.jsonl

Append a single JSON line to `.maestro/logs/progress.jsonl` (create if it does not exist):

```json
{"timestamp":"2026-03-18T14:32:00Z","event":"agent_dispatch","story":"M1-01","details":"dispatched implementer"}
```

Field definitions:

| Field | Value |
|-------|-------|
| `timestamp` | ISO 8601 current time |
| `event` | Event type (see table below) |
| `story` | Current story ID |
| `details` | Short description of what happened |

### Event Types

| Event | When to Use |
|-------|------------|
| `agent_dispatch` | An implementer, fixer, or QA agent was dispatched |
| `phase_transition` | Dev-loop moved to a new phase |
| `milestone_start` | Opus-loop began a new milestone |
| `milestone_complete` | Opus-loop completed a milestone (passed eval) |
| `story_complete` | A story finished QA and git craft |
| `fix_cycle` | Auto-fix loop started for a failing check |
| `qa_rejected` | QA reviewer rejected the implementation |
| `qa_approved` | QA reviewer approved the implementation |
| `safety_valve` | A safety valve triggered (budget, failures, etc.) |
| `session_pause` | Session paused |
| `session_resume` | Session resumed |

## Step 3: Ensure Log Directory Exists

Before writing, create the log directory if it does not exist:

```bash
mkdir -p .maestro/logs
```

## Daemon Integration

The daemon (if running) polls `.maestro/logs/heartbeat.json` to detect stalls. A stall is defined as no heartbeat update for longer than the configured `stall_threshold` (default: 5 minutes).

The `last_action` field is displayed in the daemon's status output and the `/maestro heartbeat` command.

## Integration Points

| Caller | When |
|--------|------|
| `opus-loop` | After each agent dispatch in the DEV LOOP section |
| `dev-loop` | At each phase transition (start of each of the 7 phases) |
| `daemon` | Reads `heartbeat.json` for stall detection |
| `/maestro heartbeat` | Reads `heartbeat.json` for display |
