---
name: schedule
description: "Manage scheduled tasks — list, add, remove, and check status of cron-based recurring jobs via Claude Code's CronCreate tools"
argument-hint: "[list|add <task> <interval>|remove <id>|status]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
  - AskUserQuestion
---

# Maestro Schedule

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███████╗ ██████╗██╗  ██╗███████╗██████╗ ██╗   ██╗██╗     ███████╗
██╔════╝██╔════╝██║  ██║██╔════╝██╔══██╗██║   ██║██║     ██╔════╝
███████╗██║     ███████║█████╗  ██║  ██║██║   ██║██║     █████╗
╚════██║██║     ██╔══██║██╔══╝  ██║  ██║██║   ██║██║     ██╔══╝
███████║╚██████╗██║  ██║███████╗██████╔╝╚██████╔╝███████╗███████╗
╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═════╝  ╚═════╝ ╚══════╝╚══════╝
```

Manage scheduled recurring tasks using Claude Code's built-in CronCreate, CronList, and CronDelete tools. Enables health checks, daily briefings, memory decay, kanban sync, and custom autonomous tasks.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

Check that CronCreate is available in the current Claude Code environment. If the tool is not available:

```
[maestro] CronCreate is not available in this environment.

  Scheduled tasks require Claude Code with cron tool support.
  Check your Claude Code version or environment configuration.
```

## Step 2: Handle Arguments

### No arguments — Show schedule overview

Read `.maestro/config.yaml` to check `scheduler.enabled`. Call CronList to get registered jobs.

```
+---------------------------------------------+
| Scheduled Tasks                             |
+---------------------------------------------+

  Scheduler: <enabled|disabled>
  Active:    <N> cron job(s) registered

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Schedule"
- Options:
  1. label: "List all schedules", description: "Show all registered cron jobs"
  2. label: "Add a schedule", description: "Register a new recurring task"
  3. label: "Remove a schedule", description: "Delete a registered cron job by ID"
  4. label: "Check status", description: "Show recent execution logs"

### `list` — List all schedules

Call CronList to retrieve all registered cron jobs. Cross-reference with `.maestro/config.yaml` to annotate pre-built schedules.

```
+---------------------------------------------+
| Registered Schedules                        |
+---------------------------------------------+

  ID                        Interval           Description
  ------------------------  -----------------  ----------------------------------
  maestro-health-check      */30 * * * *       Run quality gates and log regressions
  maestro-daily-briefing    0 9 * * 1-5        Generate morning briefing from brain
  maestro-memory-decay      0 0 * * *          Run episodic memory decay sweep
  maestro-kanban-sync       */15 * * * *       Sync kanban board changes
  maestro-webhook-poll      */5 * * * *        Process inbound webhook events

  Total: <N> active schedules
```

If no schedules are registered:

```
[maestro] No schedules are currently registered.

  Add your first schedule with:
    /maestro schedule add health-check "*/30 * * * *"

  Or enable pre-built schedules in .maestro/config.yaml:
    scheduler.schedules.health_check.enabled: true
```

### `add <task> <interval>` — Add a new schedule

If task name and interval are not provided as arguments, gather them interactively.

Use AskUserQuestion:
- Question: "What would you like to schedule? Choose a pre-built task or define a custom one."
- Header: "Task"
- Options:
  1. label: "Health check", description: "Run quality gates every 30 minutes"
  2. label: "Daily briefing", description: "Generate morning briefing at 9am weekdays (requires brain)"
  3. label: "Memory decay", description: "Run episodic memory sweep daily at midnight"
  4. label: "Kanban sync", description: "Sync kanban board every 15 minutes"
  5. label: "Webhook polling", description: "Process inbound events every 5 minutes"
  6. label: "Custom task", description: "Define a custom prompt and cron interval"

If "Custom task" is selected:

Use AskUserQuestion:
- Question: "What should the scheduled task do? Describe the prompt that will be run."
- Header: "Task Description"

Use AskUserQuestion:
- Question: "What cron interval? (e.g., '*/30 * * * *' for every 30 min, '0 9 * * 1-5' for 9am weekdays)"
- Header: "Cron Interval"

For pre-built tasks, use the predefined prompts and default intervals from `skills/scheduler/SKILL.md`.

Check if a job with the same name already exists via CronList. If it does:

Use AskUserQuestion:
- Question: "A schedule named '<id>' already exists. Replace it?"
- Header: "Confirm Replace"
- Options:
  1. label: "Yes, replace", description: "Delete the existing schedule and create a new one"
  2. label: "Cancel", description: "Keep the existing schedule"

Call CronCreate with the resolved name, schedule, and prompt. Confirm:

```
+---------------------------------------------+
| Schedule Added                              |
+---------------------------------------------+

  ID:        <name>
  Interval:  <cron expression>
  Next run:  <estimated next execution time>
  Prompt:    "<truncated prompt...>"

  (i) Remove this schedule with: /maestro schedule remove <name>
```

Also write the schedule to `.maestro/config.yaml` under `scheduler.schedules` or `scheduler.custom` so it survives session resets.

### `remove <id>` — Remove a schedule

If no ID is provided, call CronList and show the available schedules:

Use AskUserQuestion:
- Question: "Which schedule would you like to remove?"
- Header: "Remove Schedule"
- Options: [dynamically populated from CronList output]

Confirm the deletion:

Use AskUserQuestion:
- Question: "Remove schedule '<id>'? This cannot be undone."
- Header: "Confirm Remove"
- Options:
  1. label: "Yes, remove", description: "Delete this cron job permanently"
  2. label: "Cancel", description: "Keep the schedule"

Call CronDelete with the given ID. Also remove the corresponding entry from `.maestro/config.yaml` if present.

Confirm:

```
[maestro] Schedule "<id>" removed.

  (i) Re-add it with: /maestro schedule add <task> <interval>
```

### `status` — Show recent execution logs

Glob `.maestro/logs/health-*.md` and `.maestro/logs/awareness-*.md` for recent task output. Also check `.maestro/notes.md` for any scheduler-generated alerts.

```
+---------------------------------------------+
| Schedule Execution Status                   |
+---------------------------------------------+

  Scheduler:   <enabled|disabled>
  Active jobs: <N>

  Recent Logs
  -----------
  2026-03-18 14:30  maestro-health-check     (ok) all gates passing
  2026-03-18 14:00  maestro-health-check     (ok) all gates passing
  2026-03-18 09:00  maestro-daily-briefing   (ok) briefing generated
  2026-03-18 00:00  maestro-memory-decay     (ok) 3 entries decayed

  (i) Full logs in .maestro/logs/
  (i) Pending notes from scheduler: <N> (see .maestro/notes.md)
```

If no logs are found:

```
[maestro] No execution logs found.

  Logs appear in .maestro/logs/ after the first scheduled run.
  Check that your schedules are registered with /maestro schedule list.
```

## Pre-Built Schedules Reference

| Name | Default Interval | Description | Config Key |
|------|-----------------|-------------|------------|
| `maestro-health-check` | `*/30 * * * *` | Run tsc, lint, tests. Log regressions. | `scheduler.schedules.health_check` |
| `maestro-daily-briefing` | `0 9 * * 1-5` | Morning briefing from brain and state. | `scheduler.schedules.daily_briefing` |
| `maestro-memory-decay` | `0 0 * * *` | Episodic memory decay sweep. | `scheduler.schedules.memory_decay` |
| `maestro-kanban-sync` | `*/15 * * * *` | Pull kanban changes for dev-loop. | `scheduler.schedules.kanban_sync` |
| `maestro-webhook-poll` | `*/5 * * * *` | Process queued webhook events. | `webhooks.poll_interval_minutes` |

Enable any pre-built schedule via config:

```
/maestro config set scheduler.schedules.health_check.enabled true
```

## Error Handling

| Error | Action |
|-------|--------|
| CronCreate unavailable | Warn user, show manual config alternative |
| Duplicate schedule name | Confirm overwrite before proceeding |
| Invalid cron expression | Flag and ask user for a corrected interval |
| Config file not writable | Log the schedule to notes.md instead |
| CronList returns empty | Show "no schedules" message with add instructions |
