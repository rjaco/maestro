---
name: heartbeat
description: "Show the last heartbeat and time since last activity"
allowed-tools:
  - Read
  - Bash
---

# Maestro Heartbeat

Show the last heartbeat written by the running Maestro session and how long ago it was recorded.

## Step 1: Read the Heartbeat File

Read `.maestro/logs/heartbeat.json`.

If the file does not exist:

```
No heartbeat found. Is Maestro running?

Start a session with: /maestro "your feature"
```

Stop here.

## Step 2: Parse and Display

Parse the JSON and calculate how long ago the `timestamp` was relative to the current time.

Display a summary:

```
+---------------------------------------------+
| Maestro Heartbeat                           |
+---------------------------------------------+

  Last activity:  [N seconds / minutes / hours] ago
  Timestamp:      [timestamp, human-readable]
  Session:        [session_id]

  Phase:          [phase]
  Milestone:      [milestone] / [milestone_total]   (omit if not in opus mode)
  Story:          [story] / [story_total]
  Agent dispatches: [agent_dispatches]

  Last action:    [last_action]

+---------------------------------------------+
```

If `milestone` or `milestone_total` is absent from the heartbeat, omit that line from the display.

### Staleness Indicator

Based on elapsed time since the last heartbeat, add a status line:

| Elapsed | Status |
|---------|--------|
| < 1 minute | `(ok) Active` |
| 1–5 minutes | `(i)  Running slowly` |
| 5–15 minutes | `(!)  Possibly stalled` |
| > 15 minutes | `(x)  Likely stalled — consider checking the session` |

Show the status line immediately below the "Last activity" line:

```
  Last activity:  3 minutes ago
  Status:         (i)  Running slowly
```

## Step 3: Show Recent Events (optional)

If `.maestro/logs/progress.jsonl` exists, read the last 5 lines and display them as a recent event log:

```
  Recent events:
    14:32:01  agent_dispatch    M1-01  dispatched implementer
    14:30:45  phase_transition  M1-01  entering qa_review
    14:28:12  phase_transition  M1-01  entering implement
    14:27:55  phase_transition  M1-01  entering delegate
    14:27:30  milestone_start   M1     beginning milestone 1
```

If the file does not exist or is empty, omit this section.

## Step 4: Multi-Agent Overview (if agents are active)

If `.maestro/logs/` contains any `agent-*.jsonl` files written in the last 30 minutes, display a per-agent summary below the main heartbeat block:

```
  Active agents:
    implementer-01   dispatched 4 min ago   phase: implement   story: M1-02
    qa-reviewer-01   dispatched 1 min ago   phase: qa_review   story: M1-01
```

Read each `agent-<id>.jsonl` file and extract the last entry's `phase`, `story`, and `dispatched_at` fields.

If no agent files exist or all are older than 30 minutes, omit this section.

## Argument Parsing

| Argument | Behavior |
|----------|----------|
| (none) | Show heartbeat for the current/most recent session |
| `<session_id>` | Show heartbeat filtered to a specific session ID |
| `--watch` | Refresh the display every 10 seconds (loop until Ctrl+C) |
| `--json` | Output raw heartbeat JSON instead of formatted display |

### `<session_id>` argument

If a session ID is provided, read `.maestro/logs/heartbeat.json` and verify the `session_id` field matches. If it does not match:

```
[maestro] No active heartbeat for session "<session_id>".

  Current session: <current_session_id>
  Run /maestro heartbeat to see the active session.
```

### `--json` argument

If `--json` is passed, skip the formatted display and output the raw contents of `.maestro/logs/heartbeat.json` as-is. This is useful for scripting and piping to `jq`.

```json
{
  "session_id": "sess-abc123",
  "timestamp": "2026-03-19T14:32:01Z",
  "phase": "implement",
  "milestone": 1,
  "milestone_total": 3,
  "story": "M1-02",
  "story_total": 5,
  "agent_dispatches": 7,
  "last_action": "dispatched implementer for M1-02"
}
```

## Error Handling

| Condition | Action |
|-----------|--------|
| `.maestro/logs/heartbeat.json` missing | Show "No heartbeat found" message and stop |
| File exists but is not valid JSON | Show `(x) Heartbeat file corrupt — cannot parse .maestro/logs/heartbeat.json` |
| `timestamp` field missing from JSON | Show heartbeat without elapsed time; note `(!) timestamp field missing` |
| `timestamp` is in the future | Show `(!) Clock skew detected — heartbeat timestamp is in the future` |
| `.maestro/logs/` directory missing | Treat same as heartbeat file missing |

## Examples

### Example 1: Active session, healthy

```
/maestro heartbeat
```

```
+---------------------------------------------+
| Maestro Heartbeat                           |
+---------------------------------------------+

  Last activity:  47 seconds ago
  Status:         (ok) Active
  Timestamp:      2026-03-19 14:32:01 UTC
  Session:        sess-abc123

  Phase:          implement
  Milestone:      1 / 3
  Story:          M1-02 / 5
  Agent dispatches: 7

  Last action:    dispatched implementer for M1-02

  Recent events:
    14:32:01  agent_dispatch    M1-02  dispatched implementer
    14:31:45  phase_transition  M1-02  entering implement
    14:30:12  phase_transition  M1-01  entering qa_review
    14:29:55  agent_dispatch    M1-01  dispatched qa-reviewer
    14:28:30  story_complete    M1-01  QA passed
```

### Example 2: Stalled session

```
+---------------------------------------------+
| Maestro Heartbeat                           |
+---------------------------------------------+

  Last activity:  22 minutes ago
  Status:         (x)  Likely stalled — consider checking the session
  Timestamp:      2026-03-19 14:10:05 UTC
  Session:        sess-xyz789

  Phase:          qa_review
  Story:          M2-03 / 8
  Agent dispatches: 14

  Last action:    dispatched qa-reviewer for M2-03

  (i) Run /maestro status for full session details.
  (i) If the session is hung, run /maestro status abort to recover.
```

### Example 3: No active session

```
No heartbeat found. Is Maestro running?

Start a session with: /maestro "your feature"
```

## Notes

- The heartbeat file is written by the `heartbeat` skill, called from `opus-loop` and `dev-loop`.
- A stale heartbeat does not necessarily mean failure — the session may be waiting on a long-running agent or a user checkpoint prompt.
- To check the full session status, run `/maestro status`.
- The heartbeat JSON schema is defined in `skills/heartbeat/SKILL.md`.
