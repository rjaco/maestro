---
name: graceful-degradation
description: "Continue execution with reduced capability when a service or tool is unavailable. Defines degradation rules per capability, displays a capability status summary, and logs all degradations to .maestro/logs/degradation.yaml."
---

# Graceful Degradation

When a capability is unavailable, continue with reduced functionality rather
than failing. Surfaces a clear status summary so the user knows what is and
is not available before execution proceeds.

## Capability Registry

Each capability has a degradation rule that defines the fallback and the
notification shown to the user.

| Capability | Unavailable When | Degradation | Notification |
|------------|-----------------|-------------|--------------|
| Notification channel | Webhook/token missing or returns error | Log locally, skip remote notification | `(i) Telegram unavailable — logging locally` |
| Vercel | Auth error or CLI missing | Try Cloudflare Pages if configured | `(i) Vercel down — trying Cloudflare Pages` |
| Cloudflare Pages | Auth error or CLI missing | Skip deployment, log for later | `(i) Cloudflare Pages unavailable — deploy skipped` |
| DNS service | Auth error or API unavailable | Save changes to `.maestro/logs/dns-pending.yaml`, apply later | `(i) DNS service offline — changes queued for later` |
| Browser automation | Playwright not installed | Output manual steps | `(i) Browser not available — manual steps below` |
| Spending tracker | Config missing or token-ledger not configured | Continue without tracking, warn user | `(!) Spending not tracked — config missing` |
| Health check | Service returns non-2xx or times out | Mark as degraded, use cached status | `(!) <service> health check failed — using cached status` |
| GitHub CLI | `gh` not installed | Use GitHub API via curl | `(i) gh CLI not found — using GitHub API directly` |
| Telegram | Bot token missing or invalid | Skip Telegram, try other notify providers | `(i) Telegram unavailable — logging locally` |
| AWS | Credentials expired or CLI missing | Log planned actions, skip execution | `(!) AWS unavailable — actions logged, not applied` |

## Capability Status

Before beginning an operation that depends on multiple capabilities, check
each and build a status summary.

### Status Levels

| Level | Indicator | Meaning |
|-------|-----------|---------|
| `ok` | `(ok)` | Fully available and verified |
| `degraded` | `(!)` | Available but with limitations |
| `offline` | `(x)` | Completely unavailable |
| `unknown` | `--` | Not checked yet |

### Status Display

```
[maestro] (i) Running with reduced capabilities:
  (ok) Core development      — fully available
  (ok) AWS                   — connected
  (!)  Vercel                — degraded (auth error)
  (x)  Telegram              — offline
  (x)  Stripe                — not configured

  2 capabilities degraded. Continuing with available services.
  Some actions may require manual steps.
```

Display this summary:
- At session start if any capability is degraded or offline
- Before any operation that uses a degraded capability
- After `/maestro doctor`

## Degradation Rules

### Notification Channel Degraded

When all configured notification providers fail:

```
[maestro] (i) Notification channel unavailable — logging locally

  Events will be written to .maestro/logs/notifications-local.log
  instead of being sent remotely.
```

Write the event as a timestamped line:

```
2026-03-19T14:10:00Z | story_complete | Story 3/5: API Routes | QA approved
```

### Cloud Provider Fallback

When the primary deploy target is unavailable:

1. Check if an alternative provider is configured with equivalent capability.
2. If yes: attempt the operation on the alternative provider.
3. Notify:

```
[maestro] (i) Vercel unavailable — trying Cloudflare Pages

  Primary:     Vercel (auth error)
  Fallback:    Cloudflare Pages

  Deploying to Cloudflare Pages...
```

4. If alternative also fails: skip deployment, log intent.
5. If no alternative configured: skip deployment, log intent.

### DNS Service Offline

When DNS updates cannot be applied:

1. Write the intended changes to `.maestro/logs/dns-pending.yaml`:

```yaml
pending:
  - timestamp: "2026-03-19T14:00:00Z"
    service: cloudflare-dns
    domain: example.com
    record_type: CNAME
    record_name: app
    record_value: my-project.vercel.app
    reason_deferred: "DNS service offline"
```

2. Notify:

```
[maestro] (i) DNS service offline — 1 change queued for later

  Changes saved to .maestro/logs/dns-pending.yaml
  Apply when DNS is available: /maestro dns apply-pending
```

### Browser Automation Unavailable

When Playwright is not installed or the browser cannot launch:

1. Output manual steps in place of automation:

```
[maestro] (i) Browser automation unavailable

  Manual steps:
    1. Open: https://example.com
    2. Click "Settings" > "Deploy Hooks"
    3. Copy the webhook URL
    4. Paste it into .maestro/services.yaml under vercel.webhook_url
```

2. Continue with the rest of the operation.

### Spending Tracker Not Configured

When the token-ledger skill cannot record costs:

```
[maestro] (!) Spending not tracked — config missing

  To enable tracking:
    Run: /maestro setup
    Then configure token_ledger in .maestro/config.yaml

  Costs will not be recorded for this session.
```

Continue normally. This is informational only — do not block.

### Health Check Failed

When a service health check returns a non-2xx response or times out:

1. Mark the service as `degraded` in the capability registry.
2. Use the last known good status (from `.maestro/logs/degradation.yaml`).
3. Do not block the operation.
4. Notify:

```
[maestro] (!) AWS health check failed — continuing with cached status

  Last verified: 2026-03-18T09:00:00Z
  Cached status: ok

  If AWS is actually down, operations may fail.
  Run /maestro services health to recheck.
```

## Degradation Log

All degradations are appended to `.maestro/logs/degradation.yaml`:

```yaml
degradations:
  - timestamp: "2026-03-19T14:00:00Z"
    capability: vercel
    status: degraded
    reason: "401 Unauthorized"
    fallback: cloudflare-pages
    fallback_result: success

  - timestamp: "2026-03-19T14:05:00Z"
    capability: telegram
    status: offline
    reason: "Bot token not configured"
    fallback: local-log
    fallback_result: success

  - timestamp: "2026-03-19T14:10:00Z"
    capability: dns-service
    status: offline
    reason: "ECONNREFUSED"
    fallback: deferred
    fallback_result: queued
```

Fields:

| Field | Description |
|-------|-------------|
| `timestamp` | ISO 8601 UTC |
| `capability` | Capability name from the registry |
| `status` | `degraded` or `offline` |
| `reason` | Error that caused the degradation |
| `fallback` | Strategy applied (`<provider>`, `local-log`, `deferred`, `manual`, `skipped`) |
| `fallback_result` | `success`, `failed`, or `queued` |

If `.maestro/logs/` does not exist, create it before writing.

## Capability Check Algorithm

Run checks in parallel. For each capability:

1. Attempt a lightweight probe (health endpoint, `--version` call, or config
   presence check).
2. Timeout after 5 seconds.
3. Record the result in the capability registry.
4. Apply the degradation rule if the probe fails.

The check is read-only. Never modify state during a capability check.

## Integration Points

### dev-loop/SKILL.md — Phase 1 (VALIDATE)

Run capability checks for all services referenced in the story spec. If any
are degraded, display the status summary before Phase 2 (DELEGATE). Do not
block execution unless the story requires a capability that is `offline` with
no fallback.

### notify/SKILL.md

When a notification provider fails, graceful-degradation handles the local-log
fallback. The notify skill calls `degradation.mark(capability, reason)` instead
of raising an error.

### self-heal-enhanced/SKILL.md

After self-heal exhausts strategies for a service, mark the service as
`degraded` in the capability registry so subsequent operations can skip it or
use a fallback automatically.

### retrospective/SKILL.md

Degradation log entries map to friction signals:
- Multiple `degraded` entries for the same capability → `SERVICE_INSTABILITY`
- Entries with `fallback_result: failed` → `NO_FALLBACK` signal

## Rules

1. Never raise an unhandled error for a degraded capability — always apply
   the fallback first.
2. Always log to `.maestro/logs/degradation.yaml` before continuing.
3. Display the capability status summary before any multi-service operation.
4. Do not retry health checks more than once per session unless the user
   explicitly asks.
5. Follow output-format/SKILL.md: no emoji, text indicators only.
6. Keep degradation notifications to one line unless manual steps are needed.
7. The dev-loop must continue unless the required capability has no fallback
   and no manual alternative.
