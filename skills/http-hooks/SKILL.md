---
name: http-hooks
description: "HTTP hook endpoint integration. Registers Maestro as a webhook receiver for CI/CD events using Claude Code v2.1 HTTP hooks. Enables GitHub Actions, build pipelines, and monitoring systems to trigger Maestro actions directly over HTTP."
---

# HTTP Hook Endpoint

Claude Code v2.1 supports HTTP hooks alongside shell command hooks. Maestro uses HTTP hooks to expose a live endpoint that CI/CD pipelines, GitHub Actions, and monitoring services can call directly — without a file-based queue intermediary.

## Architecture

```
GitHub Actions / CI Pipeline / Monitoring
    |
    v  POST /hooks/maestro  (HTTP hook endpoint)
    |
    v
Claude Code HTTP Hook Handler
    |
    v
Maestro routes to action (ci-mode, fix story, notify)
```

This complements the file-based `webhooks` skill. Use HTTP hooks when:
- The caller can reach the Claude Code instance directly (local dev, self-hosted runners)
- You need synchronous acknowledgment before the caller times out
- Latency matters more than fire-and-forget reliability

Use the `webhooks` skill's file-based queue when:
- The caller cannot reach Claude Code directly (cloud CI, ephemeral runners)
- You prefer durable queuing over direct connection

## Registering HTTP Hooks

HTTP hooks are registered in `hooks/hooks.json` alongside shell hooks. Use `type: "http"` with a `url` field:

```json
{
  "hooks": {
    "HttpRequest": [
      {
        "name": "ci-failure-handler",
        "type": "http",
        "url": "http://localhost:9877/hooks/maestro",
        "matcher": {
          "source": "ci",
          "event": "build.failed"
        },
        "handler": "skills/http-hooks/handlers/ci-failure.md",
        "timeout_ms": 30000
      },
      {
        "name": "github-pr-handler",
        "type": "http",
        "url": "http://localhost:9877/hooks/maestro",
        "matcher": {
          "source": "github",
          "event": "pull_request.*"
        },
        "handler": "skills/http-hooks/handlers/github-pr.md",
        "timeout_ms": 30000
      }
    ]
  }
}
```

### Hook Registration Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier for this hook registration |
| `type` | Yes | Must be `"http"` for HTTP hooks |
| `url` | Yes | Endpoint Claude Code exposes for this hook |
| `matcher.source` | No | Filter by event source (`github`, `ci`, `monitoring`) |
| `matcher.event` | No | Filter by event type, supports glob (`build.*`) |
| `handler` | Yes | Path to the skill file handling this event |
| `timeout_ms` | No | Max time to process before returning 200 (default: 30000) |

## Inbound Request Format

Callers POST JSON to the registered URL. The envelope format:

```json
{
  "source": "github",
  "event": "pull_request.opened",
  "id": "evt_20260318_001",
  "timestamp": "2026-03-18T10:30:00Z",
  "signature": "sha256=abc123...",
  "payload": {
    "pr_number": 47,
    "title": "Add payment gateway",
    "branch": "feat/payments",
    "author": "rodrigo",
    "repo": "myorg/myapp",
    "base_branch": "main"
  }
}
```

### Response

The hook handler must return a response within `timeout_ms`. Return HTTP 200 with a JSON body:

```json
{
  "received": true,
  "action": "story_created",
  "story_id": "fix-ci-payments-001",
  "message": "Created fix story for failing payment tests"
}
```

Return HTTP 400 for rejected requests (bad signature, missing fields). Return HTTP 200 immediately for events you're ignoring — do not let the caller timeout.

## Security

### Webhook Signature Verification

All inbound HTTP hook requests must be verified before processing. Maestro checks the `X-Hub-Signature-256` header (GitHub) or `X-Maestro-Signature` (custom callers) against a shared secret.

Verification algorithm (HMAC-SHA256):

```
expected = HMAC-SHA256(secret, raw_request_body)
actual   = request.headers["X-Hub-Signature-256"].removePrefix("sha256=")
reject if expected != actual (constant-time comparison)
```

Configure the shared secret in `.maestro/config.yaml`:

```yaml
http_hooks:
  security:
    signature_secret: null     # set to your shared secret — never commit this
    verify_signatures: true    # set false only for local development
```

**Never disable signature verification in production.** GitHub and most CI systems support HMAC-SHA256 webhook signatures natively.

### Allowed Origins

Restrict which IP addresses or hostnames can send hook requests:

```yaml
http_hooks:
  security:
    allowed_origins:
      - "192.30.252.0/22"     # GitHub Actions IP range
      - "185.199.108.0/22"    # GitHub Actions IP range
      - "127.0.0.1"           # local development
    reject_unknown_origins: true
```

If `allowed_origins` is empty and `reject_unknown_origins` is false, all origins are accepted (development default). In production, always set explicit allowed origins.

### Rate Limiting

Prevent abuse from runaway pipelines or mis-configured callers:

```yaml
http_hooks:
  security:
    rate_limit:
      requests_per_minute: 60
      burst: 10
      per_source: true       # separate limit per source IP
```

When the rate limit is exceeded, return HTTP 429 with a `Retry-After` header. Log the rejection to `.maestro/logs/http-hooks.log`.

### Secrets — Never Elicit, Never Log

- Never log the signature secret or request body in full to `.maestro/logs/`
- Log only: timestamp, source, event type, action taken, status code
- Do not expose the signing secret in CI job output or config committed to git

## Use Cases

### GitHub Actions → Maestro on CI Failure

A GitHub Actions workflow posts to Maestro when tests fail, triggering automatic story creation:

**GitHub Actions workflow step:**

```yaml
- name: Notify Maestro on failure
  if: failure()
  run: |
    curl -X POST http://localhost:9877/hooks/maestro \
      -H "Content-Type: application/json" \
      -H "X-Hub-Signature-256: sha256=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$MAESTRO_SECRET" | awk '{print $2}')" \
      -d '{
        "source": "ci",
        "event": "build.failed",
        "payload": {
          "build_id": "${{ github.run_id }}",
          "branch": "${{ github.ref_name }}",
          "workflow": "${{ github.workflow }}",
          "error_summary": "Test suite failed",
          "logs_url": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
        }
      }'
  env:
    MAESTRO_SECRET: ${{ secrets.MAESTRO_WEBHOOK_SECRET }}
```

**Maestro handler behavior:**

On receiving `ci/build.failed`:
1. Parse the failing branch and error summary from the payload
2. Search `.maestro/stories/` for an open fix story for this branch — skip creation if one exists
3. Create `.maestro/stories/fix-ci-[branch]-[run_id].md` with:
   - Title: "Fix CI failure on [branch]"
   - Acceptance criteria extracted from the error summary
   - Link to the GitHub Actions run URL
4. If `ci-mode` is active, route directly to the implementer agent
5. If interactive, surface a checkpoint prompt: `(!) CI failure on [branch]. Auto-create fix story? [Y/n]`
6. Return `{"received": true, "action": "story_created", ...}`

### CI Build Completion → Maestro State Update

When a build passes, Maestro can update project state and notify:

```json
{
  "source": "ci",
  "event": "build.passed",
  "payload": {
    "build_id": "run-456",
    "branch": "main",
    "duration_ms": 94000,
    "tests_passed": 142
  }
}
```

Handler: log to `.maestro/notes.md`, update last-known-good build in `.maestro/state.md`, trigger notify skill if `ci_notifications: true`.

### GitHub PR Events → Kanban Sync

On `pull_request.opened` or `pull_request.merged`, Maestro can sync the kanban board:

```json
{
  "source": "github",
  "event": "pull_request.merged",
  "payload": {
    "pr_number": 47,
    "branch": "feat/payments",
    "merged_by": "rodrigo"
  }
}
```

Handler: delegate to kanban skill to move the corresponding issue to "Done". Log to `audit-log`.

## Event Routing Table

| Source | Event | Default Action |
|--------|-------|----------------|
| `github` | `pull_request.opened` | Log, kanban sync (if enabled) |
| `github` | `pull_request.merged` | Log, kanban → Done |
| `github` | `push` | Log, awareness check |
| `ci` | `build.failed` | Create fix story, notify |
| `ci` | `build.passed` | Log, update state.md |
| `ci` | `deploy.completed` | Notify, post-deploy checks |
| `ci` | `deploy.failed` | Notify (alert), create fix story |
| `monitoring` | `alert.triggered` | Notify (critical), create fix story |
| `monitoring` | `alert.resolved` | Notify (resolved) |

Override routing in `.maestro/config.yaml`:

```yaml
http_hooks:
  routes:
    github:
      pull_request.opened: kanban_sync
      pull_request.merged: kanban_done
    ci:
      build.failed: create_fix_story
      build.passed: log_only
    monitoring:
      alert.triggered: create_fix_story_and_notify
```

## Configuration

Full config block in `.maestro/config.yaml`:

```yaml
http_hooks:
  enabled: false
  port: 9877
  bind: "127.0.0.1"    # never bind to 0.0.0.0 unless behind a reverse proxy

  security:
    signature_secret: null       # set via environment variable, never commit
    verify_signatures: true
    allowed_origins: []
    reject_unknown_origins: false
    rate_limit:
      requests_per_minute: 60
      burst: 10
      per_source: true

  routes:
    github:
      pull_request.opened: kanban_sync
      pull_request.merged: kanban_done
      push: log
    ci:
      build.failed: create_fix_story
      build.passed: log
      deploy.completed: notify
      deploy.failed: create_fix_story
    monitoring:
      alert.triggered: create_fix_story_and_notify
      alert.resolved: notify

  logging:
    file: ".maestro/logs/http-hooks.log"
    level: info            # info | debug | warn | error
```

## Integration with Other Skills

### webhooks skill

The HTTP hooks skill and `webhooks` skill share the same event routing table and handler logic. HTTP hooks bypass the file queue — events are processed synchronously in the request/response cycle rather than on the next poll interval.

When both are configured, HTTP hooks take precedence for sources that can reach the endpoint. The file queue remains the fallback for sources that cannot.

### ci-mode skill

When `MAESTRO_CI=true`, HTTP hook handlers run in headless mode: no checkpoint prompts, no interactive confirmations. Fix stories are created and queued automatically. The handler returns immediately with the action taken.

### notify skill

HTTP hook handlers delegate to the `notify` skill for all outbound notifications. `ci_notifications` must be `true` for notifications to fire in CI mode.

## Error Handling

| Error | Action |
|-------|--------|
| Bad signature | Return HTTP 400, log rejection |
| Unknown event type | Return HTTP 200, log as unrouted |
| Rate limit exceeded | Return HTTP 429 with Retry-After |
| Handler timeout | Return HTTP 200, log timeout, continue async |
| Origin rejected | Return HTTP 403, log rejection |
| Duplicate event ID | Return HTTP 200, skip processing (idempotent) |

Log all errors to `.maestro/logs/http-hooks.log`. Never return HTTP 500 — callers treat 5xx as a delivery failure and will retry.
