---
name: self-heal-enhanced
description: "Enhanced self-healing with typed recovery strategies for auth expiry, rate limits, transient network errors, missing CLIs, permission errors, git state, worktree conflicts, disk space, and context overflow. Logs all attempts to .maestro/logs/self-heal.yaml."
---

# Self-Heal Enhanced

Extended self-healing layer for dev-loop Phase 4. Classifies failures into
typed error categories, applies a matching recovery strategy, and escalates
with an actionable message if the strategy fails.

## Flow

```
1. Error occurs during task execution
2. Classify error type (auth, network, tool, git, resource, context)
3. Look up recovery strategy for that type
4. Attempt automatic fix (within autonomy bounds)
5. If fix succeeds: log recovery, continue
6. If fix fails: escalate to user with enhanced error message
7. Log all self-heal attempts for retrospective
```

Autonomy bounds: automatic fixes may run read-only commands, wait, stash git
state, and retry. They must NOT modify credentials, delete files, force-push,
or change infrastructure configuration.

## Error Classification

Classify the error before applying a strategy.

| Class | Detection |
|-------|-----------|
| `auth` | exit 401, 403, text: "Unauthorized", "Forbidden", "token", "credential" |
| `rate_limit` | exit 429, text: "rate limit", "Too Many Requests", "quota exceeded" |
| `network` | text: "ECONNREFUSED", "ENOTFOUND", "ETIMEDOUT", "Network Error", "timeout" |
| `tool` | text: "command not found", "not found" + a CLI name |
| `permission` | text: "Permission denied", "EACCES", "Read-only file system" |
| `git` | text: "CONFLICT", "merge conflict", "detached HEAD", "non-fast-forward" |
| `worktree` | text: "already checked out", "worktree" + "locked", "worktree" + "conflict" |
| `disk` | text: "ENOSPC", "no space left", "disk full" |
| `context` | text: "context length exceeded", "maximum context", "too many tokens" |

If the error matches multiple classes, use the first match in table order.
If no class matches, use the generic strategy.

## Recovery Strategies

### auth — Service Authentication Expired

1. Run `/maestro services health` to identify which service is failing.
2. Log the expired service to `.maestro/logs/self-heal.yaml`.
3. Prompt user: "Your `<service>` token appears expired. Run
   `/maestro connect <service>` to reconnect, then confirm to retry."
4. On confirmation: retry the failed operation once.
5. On failure: escalate with enhanced error (error-enhancer skill).

This strategy does NOT auto-rotate credentials. It detects and surfaces the
issue, then waits for user action.

### rate_limit — API Rate Limited

Exponential backoff:

| Attempt | Wait | Action |
|---------|------|--------|
| 1 | 30s | Wait and retry |
| 2 | 60s | Wait and retry |
| 3 | 120s | Wait and retry |
| 4 | — | Fail — escalate |

Log each backoff to `.maestro/logs/self-heal.yaml` with `strategy: backoff`.
Display countdown:

```
[maestro] (!) Rate limited by <service>. Waiting 30s before retry (1/3)...
```

After 3 backoffs without success, escalate with enhanced error.

### network — Transient Network Error

Retry up to 3 times with 10-second intervals:

| Attempt | Wait | Action |
|---------|------|--------|
| 1 | 10s | Retry |
| 2 | 10s | Retry |
| 3 | 10s | Retry |
| 4 | — | Fail — escalate |

Display:

```
[maestro] (!) Network error. Retrying in 10s (1/3)...
```

If all 3 retries fail, escalate. Include the service's status page URL in
the escalation message if known.

### tool — Missing CLI Tool

1. Identify the missing CLI from the error text.
2. Look up the install command from the error-enhancer pattern database.
3. Display install suggestion:

```
[maestro] (!) Missing CLI: <tool>

  Fix:
    Install: <install command>

  After installing, retry the operation or run:
    /maestro doctor
```

4. Do NOT auto-install. Surface the fix and pause.
5. If a known API-route fallback exists for this CLI (e.g., GitHub API instead
   of `gh`), note it:

```
  (i) Fallback: the GitHub API can be used instead of gh CLI.
      Some features may be limited.
```

### permission — File or Command Permission Error

1. Display the affected path.
2. Suggest the chmod fix:

```
[maestro] (!) Permission denied: <path>

  Fix:
    chmod u+rw <path>

  Then retry.
```

3. Retry the operation once after displaying the suggestion.
4. Do NOT auto-run chmod. The user must apply the fix.

### git — Dirty or Conflicted Git State

1. Run `git status` to assess the current state.
2. If working tree is dirty (uncommitted changes):
   - Run `git stash` to stash changes.
   - Retry the failed operation.
   - After retry (success or fail): run `git stash pop` to restore.
   - Log stash action to `.maestro/logs/self-heal.yaml`.
3. If merge conflict:
   - Do NOT auto-resolve. Escalate immediately with enhanced error.
4. If detached HEAD:
   - Log and escalate with suggested fix: `git checkout <branch>`.

### worktree — Worktree Conflict

1. List all worktrees: `git worktree list`.
2. Identify the conflicting worktree path.
3. Check if it is stale (no process using it):
   - If stale: remove with `git worktree remove --force <path>`.
   - Log removal to `.maestro/logs/self-heal.yaml`.
   - Re-dispatch the operation.
4. If worktree is active: escalate. Do NOT remove an active worktree.

### disk — Out of Disk Space

1. Run `df -h .` to show available space.
2. Identify the largest directories in `.maestro/`:

```
[maestro] (x) Out of disk space

  Available: <X>GB free on <mount>

  Suggested cleanup:
    du -sh .maestro/logs/*   (check log sizes)
    du -sh node_modules/     (check dependencies)

  After freeing space, retry.
```

3. Do NOT auto-delete. Surface the diagnosis and pause.

### context — Context Length Exceeded

1. Log: context overflow during `<operation>`.
2. Apply context reduction:
   - Strip debug logs from the context package.
   - Summarize large files to their key signatures.
   - Remove unchanged file content, keep only diffs.
3. Retry the operation with the reduced context package.
4. If still failing after reduction: escalate.

```
[maestro] (!) Context too large. Reducing context package and retrying...
```

### generic — Unclassified Error

Retry once. If it fails again, escalate via error-enhancer and surface to user.

## Self-Heal Log

All attempts are appended to `.maestro/logs/self-heal.yaml`:

```yaml
heals:
  - timestamp: "2026-03-19T14:10:00Z"
    error_type: auth
    service: vercel
    strategy: reconnect
    result: success
    duration_seconds: 15

  - timestamp: "2026-03-19T14:15:00Z"
    error_type: rate_limit
    service: stripe
    strategy: backoff
    result: success
    retries: 2
    duration_seconds: 90

  - timestamp: "2026-03-19T14:22:00Z"
    error_type: network
    service: aws
    strategy: retry
    result: failed
    retries: 3
    duration_seconds: 30
    escalated: true
```

Fields:

| Field | Description |
|-------|-------------|
| `timestamp` | ISO 8601 UTC |
| `error_type` | Classification from the table above |
| `service` | Service name if known, else `unknown` |
| `strategy` | Which strategy was applied |
| `result` | `success` or `failed` |
| `retries` | Number of retry attempts made |
| `duration_seconds` | Total time spent in recovery |
| `escalated` | `true` if the error was surfaced to the user |

If `.maestro/logs/` does not exist, create it before writing.

## Escalation Message

When all strategies fail, use the error-enhancer skill to produce an
actionable error, then display:

```
+---------------------------------------------+
| Self-heal failed: <error_type>              |
+---------------------------------------------+
  Strategy   <strategy name>
  Attempts   <N>
  Service    <service if known>

  <enhanced error block from error-enhancer>

  Session paused. Resolve the issue above,
  then confirm to continue.
```

## Integration Points

### dev-loop/SKILL.md — Phase 4 (SELF-HEAL)

Replace the existing self-heal phase with this skill. The 3-attempt cap from
dev-loop applies per-story. Self-heal-enhanced applies within each attempt,
so strategies like backoff or stash count as one attempt from dev-loop's
perspective.

### error-enhancer/SKILL.md

Call `error_enhancer.enhance(input)` to produce the fix block in escalation
messages.

### retrospective/SKILL.md

Self-heal log entries map to friction signals:
- `auth` failures → `SERVICE_DRIFT` signal (credentials need refresh)
- `rate_limit` failures → `THROUGHPUT` signal (plan limits reached)
- `context` failures → `CONTEXT_OVERFLOW` signal (story too large)
- `tool` failures → `ENVIRONMENT` signal (missing toolchain)

## Rules

1. Never auto-modify credentials, delete data, or force-push.
2. Always log to `.maestro/logs/self-heal.yaml` before retrying.
3. Respect the dev-loop Phase 4 per-story attempt cap of 3.
4. Display a status line before each retry so the user knows what is happening.
5. Follow output-format/SKILL.md: no emoji, text indicators only.
6. If autonomy mode is `ask`, pause and confirm before any stash or worktree
   removal operation.
