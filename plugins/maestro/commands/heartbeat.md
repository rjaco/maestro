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

## Notes

- The heartbeat file is written by the `heartbeat` skill, called from `opus-loop` and `dev-loop`.
- A stale heartbeat does not necessarily mean failure — the session may be waiting on a long-running agent or a user checkpoint prompt.
- To check the full session status, run `/maestro status`.
