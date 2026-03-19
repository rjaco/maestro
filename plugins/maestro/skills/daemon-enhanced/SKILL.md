---
name: daemon-enhanced
description: "Enhanced autonomous daemon with remote command integration. Polls messaging channels and file inbox, executes task chains and individual commands, manages crash recovery and state persistence."
---

# Enhanced Autonomous Daemon

The enhanced daemon is a long-running autonomous agent that polls for commands from multiple sources, executes task chains and individual instructions, and maintains persistent state between invocations. It is started by `scripts/autonomous-daemon.sh` and driven by the `claude` CLI.

## Architecture

```
┌─────────────────────────────────────────────┐
│  maestro-autonomous-daemon                  │
│                                             │
│  Main Loop:                                 │
│    1. Check for commands (messaging channels│
│       + .maestro/inbox/*.yaml)              │
│    2. Check for pending task chains         │
│    3. Execute next step of active chain     │
│    4. Process approval responses            │
│    5. Update state + send notifications     │
│    6. Sleep (configurable interval)         │
│    7. Loop back to 1                        │
│                                             │
│  Command Sources:                           │
│    - CLI: /maestro daemon command "..."     │
│    - Telegram: message to bot               │
│    - Slack: message in channel              │
│    - File: .maestro/inbox/<timestamp>.yaml  │
│                                             │
│  State:                                     │
│    - .maestro/daemon-state.yaml             │
│    - .maestro/spending-log.yaml             │
│    - .maestro/task-queue.yaml               │
└─────────────────────────────────────────────┘
```

## Daemon State

The daemon writes its state after every action. On startup, it reads this file to detect and resume from crashes.

```yaml
# .maestro/daemon-state.yaml
daemon:
  pid: 12345
  started_at: "2026-03-19T12:00:00Z"
  uptime_seconds: 7200
  autonomy_mode: tiered
  active_chain: null
  tasks_completed: 5
  tasks_failed: 0
  spending:
    session: 45.50
    day: 120.00
  last_activity: "2026-03-19T13:55:00Z"
  version: "1.0.0"
```

Fields:

| Field | Description |
|-------|-------------|
| `pid` | OS process ID of the daemon shell script |
| `started_at` | ISO timestamp of daemon start or last restart |
| `uptime_seconds` | Seconds since `started_at` |
| `autonomy_mode` | Current mode: `manual`, `tiered`, or `full-auto` |
| `active_chain` | Chain name currently executing, or `null` |
| `tasks_completed` | Total tasks completed in this session |
| `tasks_failed` | Total tasks failed in this session |
| `spending.session` | USD spent this session |
| `spending.day` | USD spent today (rolling 24h) |
| `last_activity` | ISO timestamp of last completed action |

## Task Queue

Commands from all sources are normalized into `task-queue.yaml` before execution.

```yaml
# .maestro/task-queue.yaml
tasks:
  - id: "task-001"
    source: telegram
    chat_id: "123456"
    command: "Buy domain myapp.com and deploy the landing page"
    status: pending
    created_at: "2026-03-19T14:00:00Z"

  - id: "task-002"
    source: cli
    command: "Run the email campaign chain"
    status: running
    started_at: "2026-03-19T14:05:00Z"

  - id: "task-003"
    source: file
    inbox_file: ".maestro/inbox/1710856800.yaml"
    command: "Check if the Vercel deployment is healthy"
    status: completed
    started_at: "2026-03-19T14:08:00Z"
    completed_at: "2026-03-19T14:08:12Z"
    result: "Deployment healthy. URL: https://myapp.vercel.app"
```

Task status lifecycle: `pending` → `running` → `completed` | `failed`

## Inbox File Format

Drop YAML files into `.maestro/inbox/` to queue commands from scripts or other tools:

```yaml
# .maestro/inbox/1710856800.yaml
command: "Run the social-media-blitz chain for the product launch"
source: file
priority: normal  # normal | high | low
reply_to: null    # optional: notification channel for result
created_at: "2026-03-19T14:00:00Z"
```

The daemon processes inbox files in creation-time order. After processing, files are moved to `.maestro/inbox/processed/`.

## Daemon Loop (Detailed)

Each iteration of the main loop:

### Step 1: Ingest Commands

**Messaging channels** (Telegram/Slack):
1. Read `.maestro/config.yaml` for configured messaging providers
2. For Telegram: poll `getUpdates` API for new messages
3. For Slack: poll events API or check configured channel
4. Filter messages addressed to the bot (direct messages or @mention)
5. Parse command text and source metadata
6. Write to task-queue.yaml with status `pending`

**File inbox**:
1. List `.maestro/inbox/*.yaml` files not yet processed
2. Parse each file into a task entry
3. Append to task-queue.yaml with status `pending`
4. Do not delete yet — move only after task completes

### Step 2: Check for Pending Chains

1. Read daemon-state.yaml — check `active_chain` field
2. If an active chain exists, read its state from `.maestro/chains/<name>.state.yaml`
3. Determine the next pending step
4. Continue from Step 3 below

If no active chain, check for queued tasks that translate to chain execution:
- If task command matches a chain template name, start that chain
- Otherwise, proceed to Step 3 for ad-hoc command execution

### Step 3: Execute Active Chain Step

If a chain is active:
1. Invoke the task-chain skill for the next step
2. Capture outputs and write chain state
3. Send step receipt notification
4. If step failed: invoke rollback engine, update daemon state
5. If chain complete: clear `active_chain`, send completion notification

If no chain is active but tasks are pending:
1. Take the oldest `pending` task
2. Mark it `running`, record `started_at`
3. Invoke `claude` CLI with the task command and appropriate context
4. Capture result, mark `completed` or `failed`
5. Send result back to the originating channel (Telegram/Slack/log)

### Step 4: Process Approval Responses

For steps requiring T2/T3 approval:
1. Check `.maestro/inbox/` for approval response files
2. Check Telegram/Slack for approval messages (yes/no/abort)
3. If approved: resume the paused chain step
4. If denied: trigger rollback, notify user
5. Approval timeout: if no response in 30 minutes, notify and pause the chain

### Step 5: Update State

1. Write updated daemon-state.yaml:
   - Increment `tasks_completed` or `tasks_failed`
   - Update `last_activity` timestamp
   - Recalculate `uptime_seconds`
   - Update `spending.session` from spending-log.yaml
2. Flush completed tasks from task-queue.yaml (keep last 50 completed for history)

### Step 6: Sleep

Sleep for `$DAEMON_INTERVAL` seconds (default: 30).

## Command Parsing

When the daemon receives a natural-language command, it classifies it:

| Command Pattern | Action |
|----------------|--------|
| `run chain <name>` | Start named chain template |
| `run chain --custom <yaml>` | Define and execute custom chain |
| `chain status` | Report current chain status |
| `abort chain` | Trigger rollback on active chain |
| `buy/purchase/setup/deploy/configure...` | Route to appropriate service skill |
| `what is...`, `check...`, `status of...` | T1 read-only action |
| `pause` | Graceful daemon pause after current task |
| `stop` | Immediate daemon shutdown |
| `status` | Report daemon state |
| `budget` | Report spending and limits |

Unrecognized commands: log and notify the sender with "Command not understood: ..."

## Crash Recovery

On daemon startup, before entering the main loop:

1. Check if `daemon-state.yaml` exists
2. If the PID in state matches a running process: daemon already running, exit with message
3. If the PID does not match a running process:
   - A crash occurred. Log recovery event.
   - Check `active_chain` — if set, read chain state and resume from the last completed step
   - Check `task-queue.yaml` for any `running` tasks — mark them `failed` (they did not complete)
   - Send "daemon restarted after crash" notification with context
4. Write new PID to daemon-state.yaml
5. Enter main loop

Recovery notification:
```
[Maestro Daemon] Restarted after unexpected stop
Previous PID: 12345 (not running)
Recovering chain: "Launch myapp.com" — resuming from step deploy-app
Tasks marked failed during recovery: task-002
```

## Spending Controls

The daemon enforces configurable spending limits. Read from `.maestro/config.yaml`:

```yaml
daemon:
  spending_limits:
    per_task: 50.00     # USD max per single task
    per_session: 500.00 # USD max for entire daemon session
    per_day: 200.00     # USD rolling 24h
```

Before executing any action with a cost estimate:
1. Read current spend from `spending-log.yaml`
2. If `session_spend + estimated_cost > per_session`: pause daemon, notify
3. If `day_spend + estimated_cost > per_day`: pause daemon, notify
4. If `task_cost_so_far + estimated_cost > per_task`: pause task, notify

On limit trigger, send a notification and wait for explicit approval before continuing.

## Spending Log

```yaml
# .maestro/spending-log.yaml
session_start: "2026-03-19T12:00:00Z"
session_total: 45.50
day_total: 120.00
entries:
  - timestamp: "2026-03-19T14:00:08Z"
    task_id: "task-001"
    service: namecheap
    action: "Purchase domain myapp.com"
    cost: 12.99
  - timestamp: "2026-03-19T14:05:33Z"
    task_id: "task-002"
    service: vercel
    action: "Deploy to Vercel (Pro plan)"
    cost: 0.00
```

## Autonomy Mode

The daemon operates in one of three autonomy modes, configurable in `.maestro/config.yaml`:

```yaml
daemon:
  autonomy_mode: tiered  # manual | tiered | full-auto
```

| Mode | T1 | T2 | T3 |
|------|----|----|----|
| `manual` | requires approval | requires approval | requires approval |
| `tiered` | auto | auto | requires approval |
| `full-auto` | auto | auto | auto |

The mode can be changed while the daemon is running by:
- Sending "set autonomy full-auto" via Telegram/Slack
- Editing the config file (takes effect on next loop iteration)
- Running `/maestro daemon autonomy full-auto` from CLI

## Notification Integration

The daemon sends notifications via the notify skill for:

| Event | Severity | Message |
|-------|----------|---------|
| Task started | info | "Started: [command]" |
| Task completed | info | "Done: [command] — [result summary]" |
| Task failed | warning | "Failed: [command] — [error]" |
| Chain step complete | info | "Chain [N]/[M]: [step] done" |
| Chain complete | info | "Chain [name] complete — [summary]" |
| Chain failed | error | "Chain [name] FAILED at [step]" |
| Rollback complete | warning | "Rollback complete — [N] steps reversed" |
| Spending limit reached | warning | "Spending limit reached — paused" |
| Approval required | info | "Approval needed: [action]" |
| Daemon restarted | warning | "Daemon restarted after crash" |
| Daemon stopped | info | "Daemon stopped gracefully" |

## Graceful Shutdown

On SIGTERM:
1. Finish the current step if actively running (do not interrupt mid-action)
2. Write final state to daemon-state.yaml with `active: false`
3. Send "daemon stopped gracefully" notification
4. Exit 0

On SIGKILL: No cleanup possible — crash recovery handles the next startup.

## Log Format

All daemon activity is appended to `.maestro/logs/daemon.log`:

```
[2026-03-19T14:00:00Z] [INFO]    Daemon started. PID=12345. Mode=tiered. Interval=30s
[2026-03-19T14:00:05Z] [INFO]    New task from telegram: "Buy domain myapp.com"
[2026-03-19T14:00:08Z] [INFO]    Task task-001 running
[2026-03-19T14:00:08Z] [INFO]    Chain started: Launch myapp.com (5 steps)
[2026-03-19T14:00:16Z] [INFO]    Step buy-domain done. Cost: $12.99
[2026-03-19T14:00:19Z] [INFO]    Step setup-dns done. Cost: $0
[2026-03-19T14:00:20Z] [WARN]    T3 approval required for step: announce
[2026-03-19T14:02:10Z] [INFO]    Approval received from telegram (chat_id: 123456)
[2026-03-19T14:02:12Z] [INFO]    Step announce done. Cost: $0
[2026-03-19T14:02:12Z] [INFO]    Chain complete: Launch myapp.com. Total: $12.99. Time: 124s
[2026-03-19T14:02:12Z] [INFO]    Task task-001 completed
```

Log levels: `DEBUG`, `INFO`, `WARN`, `ERROR`

## Integration Points

### With task-chain skill
- The daemon executes chains step-by-step, delegating to the task-chain orchestrator
- Chain state is shared via `.maestro/chains/<name>.state.yaml`

### With notification hub (notify skill)
- All daemon events are dispatched through the notify skill
- Provider routing (Telegram/Slack/Discord) is handled by notify

### With credential manager
- Credentials for services accessed by tasks are read from the credential manager
- The daemon does not store secrets directly

### With autonomy engine
- Before each service action, consult the autonomy engine for tier classification
- Autonomy mode is enforced consistently across chain and ad-hoc tasks

### With token-ledger / spending-log
- All costs are written to spending-log.yaml
- The ledger is consulted before actions to enforce spending limits
