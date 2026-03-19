---
name: workers
description: "Manage background autonomous workers — list, start, stop, check status, and view logs for the 6 scheduled Maestro health workers"
argument-hint: "[list|start [<name>]|stop [<name>]|status [<name>]|logs [<name>]]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - AskUserQuestion
---

# Maestro Workers

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Manage Maestro's 6 autonomous background workers. Workers run on a schedule via cron and monitor project health without requiring user interaction. They log results to `.maestro/logs/workers/` and surface findings in `.maestro/notes.md` for the dev-loop to pick up.

## The 6 Workers

| Name | Schedule | Purpose |
|------|----------|---------|
| `health-check` | Every 30 min | TypeScript, lint, and test regressions |
| `dependency-audit` | Every 6 hr | npm audit for high/critical vulnerabilities |
| `convention-drift` | Every 1 hr | Recent commits vs. DNA conventions |
| `memory-decay` | Daily midnight | Apply confidence decay to stale memories |
| `stale-worktree-cleanup` | Every 1 hr | Flag abandoned git worktrees (> 24h old) |
| `cost-report` | 6pm weekdays | Daily token spend summary by model and story |

## Step 1: Check Prerequisites

Check that `.maestro/dna.md` exists. If it does not:

```
[maestro] Not initialized. Run /maestro init first.

  (i) Workers require .maestro/dna.md — init creates it.
```

## Step 2: Handle Arguments

### No arguments — Show worker overview

Run `CronList` and match results against the 6 known worker names.

```
+---------------------------------------------+
| Background Workers                          |
+---------------------------------------------+

  NAME                     SCHEDULE          STATUS
  health-check             */30 * * * *      registered
  dependency-audit         0 */6 * * *       registered
  convention-drift         0 * * * *         registered
  memory-decay             0 0 * * *         registered
  stale-worktree-cleanup   0 * * * *         registered
  cost-report              0 18 * * 1-5      registered

  Logs: .maestro/logs/workers/
  Notes: .maestro/notes.md

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Workers"
- Options:
  1. label: "List workers", description: "Show all workers and their schedule"
  2. label: "Start all workers", description: "Register all 6 workers with cron"
  3. label: "Stop a worker", description: "Unregister one worker by name"
  4. label: "Check status", description: "Show last run result for each worker"
  5. label: "View logs", description: "Read recent log output for a worker"

---

### `list` — Show all workers and their cron registration

Run `CronList`. For each of the 6 known workers, show whether it is registered or missing.

```
+---------------------------------------------+
| Background Workers                          |
+---------------------------------------------+

  NAME                     SCHEDULE          REGISTERED
  health-check             */30 * * * *      yes
  dependency-audit         0 */6 * * *       yes
  convention-drift         0 * * * *         yes
  memory-decay             0 0 * * *         yes
  stale-worktree-cleanup   0 * * * *         yes
  cost-report              0 18 * * 1-5      no  (!)

  (!) 1 worker is not registered. Run /maestro workers start to register all.
```

---

### `start [<name>]` — Register worker(s) with cron

If `<name>` is provided, register only that worker. If omitted, register all 6.

**Valid names:** `health-check`, `dependency-audit`, `convention-drift`, `memory-decay`, `stale-worktree-cleanup`, `cost-report`

If an invalid name is given:

```
[maestro] Unknown worker: <name>

  Valid workers: health-check, dependency-audit, convention-drift,
                 memory-decay, stale-worktree-cleanup, cost-report
```

For each worker to register, check if it is already registered via `CronList`. If already registered, skip it (idempotent).

Register using `CronCreate` with the schedule and command defined in `skills/background-workers/SKILL.md`.

Confirm:

```
+---------------------------------------------+
| Workers Started                             |
+---------------------------------------------+

  health-check             registered  (*/30 * * * *)
  dependency-audit         registered  (0 */6 * * *)
  convention-drift         registered  (0 * * * *)
  memory-decay             registered  (0 0 * * *)
  stale-worktree-cleanup   registered  (0 * * * *)
  cost-report              registered  (0 18 * * 1-5)

  (i) Workers will begin running on their next scheduled time.
  (i) Logs will appear in .maestro/logs/workers/ after first run.
```

---

### `stop [<name>]` — Unregister a worker

If `<name>` is provided, stop only that worker. If omitted, ask which worker to stop:

Use AskUserQuestion:
- Question: "Which worker would you like to stop?"
- Header: "Stop Worker"
- Options:
  1. label: "health-check", description: "Every 30 min — TypeScript, lint, and test regressions"
  2. label: "dependency-audit", description: "Every 6 hr — npm vulnerability audit"
  3. label: "convention-drift", description: "Every 1 hr — convention drift from DNA"
  4. label: "memory-decay", description: "Daily — memory confidence decay"
  5. label: "stale-worktree-cleanup", description: "Every 1 hr — stale git worktree detection"
  6. label: "cost-report", description: "6pm weekdays — daily token spend summary"
  7. label: "Stop ALL workers", description: "Unregister all 6 workers"

Confirm before stopping:

Use AskUserQuestion:
- Question: "Stop worker \"<name>\"? It will no longer run on its schedule."
- Header: "Confirm Stop"
- Options:
  1. label: "Yes, stop it", description: "Unregister with CronDelete"
  2. label: "Cancel", description: "Keep the worker running"

Run `CronDelete name: "maestro-<name>"` on confirmation.

Confirm:

```
[maestro] Worker "<name>" stopped.

  (i) No further scheduled runs. Existing logs remain in .maestro/logs/workers/.
  (i) Restart with: /maestro workers start <name>
```

---

### `status [<name>]` — Show last run result

If `<name>` is provided, show the most recent log entry for that worker.
If omitted, show the last result for all 6 workers.

Glob `.maestro/logs/workers/<name>-*.log` sorted by date descending, read the most recent file, and display the last log block.

```
+---------------------------------------------+
| Worker Status                               |
+---------------------------------------------+

  health-check         2026-03-18T14:30:00Z  OK
  dependency-audit     2026-03-18T12:00:00Z  CLEAN
  convention-drift     2026-03-18T14:00:00Z  DRIFT_DETECTED  (!)
  memory-decay         2026-03-18T00:00:00Z  OK
  stale-worktree       2026-03-18T14:00:00Z  CLEAN
  cost-report          2026-03-17T18:00:00Z  OK

  (!) convention-drift detected violations — see /maestro workers logs convention-drift
```

If no log file exists for a worker:

```
  <name>    no log yet  (worker may not have run yet)
```

---

### `logs [<name>]` — View recent log output

If `<name>` is omitted, ask which worker's logs to view:

Use AskUserQuestion:
- Question: "Which worker's logs would you like to view?"
- Header: "Worker Logs"
- Options:
  1. label: "health-check", description: "TypeScript, lint, and test check results"
  2. label: "dependency-audit", description: "npm vulnerability audit results"
  3. label: "convention-drift", description: "Convention violation findings"
  4. label: "memory-decay", description: "Memory decay and archival summary"
  5. label: "stale-worktree-cleanup", description: "Stale worktree findings"
  6. label: "cost-report", description: "Daily token spend summary"

Glob `.maestro/logs/workers/<name>-*.log` sorted by date descending. Read the most recent file and display its full contents.

```
+---------------------------------------------+
| Logs: <name>                                |
+---------------------------------------------+

  File: .maestro/logs/workers/<name>-2026-03-18.log

  <full log content>

  (i) Run /maestro workers status to see a summary across all workers.
```

If the log directory or file does not exist:

```
[maestro] No logs found for worker "<name>".

  (i) Logs appear after the first scheduled run.
  (i) Check that the worker is registered: /maestro workers list
```
