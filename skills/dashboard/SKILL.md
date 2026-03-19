---
name: dashboard
description: "Display live session status with temporal context, phase duration, heartbeat age, and per-story progress indicators."
---

# dashboard

## Purpose

Render live, human-readable status during active sessions. Show temporal context so the operator knows at a glance whether work is progressing normally or needs attention.

## Live Progress Indicators

When displaying status during active sessions, include temporal context:

### Phase Duration
Show elapsed time in the current phase:
```
  Phase:   validate > delegate > [IMPLEMENT 2m 14s] > ...
```

### Heartbeat Age
Show time since last heartbeat with staleness indicator:
```
  Heartbeat: 45s ago (ok)     — active
  Heartbeat: 3m ago  (i)      — running slowly
  Heartbeat: 8m ago  (!)      — possibly stalled
  Heartbeat: 20m ago (x)      — likely stalled
```

### Story Progress
Show per-story elapsed time:
```
  Stories:
    ✓ S1 schema        1m 22s    $0.18
    ▶ S2 api-routes    3m 05s    $0.42 (running)
    ○ S3 frontend      —         —
    ○ S4 tests         —         —
```
