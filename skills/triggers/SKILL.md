---
name: triggers
description: "Event-driven automation system. Fires Maestro workflows based on GitHub events, CI/CD status, schedules, file changes, and internal Maestro events. Inspired by Cursor Automations."
---

# Triggers — Event-Driven Automation

Fire Maestro workflows automatically in response to external and internal events. Define trigger → condition → action pipelines in `.maestro/triggers.yml`.

## Trigger Sources

### 1. GitHub
Events detected via `gh api repos/{owner}/{repo}/events` polled every 5 minutes:

| Event | Description |
|-------|-------------|
| `github.pull_request.opened` | New PR created |
| `github.pull_request.commented` | Comment posted on a PR |
| `github.push` | Commit pushed to a branch |
| `github.issue.created` | New issue opened |
| `github.release.published` | A release tag was published |

### 2. CI/CD
Events detected via `gh run list --json status,conclusion,headBranch` or webhook queue:

| Event | Description |
|-------|-------------|
| `ci.build.passed` | Workflow run completed successfully |
| `ci.build.failed` | Workflow run failed |
| `ci.deploy.completed` | Deployment job finished |

### 3. Schedule (Cron)
Time-based triggers registered with Claude Code's CronCreate tool. No polling — Claude Code fires at the scheduled time.

| Cron | Meaning |
|------|---------|
| `0 9 * * 1-5` | 9am weekdays |
| `0 * * * *` | Hourly |
| `0 0 * * 0` | Weekly (Sunday midnight) |
| Any valid cron | Custom cadence |

### 4. File Change
Detected by diffing `git status --short` against the last-known state stored in `.maestro/triggers/last-file-state.txt`. Checked every 5 minutes. `inotifywait` used if available.

| Event | Description |
|-------|-------------|
| `file.changed` | Any tracked file modified |
| `file.changed:<glob>` | Files matching a glob pattern changed |
| `file.added` | New untracked file committed |
| `file.deleted` | File removed from the repo |

### 5. Internal Maestro Events
Emitted by Stop and PostToolUse hooks; read from `.maestro/triggers/internal-events.json`:

| Event | Description |
|-------|-------------|
| `maestro.story.completed` | An agent marked a story DONE |
| `maestro.milestone.done` | A milestone reached completion |
| `maestro.qa.rejected` | QA agent rejected a story |
| `maestro.self_heal.failed` | Self-heal loop exhausted retries |
| `maestro.health.degraded` | Awareness heartbeat detected a regression |

## Configuration Format

`.maestro/triggers.yml`:

```yaml
triggers:
  - name: "auto-review-prs"
    event: github.pull_request.opened
    conditions:
      - branch_matches: "feat/*"
      - author_not: "dependabot"
    action: /maestro plan --review-only
    model: sonnet
    enabled: true

  - name: "fix-failed-builds"
    event: ci.build.failed
    conditions:
      - branch: development
    action: /maestro "Fix the build failure"
    model: sonnet
    enabled: true

  - name: "daily-health-check"
    event: schedule
    cron: "0 9 * * 1-5"
    action: /maestro doctor
    enabled: true

  - name: "post-deploy-tests"
    event: ci.deploy.completed
    conditions:
      - environment: production
    action: scripts/index-health-check.sh
    enabled: false

  - name: "on-qa-rejection"
    event: maestro.qa.rejected
    action: /maestro "Review the QA rejection and revise the story"
    model: sonnet
    enabled: true
```

## Event Detection

Every 5 minutes (via CronCreate or `/loop 5m`), the trigger evaluator:

1. Reads `.maestro/triggers.yml` for enabled triggers
2. Fetches new events from each source
3. Deduplicates against `.maestro/triggers/processed-events.json`
4. Evaluates conditions for each matching event
5. Executes the action if all conditions pass
6. Records the event as processed and appends to `.maestro/logs/triggers.log`

Schedule triggers skip steps 2–4; CronCreate fires them directly at the configured time.

## Condition Evaluation

All conditions must pass (AND logic). Wrap in `any:` for OR logic.

| Syntax | Meaning | Example |
|--------|---------|---------|
| `field: value` | Exact match | `branch: main` |
| `field_matches: pattern` | Glob match | `branch_matches: "feat/*"` |
| `field_regex: pattern` | Regex match | `title_regex: "^fix:"` |
| `field_not: value` | Negation | `author_not: "dependabot"` |
| `field_gt: n` | Numeric greater-than | `pr_size_gt: 500` |
| `field_lt: n` | Numeric less-than | `changed_files_lt: 10` |

Fields reference the event `payload`. Missing field → condition fails (safe default).

## Action Types

**1. Maestro command** — invoke any `/maestro` command in the current workspace:
```yaml
action: /maestro plan --review-only
model: sonnet
```

**2. Shell script** — run a script from the project root; event payload passed as JSON on stdin:
```yaml
action: scripts/index-health-check.sh
```

**3. Notification** — send an alert via the notify skill:
```yaml
action: notify
notify:
  channel: slack
  urgency: high
  message: "Build failed on {{payload.branch}}"
```

**4. Story creation** — auto-create a story in the backlog:
```yaml
action: create-story
story:
  title: "Fix build failure on {{payload.branch}}"
  priority: high
  labels: [auto-generated, ci-failure]
```

**5. Webhook forward** — POST the event payload to an external service:
```yaml
action: webhook-forward
webhook:
  url: "https://hooks.example.com/maestro"
```

## Safety

**Rate limiting** — max 5 triggers per hour per event type. Excess triggers are queued for the next hour window. State stored in `.maestro/triggers/rate-limits.json`.

**Cooldown** — same trigger name will not fire again within 5 minutes of its last execution. Prevents runaway loops on noisy events.

**Manual override:**
```
/maestro triggers pause          # Stop all trigger evaluation immediately
/maestro triggers resume         # Resume trigger evaluation
/maestro triggers status         # Show enabled triggers and last-fired times
```
Pause state: presence of `.maestro/triggers/paused` file = all triggers paused.

**Dry run:**
```
/maestro triggers test <name>    # Simulate trigger using last known event payload
```
Prints what action would have been taken without executing it.

## Integration Points

- **webhooks/SKILL.md** — Trigger evaluator reads `.maestro/webhooks/queue.json` on each poll; webhooks skill handles queue maintenance and raw event ingestion.
- **scheduler/SKILL.md** — Schedule triggers share CronCreate infrastructure with the scheduler skill.
- **ci-watch/SKILL.md** — `ci.build.*` events are sourced from `gh run list`, the same data ci-watch monitors; trigger evaluator delegates run-state lookups to ci-watch.
- **awareness/SKILL.md** — Awareness heartbeat emits `maestro.health.degraded` when it detects regressions, making triggers the natural escalation path.

## State Files

| File | Purpose |
|------|---------|
| `.maestro/triggers.yml` | Trigger definitions (user-managed) |
| `.maestro/triggers/processed-events.json` | Deduplication log |
| `.maestro/triggers/internal-events.json` | Internal Maestro event queue |
| `.maestro/triggers/rate-limits.json` | Rate limit and cooldown state |
| `.maestro/triggers/paused` | Presence = all triggers paused |
| `.maestro/logs/triggers.log` | Execution log with timestamps |
