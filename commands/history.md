---
name: history
description: "View session history and build logs"
argument-hint: "[list|detail SESSION_ID|cost]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Maestro History

View past sessions, build logs, and cost analysis. Reads from `.maestro/logs/`, `.maestro/state.md`, and `.maestro/token-ledger.md`.

## No Arguments or `list` — Session List

Read `.maestro/state.md` for the "Features Completed" section and `.maestro/logs/` for session log files. Present a table:

```
+---------------------------------------------+
| Session History                             |
+---------------------------------------------+
  Date        Feature                  Stories  Cost    Time
  ----------  ---------------------    -------  ------  ------
  2026-03-15  User authentication      5/5      $4.20   14m
  2026-03-12  Dark mode toggle         2/2      $1.10   6m
  2026-03-10  API rate limiting        3/3      $2.85   11m

  Total  3 sessions, 10 stories, $8.15, 31m
```

Use AskUserQuestion:
- Question: "What would you like to see?"
- Header: "History"
- Options:
  1. label: "Session details", description: "View full build log for a specific session"
  2. label: "Cost analysis", description: "Aggregated cost data across all sessions"

If no sessions found:

```
+---------------------------------------------+
| Session History                             |
+---------------------------------------------+
  (i) No session history found.
  (i) History is recorded after completing features with /maestro.
```

### How to Find Sessions

1. Read `.maestro/state.md` — look for entries in "Features Completed" and "History" sections
2. Glob `.maestro/logs/*.md` — each log file contains a session record
3. Read `.maestro/token-ledger.md` — contains per-story cost data

## `detail SESSION_ID` — Session Details

The SESSION_ID can be a date, feature name, or session UUID. Search through logs to find the matching session.

```
+---------------------------------------------+
| Session: User authentication                |
+---------------------------------------------+
  Date      2026-03-15
  Mode      checkpoint
  Duration  14m 32s
  Stories   5/5 completed, 0 skipped

  Story Breakdown
    01  Database schema    (ok)  QA pass 1st   $0.65   2m
    02  API routes         (ok)  QA pass 1st   $0.95   3m
    03  Auth middleware    (ok)  QA pass 2nd   $1.10   4m
    04  Login page         (ok)  QA pass 1st   $0.80   3m
    05  Tests              (ok)  QA pass 1st   $0.70   2m

  QA first-pass rate  80%
  Self-heal cycles    2 total
  Commits             5

Use AskUserQuestion:
- Question: "What next?"
- Header: "Detail"
- Options:
  1. label: "Show git log", description: "View commits from this session"
  2. label: "Back to list", description: "Return to session overview"

## `cost` — Cost Analysis

Aggregate cost data across all sessions:

```
+---------------------------------------------+
| Cost Analysis                               |
+---------------------------------------------+
  Total spend      $8.15
  Total stories    10
  Total sessions   3
  Avg per story    $0.82
  Avg per feature  $2.72

  Model Breakdown
    Sonnet    $5.40    (66%)    8 stories
    Opus      $2.75    (34%)    5 QA reviews

  Cost Trend
    Mar 10    $2.85    (3 stories)
    Mar 12    $1.10    (2 stories)
    Mar 15    $4.20    (5 stories)

  (i) Lower costs by using --yolo mode for well-understood tasks.
  (i) Change models: /maestro model set execution haiku
```

If `.maestro/token-ledger.md` does not exist:

```
+---------------------------------------------+
| Cost Analysis                               |
+---------------------------------------------+
  (i) No cost data found.
  (i) Cost tracking starts automatically when you build features.
  (i) Disable with: /maestro config set cost_tracking.enabled false
```
