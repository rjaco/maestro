---
name: scheduler
description: "Cron-based task scheduling. Run health checks, daily briefings, knowledge base updates, and custom tasks on a schedule using Claude Code's CronCreate tools."
---

# Maestro Scheduler

Schedule recurring tasks using Claude Code's built-in CronCreate/CronList/CronDelete tools. Enables health checks, daily briefings, memory decay, kanban sync, and custom autonomous tasks.

## Pre-Built Schedules

| Schedule | Frequency | What It Does | Requires |
|----------|-----------|-------------|----------|
| Health Check | Every 30 min | Run tests, typecheck, lint. Log regressions. | quality gates in config |
| Daily Briefing | 9am weekdays | Read brain, show priorities, surface pending. | brain integration |
| Memory Decay | Daily | Run episodic memory decay sweep. | memory skill |
| Kanban Sync | Every 15 min | Pull changes from kanban board. | kanban integration |

## Setup

### Enable Scheduling

Via `/maestro config`:

```yaml
scheduler:
  enabled: true
  schedules:
    health_check:
      enabled: true
      cron: "*/30 * * * *"     # Every 30 minutes
      prompt: "Run project health check: tsc --noEmit, npm test, npm run lint. Report results."
    daily_briefing:
      enabled: false            # Requires brain integration
      cron: "0 9 * * 1-5"      # 9am weekdays
      prompt: "Generate daily briefing from .maestro/ state and knowledge base."
    memory_decay:
      enabled: true
      cron: "0 0 * * *"        # Daily at midnight
      prompt: "Run memory decay sweep on .maestro/memory/episodic.md"
    kanban_sync:
      enabled: false            # Requires kanban integration
      cron: "*/15 * * * *"     # Every 15 minutes
      prompt: "Sync stories with configured kanban provider."
```

### Creating Schedules

Use Claude Code's CronCreate tool to register each enabled schedule:

```
CronCreate
  name: "maestro-health-check"
  schedule: "*/30 * * * *"
  command: "Run Maestro health check: execute tsc --noEmit, run test suite, run linter. If any fail, log results to .maestro/logs/health-{date}.md and create a note in .maestro/notes.md flagging the regression."
```

### Listing Schedules

```
CronList
```

Shows all registered Maestro cron jobs.

### Removing Schedules

```
CronDelete
  name: "maestro-health-check"
```

## Custom Schedules

Users can create custom scheduled tasks:

```
/maestro config set scheduler.custom.my_task.cron "0 */4 * * *"
/maestro config set scheduler.custom.my_task.prompt "Check for dependency updates and report"
```

The scheduler skill reads custom schedules from config and registers them via CronCreate.

## Health Check Task

The health check is the most common scheduled task. It:

1. Runs the project's quality gates (from `.maestro/config.yaml`):
   - `tsc --noEmit` (if `quality.run_tsc: true`)
   - `npm run lint` (if `quality.run_lint: true`)
   - `npm test` (if `quality.run_tests: true`)

2. Compares results against the last health check log.

3. If a regression is detected:
   - Log to `.maestro/logs/health-{date}.md`
   - Add a note to `.maestro/notes.md` (picked up by dev-loop between stories)
   - If kanban is configured, create a bug card
   - If brain is configured, save the regression to the knowledge base

4. Output format:

```
+---------------------------------------------+
| Health Check                                |
+---------------------------------------------+
  Time      2026-03-17 14:30

  (ok) TypeScript    clean
  (ok) Linter        clean
  (x)  Tests         2 failing

  Regression detected:
    src/routes/users.test.ts — "should return 401 for invalid token"
    src/routes/users.test.ts — "should rate limit after 10 requests"

  (i) Logged to .maestro/logs/health-2026-03-17.md
  (i) Added to .maestro/notes.md for next dev-loop
```

## Daily Briefing Task

Requires brain integration. Generates a morning briefing:

1. Read `.maestro/state.md` for project state
2. Read `.maestro/state.local.md` for pending sessions
3. Read recent brain notes (last 7 days)
4. Read `.maestro/trust.yaml` for metrics
5. Read recent health check logs

See brain SKILL.md `daily_briefing()` for output format.

## Memory Decay Task

Runs the memory skill's `decay_sweep()` operation:

1. Read `.maestro/memory/episodic.md`
2. Multiply each entry's salience by 0.8
3. Remove entries below 0.1
4. Write updated file

## Kanban Sync Task

Runs the kanban skill's `sync_from_kanban()` operation:

1. Read current board state from provider
2. Compare with Maestro story states
3. If changes detected, write to `.maestro/notes.md` for dev-loop to pick up
4. Push any local status changes to the board

In non-interactive mode (cron), changes are logged but NOT auto-applied. They're flagged in notes.md for the user to review at next interactive session.

## Error Handling

- If a scheduled task fails, log the error but don't retry automatically
- If CronCreate is not available (tool not in environment), warn and skip
- Scheduled tasks run with whatever permissions the Claude Code session has
- Tasks should be idempotent (safe to run multiple times)
