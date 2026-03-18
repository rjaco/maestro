---
name: webhooks
description: "Inbound webhook processing. Polls a queue file for external events (GitHub, CI/CD, monitoring) and routes them to Maestro actions."
---

# Webhook Processing

Process inbound events from external services. Since Claude Code can't run a persistent HTTP server, webhooks work via a file-based queue that external services write to and Maestro polls.

## Architecture

```
External Service (GitHub, CI, Datadog)
    |
    v
Webhook Receiver (external script/service)
    |
    v
.maestro/webhooks/queue.json  (file-based queue)
    |
    v
Maestro polls via CronCreate / /loop
    |
    v
Route to appropriate action
```

## Queue Format

External services (or a lightweight receiver script) write events to `.maestro/webhooks/queue.json`:

```json
[
  {
    "id": "evt_001",
    "source": "github",
    "type": "pull_request.opened",
    "timestamp": "2026-03-17T10:30:00Z",
    "payload": {
      "pr_number": 42,
      "title": "Add user authentication",
      "branch": "feat/auth",
      "author": "rodrigo"
    },
    "processed": false
  },
  {
    "id": "evt_002",
    "source": "ci",
    "type": "build.failed",
    "timestamp": "2026-03-17T10:35:00Z",
    "payload": {
      "build_id": "run-123",
      "branch": "main",
      "error": "Test suite failed: 3 tests"
    },
    "processed": false
  }
]
```

## Event Routing

| Source | Event Type | Maestro Action |
|--------|-----------|----------------|
| `github` | `pull_request.opened` | Log to notes.md, notify team |
| `github` | `pull_request.merged` | Update state.md, run awareness check |
| `github` | `push` (to main) | Run health check, notify |
| `github` | `issue.created` | Sync with kanban board |
| `ci` | `build.failed` | Notify, log to notes.md, suggest fix |
| `ci` | `build.passed` | Log, update state |
| `ci` | `deploy.completed` | Notify, log, run smoke tests |
| `monitoring` | `alert.triggered` | Notify (high urgency), log |
| `monitoring` | `alert.resolved` | Notify (low urgency), log |
| `github` | `issue_comment.created` | Parse @maestro command, route to skill |
| `deploy` | `deployment.succeeded` | Notify, log, run post-deploy checks |
| `deploy` | `deployment.failed` | Notify (alert), log error |
| `monitoring` | `error.created` | Create fix story, notify |
| `monitoring` | `monitor.down` | Critical notification |
| `monitoring` | `monitor.up` | Resolve notification |
| `custom` | Any | Log to notes.md for dev-loop pickup |

## Polling Mechanism

Set up polling via CronCreate:

```
CronCreate
  name: "maestro-webhook-poll"
  schedule: "*/5 * * * *"
  command: "Check .maestro/webhooks/queue.json for unprocessed events. For each: route to appropriate action, mark as processed."
```

Or use `/loop 5m` for active session polling.

## Processing Logic

For each unprocessed event in the queue:

1. Read the event
2. Match `source` + `type` against routing table
3. Execute the mapped action:
   - **Notify**: Call notify skill with event summary
   - **Log**: Append to `.maestro/notes.md` for dev-loop
   - **Health check**: Trigger awareness skill
   - **Kanban sync**: Call kanban skill
4. Mark event as `"processed": true`
5. Log processing result to `.maestro/logs/webhooks.log`

## Receiver Script

For GitHub webhooks, a simple receiver script can be set up:

```bash
#!/bin/bash
# Save this as .maestro/webhooks/receiver.sh
# Run: nohup bash .maestro/webhooks/receiver.sh &

# Simple HTTP receiver using netcat (for development only)
# For production, use a proper webhook service like smee.io or webhook.site

QUEUE=".maestro/webhooks/queue.json"
PORT=9876

echo "Webhook receiver listening on port $PORT"

while true; do
  BODY=$(nc -l -p $PORT -q 1 | tail -1)
  if [ -n "$BODY" ]; then
    # Append to queue
    jq --argjson evt "$BODY" '. += [$evt + {"processed": false}]' "$QUEUE" > "$QUEUE.tmp"
    mv "$QUEUE.tmp" "$QUEUE"
    echo "Event received and queued"
  fi
done
```

**For production**: Use services like smee.io (GitHub webhook proxy), webhook.site, or a simple cloud function that writes to a shared file/API.

## GitHub-Specific Events

For GitHub integration via `gh` CLI (no webhook server needed):

```bash
# Poll for recent events instead of receiving webhooks
gh api repos/{owner}/{repo}/events --paginate --limit 10
```

This is simpler than setting up a webhook receiver and works within Claude Code's sandbox model.

## Configuration

```yaml
webhooks:
  enabled: false
  poll_interval_minutes: 5
  queue_file: ".maestro/webhooks/queue.json"
  routes:
    github:
      pull_request: notify
      push: health_check
      issue: kanban_sync
    ci:
      build_failed: notify_alert
      build_passed: log
    monitoring:
      alert: notify_alert
```

## Error Handling

- Queue file doesn't exist → create empty array `[]`
- Invalid JSON in queue → log error, skip
- Event processing fails → log error, don't mark as processed (retry next poll)
- Queue grows too large (>100 events) → archive processed events to `.maestro/webhooks/archive/`
