---
name: webhooks-github-events
description: "GitHub event processing for webhook system. Maps GitHub API events to Maestro actions using gh CLI polling."
---

# GitHub Event Processing

Process GitHub events by polling the GitHub API via `gh` CLI instead of requiring a webhook server. This approach works within Claude Code's sandbox model.

## Polling vs Webhooks

Since Claude Code can't run an HTTP server, we poll GitHub's API:

```bash
# Get recent repo events
gh api repos/{owner}/{repo}/events --paginate --limit 10 --jq '
  .[] | select(.created_at > "'$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)'")'

# Get recent PRs
gh pr list --state all --limit 5 --json number,title,state,updatedAt

# Get recent issues
gh issue list --state all --limit 5 --json number,title,state,updatedAt

# Get workflow runs
gh run list --limit 5 --json databaseId,status,conclusion,name,updatedAt
```

## Event Mapping

### Pull Request Events

```bash
# Check for new/updated PRs
gh pr list --state open --json number,title,author,updatedAt,labels
```

| PR State | Action |
|----------|--------|
| New PR opened | Log to notes.md, notify if configured |
| PR merged | Update state.md, trigger awareness check |
| PR review requested | Notify reviewer |
| PR checks failing | Notify, suggest fix via notes.md |

### CI/CD Events

```bash
# Check recent workflow runs
gh run list --limit 5 --json databaseId,status,conclusion,name,headBranch
```

| Run Status | Action |
|------------|--------|
| `failure` | Notify (alert), log error to notes.md |
| `success` | Log, update state if relevant branch |
| `in_progress` | No action (informational) |

### Issue Events

```bash
# Check for new issues
gh issue list --state open --limit 10 --json number,title,labels,createdAt
```

| Event | Action |
|-------|--------|
| New issue with `maestro` label | Create story in kanban |
| Issue closed | Update kanban if synced |
| Issue assigned | Log to notes.md |

## Integration with Maestro

When polling finds relevant events:

1. Format event as a note in `.maestro/notes.md`
2. If notifications configured, send alert via notify skill
3. If kanban sync enabled, update board
4. Dev-loop picks up notes between stories

## Scheduling

Use CronCreate to poll periodically:

```
CronCreate
  name: "maestro-github-poll"
  schedule: "*/10 * * * *"
  command: "Poll GitHub for recent events using gh CLI. Check PRs, workflow runs, and issues. Log findings to .maestro/notes.md and send notifications if configured."
```
