---
name: webhooks
description: "Manage webhook event processing — list configured sources, add or remove routes, test event handling, and view processing logs"
argument-hint: "[list|add <source>|remove <id>|test|logs]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
  - AskUserQuestion
---

# Maestro Webhooks

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
██╗    ██╗███████╗██████╗ ██╗  ██╗ ██████╗  ██████╗ ██╗  ██╗███████╗
██║    ██║██╔════╝██╔══██╗██║  ██║██╔═══██╗██╔═══██╗██║ ██╔╝██╔════╝
██║ █╗ ██║█████╗  ██████╔╝███████║██║   ██║██║   ██║█████╔╝ ███████╗
██║███╗██║██╔══╝  ██╔══██╗██╔══██║██║   ██║██║   ██║██╔═██╗ ╚════██║
╚███╔███╔╝███████╗██████╔╝██║  ██║╚██████╔╝╚██████╔╝██║  ██╗███████║
 ╚══╝╚══╝ ╚══════╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝
```

Manage inbound webhook event processing. Since Claude Code cannot run a persistent HTTP server, webhooks use a file-based queue at `.maestro/webhooks/queue.json` that external services write to and Maestro polls on a cron schedule.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

Read `webhooks.enabled` in config. If webhooks are disabled:

```
[maestro] Webhook processing is currently disabled.

  Enable it with:
    /maestro config set webhooks.enabled true

  Then add your first source with:
    /maestro webhooks add github
```

## Step 2: Handle Arguments

### No arguments — Show webhook status

Read `.maestro/config.yaml` for `webhooks` settings. Check if `.maestro/webhooks/queue.json` exists and count unprocessed events.

```
+---------------------------------------------+
| Webhook Processing                          |
+---------------------------------------------+

  Status:    <enabled|disabled>
  Poll:      every <N> minutes (via CronCreate)
  Queue:     .maestro/webhooks/queue.json
  Pending:   <N> unprocessed event(s)

  Configured sources:
    github       (ok) pull_request, push, issue
    ci           (ok) build.failed, build.passed
    monitoring   ( -) not configured

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Webhooks"
- Options:
  1. label: "List sources", description: "Show all configured webhook sources and routes"
  2. label: "Add a source", description: "Configure a new inbound event source"
  3. label: "Remove a source", description: "Delete a configured source route"
  4. label: "Test processing", description: "Process any pending events in the queue now"
  5. label: "View logs", description: "Show recent webhook processing logs"

### `list` — List configured sources

Read `.maestro/config.yaml` under `webhooks.routes`. Display all configured sources and their event mappings.

```
+---------------------------------------------+
| Webhook Sources                             |
+---------------------------------------------+

  Source       Event                  Maestro Action
  -----------  --------------------   ------------------
  github       pull_request.opened    Log + notify team
  github       pull_request.merged    Update state + awareness
  github       push (to main)         Health check + notify
  github       issue.created          Kanban sync
  ci           build.failed           Notify (alert) + log
  ci           build.passed           Log + update state
  ci           deploy.completed       Notify + post-deploy check
  monitoring   alert.triggered        Notify (high urgency) + log
  monitoring   alert.resolved         Notify (low urgency) + log

  Queue file:  .maestro/webhooks/queue.json
  Poller:      maestro-webhook-poll (every 5 min)
```

If no routes are configured:

```
[maestro] No webhook sources configured.

  Add your first source with:
    /maestro webhooks add github
```

### `add <source>` — Add a webhook source

Valid sources: `github` | `ci` | `monitoring` | `deploy` | `custom`

If source is not provided or not recognized:

Use AskUserQuestion:
- Question: "Which event source would you like to add?"
- Header: "Source"
- Options:
  1. label: "GitHub", description: "PRs, pushes, issues, and comments from GitHub"
  2. label: "CI/CD", description: "Build success/failure, deploy events from your CI pipeline"
  3. label: "Monitoring", description: "Alerts and resolutions from Datadog, PagerDuty, or similar"
  4. label: "Deploy", description: "Deployment succeeded/failed events"
  5. label: "Custom", description: "Define a custom source and event routing"

For each source, show the default event routes and ask which to enable:

Use AskUserQuestion:
- Question: "Which events should Maestro react to for <source>? Select all that apply or choose 'All defaults'."
- Header: "Events"
- Options: [populated from the routing table in `skills/webhooks/SKILL.md`]

Add the selected routes to `.maestro/config.yaml` under `webhooks.routes`.

For GitHub specifically, show setup instructions:

```
+---------------------------------------------+
| GitHub Webhook Setup                        |
+---------------------------------------------+

  Queue file: .maestro/webhooks/queue.json

  Option A — gh CLI polling (simpler, no server needed):
    Maestro polls: gh api repos/{owner}/{repo}/events
    No webhook URL required.

  Option B — HTTP receiver:
    1. Start the receiver script:
         bash .maestro/webhooks/receiver.sh &
    2. Configure GitHub to POST to your machine's IP:
         http://<your-ip>:9876
    3. For public access, use smee.io as a proxy:
         smee --url https://smee.io/<channel> --port 9876

  (i) Option A is recommended for local development.
```

If a polling schedule is not yet registered:

```
  (i) Webhook polling requires a cron schedule.
      Set it up now with: /maestro schedule add webhook-poll "*/5 * * * *"
```

Confirm:

```
[maestro] Webhook source "<source>" added.

  Events configured: <N> routes
  (i) Events will be processed every <N> minutes.
  (i) View logs with: /maestro webhooks logs
```

### `remove <id>` — Remove a source

If no ID is provided, show the list of configured sources and ask which to remove.

Use AskUserQuestion:
- Question: "Which source would you like to remove?"
- Header: "Remove Source"
- Options: [dynamically populated from config]

Confirm:

Use AskUserQuestion:
- Question: "Remove all routes for '<source>'? Unprocessed events will remain in the queue."
- Header: "Confirm Remove"
- Options:
  1. label: "Yes, remove", description: "Delete all routes for this source"
  2. label: "Cancel", description: "Keep the source configured"

Remove the source block from `.maestro/config.yaml` under `webhooks.routes`. Confirm:

```
[maestro] Source "<source>" removed.

  (i) Existing events from this source in the queue will still be processed.
  (i) Re-add with: /maestro webhooks add <source>
```

### `test` — Test event processing

Read `.maestro/webhooks/queue.json`. If the file does not exist, create it as an empty array `[]`.

Count unprocessed events (`"processed": false`).

If no pending events:

```
[maestro] No pending events in the queue.

  To test manually, add a sample event to:
    .maestro/webhooks/queue.json

  Example:
    [
      {
        "id": "evt_test_001",
        "source": "github",
        "type": "push",
        "timestamp": "<now>",
        "payload": { "branch": "main" },
        "processed": false
      }
    ]
```

If pending events exist, invoke the webhooks skill from `skills/webhooks/SKILL.md` to process all unprocessed events:

For each event:
1. Match `source` + `type` against the routing table
2. Execute the mapped action (notify, log to notes.md, trigger awareness, sync kanban)
3. Mark as `"processed": true`
4. Log to `.maestro/logs/webhooks.log`

Display a processing summary:

```
+---------------------------------------------+
| Webhook Processing Run                      |
+---------------------------------------------+

  Processed: <N> events

  Event                         Source    Status
  ----------------------------  --------  ------
  pull_request.opened (#42)     github    (ok) logged + notified
  build.failed (run-123)        ci        (ok) alert sent, logged to notes

  (i) Full log: .maestro/logs/webhooks.log
```

### `logs` — View processing logs

Read `.maestro/logs/webhooks.log`. Display the most recent 20 entries.

```
+---------------------------------------------+
| Webhook Processing Logs                     |
+---------------------------------------------+

  Timestamp              Event                         Source    Result
  ---------------------  ----------------------------  --------  ------
  2026-03-18 14:32:01    pull_request.opened (#42)     github    ok
  2026-03-18 14:32:01    build.failed (run-123)         ci        ok
  2026-03-18 14:27:00    push (main, a1b2c3d)          github    ok
  2026-03-18 14:22:00    alert.triggered (CPU>90%)     monitor   ok

  Showing last 20 entries. Full log: .maestro/logs/webhooks.log
```

If the log file does not exist:

```
[maestro] No webhook logs found.

  Logs are created after the first event is processed.
  Run /maestro webhooks test to process any pending events.
```

## Architecture Reference

```
External Service (GitHub, CI, Datadog)
    |
    v
Webhook Receiver (external script or gh CLI polling)
    |
    v
.maestro/webhooks/queue.json  (file-based queue)
    |
    v
Maestro polls via CronCreate (every 5 min)
    |
    v
Route to appropriate action (notify, log, health check, kanban sync)
```

## Error Handling

| Error | Action |
|-------|--------|
| Queue file missing | Create empty `[]` automatically |
| Invalid JSON in queue | Log error, skip malformed events |
| Event processing fails | Log error, do not mark as processed (retry next poll) |
| Queue exceeds 100 events | Archive processed events to `.maestro/webhooks/archive/` |
| Unknown source in event | Log to notes.md as `custom` event for manual review |
| Routing action unavailable | Log the event, note which skill is missing |
