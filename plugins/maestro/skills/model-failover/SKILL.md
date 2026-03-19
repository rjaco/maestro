---
name: model-failover
description: "Graceful API failure handling with exponential backoff and tier escalation. Retries failed dispatches 3x with 1s/3s/9s backoff, escalates through haiku→sonnet→opus tiers on exhaustion, and logs all failures to .maestro/logs/model-failures.md. Serves as the future routing layer when Claude Code supports multiple providers."
---

# Model Failover

Handles API failures gracefully so sessions survive transient errors without user intervention. Primary model is Claude (haiku/sonnet/opus) via Claude Code's native model parameter. When a dispatch fails, this skill retries with exponential backoff, escalates through model tiers on exhaustion, and surfaces unrecoverable failures to the user.

## Model Tiers

Tiers define the escalation path. Escalation is one-directional — never downgrade during a failover sequence.

| Tier | Model | Role |
|------|-------|------|
| 1 (cheapest) | `haiku` | Fast, low-cost tasks |
| 2 (default) | `sonnet` | Standard development work |
| 3 (most capable) | `opus` | Complex, ambiguous, high-stakes stories |

The tier assigned by model-router determines the starting tier. Failover begins at that tier and escalates upward.

## Retry Behavior

On any dispatch failure, attempt retries before tier escalation.

### Retry Schedule

```
attempt 1: immediate (the original call)
attempt 2: wait 1s
attempt 3: wait 3s
attempt 4: wait 9s
→ all 3 retries exhausted → tier escalation
```

Three retries total after the initial failure. If all three retries fail on the same tier, escalate to the next tier and reset the retry counter.

### Rate Limit Handling (429)

When a 429 response is received:

1. Read the `Retry-After` header if present. Back off for exactly that duration.
2. If `Retry-After` is absent, use the standard exponential schedule.
3. Count a 429 as a retry attempt — it consumes one slot in the 3-attempt budget.
4. Log the rate limit event to `.maestro/logs/model-failures.md` with the back-off duration.

Do not treat 429 as a permanent failure. It is expected under heavy load and resolves with patience.

### Retryable vs Non-Retryable Errors

| Error Class | Action |
|-------------|--------|
| Timeout | Retry with backoff |
| 429 Rate limit | Retry after `Retry-After` or backoff |
| 5xx Server error | Retry with backoff |
| 401 Authentication failure | Do NOT retry — PAUSE immediately and surface to user |
| 400 Bad request | Do NOT retry — the prompt itself is malformed; report BLOCKED |
| Context window exceeded | Do NOT retry — escalate tier only if the next tier supports larger context |

## Tier Escalation

When all retries on a tier are exhausted:

```
starting tier: sonnet (as assigned by model-router)
  → all retries fail → escalate to opus
  → all retries fail → PAUSE and surface to user
```

If the starting tier is already opus, there is no escalation path. Retry opus 3 times, then PAUSE.

Escalation does not reset the retry-after delay for a 429 — the back-off period must still elapse before dispatching to the next tier.

### Escalation Log Entry

Before dispatching to the next tier, write:

```
[ISO timestamp] tier-escalation
  from: sonnet  to: opus
  story: [story_id]
  cause: retry-exhausted (3 attempts, server_error)
  retries: [attempt 1: timeout 30s], [attempt 2: 500], [attempt 3: 500]
```

## Failure Surface Format

When all tiers are exhausted (or a non-retryable error occurs), PAUSE and present:

```
Model Failover: Unrecoverable failure
Story:      [story_id] — [story title]
Last model: [model]
Error:      [error type] — [last error message]
Attempts:   [N] total ([tier1 retries] on [model1], [tier2 retries] on [model2])
Duration:   [total elapsed seconds]

Options:
  [1] Retry now (will start from the original tier)
  [2] Skip this story and continue
  [3] Abort session
```

Do not surface partial or intermediate failures. The user sees only the final unrecoverable state.

## Failure Log Format

All failures, retries, rate limits, and tier escalations are appended to `.maestro/logs/model-failures.md`.

```markdown
## Failure Log

### [ISO timestamp] [model: sonnet] [story: 03-auth-login]
- **Type**: timeout
- **Attempt**: 2 of 3 (retry in 3s)
- **Error**: Request exceeded 120s timeout
- **Outcome**: retrying

### [ISO timestamp] [model: sonnet] [story: 03-auth-login]
- **Type**: retry-exhausted
- **Attempts**: 3
- **Outcome**: escalating to opus

### [ISO timestamp] [model: opus] [story: 03-auth-login]
- **Type**: 429 rate-limit
- **Retry-After**: 45s
- **Attempt**: 1 of 3
- **Outcome**: backing off 45s
```

One entry per event (not per story). This produces a complete timeline of model interactions.

## Trust Tracking

After each completed story (success or failover), update `model_reliability` in `.maestro/trust.yaml`:

```yaml
model_reliability:
  haiku:
    total_dispatches: 14
    failures: 2
    retries: 4
    escalations_out: 1       # times a story left haiku due to failover
    escalations_in: 0        # times a story arrived at haiku via escalation (rare)
    reliability_pct: 85.7
  sonnet:
    total_dispatches: 28
    failures: 1
    retries: 2
    escalations_out: 0
    escalations_in: 1
    reliability_pct: 96.4
  opus:
    total_dispatches: 6
    failures: 0
    retries: 0
    escalations_out: 0
    escalations_in: 0
    reliability_pct: 100.0
```

Recalculate `reliability_pct` after each update: `(total_dispatches - failures) / total_dispatches * 100`.

### Reliability Feedback to Model Router

If any model's `reliability_pct` drops below 70% in the last 10 dispatches, bias model-router away from that model by treating its current score as if it were 3 points higher (pushing more stories to the next tier). Log this adjustment:

```
model-failover: haiku reliability dropped to 60% (last 10 dispatches)
Applying +3 score bias to model-router for haiku tier
```

Remove the bias when reliability recovers above 80%.

## State Tracking

Store active failover state in `.maestro/state.local.md` under the `failover:` key:

```yaml
failover:
  active: true
  story: "03-auth-login"
  starting_model: sonnet
  current_model: sonnet
  attempt: 2
  tier_attempts: 2           # attempts consumed on current tier
  elapsed_seconds: 7
  last_error: "timeout"
  status: retrying           # retrying | escalating | paused
```

Clear `failover.active` to `false` on story completion (success or user resolution). Preserve `last_error` and `current_model` for the failure log entry.

## Future: Multi-Provider Support

This skill is designed to become the routing layer when Claude Code supports multiple AI providers. When that capability is available:

- Expand the tier model to include providers: `claude-haiku → claude-sonnet → claude-opus → gpt-4o → gemini-pro → local-ollama`
- Failover across providers follows the same exponential backoff and escalation logic
- `trust.yaml` gains provider-level reliability tracking
- The `Retry-After` header behavior applies per-provider
- Provider-specific error codes (OpenAI, Gemini, Ollama) are normalized to the same retryable/non-retryable classification above

No changes to the core algorithm are needed — only the tier table and error normalization layer expand.

## Integration Points

| Skill | Integration |
|-------|-------------|
| **model-router** | model-failover reads the initial model assignment from model-router. On reliability drop, feeds the +3 bias signal back to model-router. |
| **delegation** | delegation calls model-failover before every agent dispatch. On PAUSE, delegation halts the current story and surfaces the user-facing options block. |
| **doom-loop** | doom-loop `StopFailure` hook increments `doom_loop.count` on API failures. model-failover and doom-loop are independent guards — both can fire on the same failure. |
| **audit-log** | Every tier escalation and PAUSE is logged to `.maestro/logs/decisions.md` as a `model_failover` entry alongside the model-router `model_selection` entry for the same story. |
| **retrospective** | Retrospective reads `model_reliability` from `trust.yaml` to report failover rates per tier. Persistent reliability below 80% on any tier triggers an improvement candidate. |
