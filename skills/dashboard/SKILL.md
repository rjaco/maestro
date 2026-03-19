---
name: dashboard
description: "Display live session status with temporal context, phase duration, heartbeat age, per-story progress, service connections, autonomy mode, spending, and active task chains."
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

## Services Widget

Read `.maestro/services.yaml` and display each service with its status. Use text indicators: `(ok)` for connected, `(!)` for error, `--` for disconnected. Show capabilities on the same line. Include a summary line.

```
  Services:
    (ok) aws            connected     compute, storage, dns
    (ok) github          connected     repos, issues, actions
    (ok) telegram        connected     messaging, notifications
    (!)  vercel          error         token expired
    --   stripe          disconnected
    --   sendgrid        disconnected
    ─────────────────────────────────
    3 connected  |  1 error  |  2 disconnected
```

Rules:
- Read `.maestro/services.yaml` for each service entry and its `status` field.
- Status values: `connected` → `(ok)`, `error` → `(!)`, `disconnected` → `--`.
- Capabilities come from the service's `capabilities` list joined with `, `.
- For error status, show the error reason in place of capabilities if available.
- Summary line counts: connected, error, disconnected.
- Show all services present in `services.yaml`; omit none.

## Autonomy & Spending Widget

Read `.maestro/config.yaml` for autonomy mode and limits. Read `.maestro/spending-log.yaml` for spending data.

```
  Autonomy:
    Mode:      tiered
    Spending:  $45.50 / $500 session (9%)
               $120.00 / $1,000 day (12%)
    Actions:   14 total (12 auto, 1 approved, 1 denied)
    Last:      Deploy to Vercel ($0) — 5m ago
```

Rules:
- `Mode` comes from `autonomy.mode` in config.yaml (e.g. `tiered`, `auto`, `manual`).
- `Spending` shows session total against `autonomy.limits.session` and day total against `autonomy.limits.day`. Calculate percentage as `floor(spent / limit * 100)`.
- `Actions` totals come from spending-log.yaml entries grouped by outcome: `auto`, `approved`, `denied`.
- `Last` is the most recent action entry from spending-log.yaml: description, cost in parens, elapsed time.
- If `autonomy` section is absent from config.yaml, show `Mode: not configured`.
- If spending-log.yaml does not exist, show `Spending: no data`.

## Active Chains Widget

Read `.maestro/task-queue.yaml` for active chains.

```
  Task Chains:
    ▶ "Launch myapp.com"  3/5 steps  $12.99 spent
      ✓ buy-domain ✓ setup-dns ▶ deploy-app ○ email ○ announce
    (no other chains active)
```

Rules:
- Show only chains with `status: active` from task-queue.yaml.
- For each chain: show name in quotes, step progress as `completed/total`, and total cost spent.
- Show step list on the next line: `✓` for completed steps, `▶` for the current step, `○` for pending steps.
- If only one chain is active, do not show the "(no other chains active)" line.
- If no chains are active, show `No active task chains.` instead.

## Combined Dashboard Display

When `/maestro dashboard` is invoked, show ALL widgets together in this order:

```
+---------------------------------------------+
| Maestro Dashboard                           |
+---------------------------------------------+

  Session: opus-aa-20260319
  Phase:   validate > delegate > [IMPLEMENT 2m 14s]
  Heartbeat: 45s ago (ok)

  Stories:
    ✓ S1 registry     1m 22s    $0.18
    ▶ S2 credentials  3m 05s    $0.42 (running)
    ○ S3 health       —         —
    ○ S4 commands     —         —

  Services:
    (ok) aws         connected    compute, storage
    (ok) github      connected    repos, issues
    (!)  vercel      error        token expired
    --   stripe      disconnected
    ────────────────────────────────────
    2 connected  |  1 error  |  1 disconnected

  Autonomy: tiered | $45.50/$500 session (9%)
  Actions: 14 total (12 auto, 1 approved, 1 denied)

  Task Chains:
    ▶ "Launch myapp.com"  3/5 steps  $12.99
    (no other chains)
```

Rules:
- The box header is always `+---------------------------------------------+` with `| Maestro Dashboard                           |` inside.
- One blank line between each section.
- No blank lines within a section.
- Content indented 2 spaces.
- If `.maestro/services.yaml` is missing, skip the Services section with a `(i) services.yaml not found` note.
- If `.maestro/spending-log.yaml` is missing, show `Spending: no data` in the Autonomy section.
- If `.maestro/task-queue.yaml` is missing, show `No active task chains.` in the Task Chains section.

## Context Budget Widget

Display current context window usage prominently in the dashboard:

```
Context: 45K/200K tokens (22%) ████░░░░░░░░░░░░░░░░ 155K remaining
```

**Data source:** Run `scripts/context-check.sh --json` or parse the current session's JSONL file.

**Display rules:**
- Show a 20-char progress bar using █ (filled) and ░ (empty)
- Color coding:
  - Green (0-59%): Healthy
  - Yellow (60-79%): Getting full
  - Red (80-100%): Critical
- At 80%+ usage, add warning: `(!) Consider /compact or /maestro checkpoint`
- At 90%+ usage, add critical: `(!!) Compaction needed — context nearly full`

**Format in dashboard:**
```
┌─ Context Budget ──────────────────────────────────┐
│ Used: 45,200 / 200,000 tokens (22.6%)             │
│ ████░░░░░░░░░░░░░░░░ 154,800 remaining            │
│ Status: Healthy                                    │
└───────────────────────────────────────────────────┘
```

**Integration in Combined Dashboard Display:**

Include the Context Budget Widget between the header block and the Stories section:

```
+---------------------------------------------+
| Maestro Dashboard                           |
+---------------------------------------------+

  Session: opus-aa-20260319
  Phase:   validate > delegate > [IMPLEMENT 2m 14s]
  Heartbeat: 45s ago (ok)

┌─ Context Budget ──────────────────────────────────┐
│ Used: 45,200 / 200,000 tokens (22.6%)             │
│ ████░░░░░░░░░░░░░░░░ 154,800 remaining            │
│ Status: Healthy                                    │
└───────────────────────────────────────────────────┘

  Stories:
    ...
```

**Progress bar calculation:** `filled = floor(pct / 100 * 20)`, `empty = 20 - filled`. Concatenate `filled` copies of `█` and `empty` copies of `░`.

**Status label mapping:**

| Usage % | Status label | Display |
|---------|-------------|---------|
| 0–59% | Healthy | plain |
| 60–79% | Getting full | plain |
| 80–89% | Warning | `(!) Consider /compact or /maestro checkpoint` |
| 90–100% | Critical | `(!!) Compaction needed — context nearly full` |

**If context data is unavailable** (script not found, JSONL unreadable): show `Context: data unavailable` and skip the widget box.
