---
name: autonomy-engine
description: "Classify actions by risk tier, enforce spending limits, and route T2/T3 actions through the approval flow before execution. Integrates with notify skill for multi-channel approval delivery."
---

# Autonomy Engine

Decide whether an action can run automatically or must be approved before execution. Every external action passes through this skill before it is dispatched.

## Action Tiers

Every external action falls into one of three tiers:

| Tier | Name | Approval Policy |
|------|------|-----------------|
| T1 — Free | Read-only operations: list, describe, get, show, status, health, check | Always auto-approve |
| T2 — Reversible-paid | Creates, starts, deploys, updates — can be undone but may cost money | Auto under spending limit |
| T3 — Irreversible | Deletes, purchases, sends, posts — cannot be undone | Depends on autonomy mode |

## Autonomy Modes

| Mode | T1 | T2 | T3 |
|------|----|----|-----|
| `full-auto` | Auto | Auto | Auto |
| `tiered` | Auto | Auto under `per_action` limit | Confirm |
| `manual` | Auto | Confirm | Confirm |

Read the current mode from `.maestro/config.yaml` under `autonomy.mode`. Default to `tiered` if not set.

## Step 1: Classify the Action

Read `skills/autonomy-engine/action-classifications.md` to look up the service and operation.

**Classification algorithm:**

1. Identify the service name (aws, cloudflare, vercel, namecheap, sendgrid, twilio, stripe, twitter, browser, or other).
2. Match the operation verb against that service's free / reversible_paid / irreversible lists.
3. If the service is not listed, apply general heuristics:
   - Verbs `list`, `get`, `show`, `describe`, `check`, `status`, `inspect`, `whoami`, `fetch`, `read`, `navigate`, `screenshot` → T1
   - Verbs `create`, `start`, `run`, `launch`, `deploy`, `update`, `add`, `set`, `buy number`, `fill`, `follow`, `like` → T2
   - Verbs `delete`, `remove`, `destroy`, `terminate`, `purge`, `send`, `post`, `tweet`, `reply`, `dm`, `submit`, `purchase`, `register`, `release`, `refund`, `charge`, `transfer` → T3
4. When in doubt, escalate to the higher tier.

Record: `{ service, operation, tier, estimated_cost }`.

## Step 2: Check Autonomy Mode

Read `.maestro/config.yaml`:

```yaml
autonomy:
  mode: tiered              # full-auto | tiered | manual
  spending:
    per_action: 50           # dollars — auto-approve T2 under this amount
    per_session: 500         # dollars — pause when reached
    per_day: 1000            # dollars — hard stop when reached
  notification_level: all   # all | important | critical | none
```

Apply the mode rules:

- **full-auto:** Approve all tiers automatically. Log every action. Skip approval UI.
- **tiered:**
  - T1: Auto-approve.
  - T2: Auto-approve if `estimated_cost <= per_action` AND `session_total + cost <= per_session` AND `day_total + cost <= per_day`. Otherwise require approval.
  - T3: Always require approval.
- **manual:**
  - T1: Auto-approve.
  - T2 and T3: Always require approval.

## Step 3: Check Spending Limits

Read `.maestro/spending-log.yaml`. If the file does not exist, treat all totals as 0.

```yaml
spending:
  session_total: 45.50
  day_total: 120.00
  last_reset: "2026-03-19"
  actions: []
```

**Day reset:** If `last_reset` is not today's date, reset `day_total` to 0 and update `last_reset`.

**Alert thresholds:**

- If `session_total >= 0.8 * per_session`: warn "Session spending at 80% of limit."
- If `day_total >= 0.8 * per_day`: warn "Daily spending at 80% of limit."

**Hard stops:**

- If `session_total >= per_session`: Block execution. Notify the user that the session spending limit has been reached. Do not proceed.
- If `day_total >= per_day`: Block execution. Notify the user that the daily spending limit has been reached. Do not proceed.

## Step 4: Show Approval UI (when required)

When an action requires human approval, display:

```
╔══════════════════════════════════════════════════╗
║  APPROVAL REQUIRED                               ║
╠══════════════════════════════════════════════════╣
║  Service:  [service name]                        ║
║  Action:   [human-readable action description]   ║
║  Cost:     [estimated cost or "free"]            ║
║  Risk:     [REVERSIBLE | IRREVERSIBLE]           ║
╠══════════════════════════════════════════════════╣
║  [A] Approve    [D] Deny    [S] Skip             ║
╚══════════════════════════════════════════════════╝
```

Send the same approval request to all configured notification channels (see notify skill). Include: service, action description, estimated cost, risk tier, and a note that CLI approval is also available.

Use AskUserQuestion:
- Question: "Approve this action?"
- Header: "Action Approval"
- Options:
  1. label: "Approve", description: "Execute the action"
  2. label: "Deny", description: "Block the action and do not proceed"
  3. label: "Skip", description: "Skip this action and continue with the next step"

Accept the response from whichever channel replies first (CLI or notification channel).

**On Approve:** Proceed. Record `approved_by: user`.
**On Deny:** Block execution. Log the denial. Report to the caller that the action was denied by the user.
**On Skip:** Skip the action. Log it as skipped. Continue the workflow without this action.

## Step 5: Execute and Record

After approval (auto or user), record the action in `.maestro/spending-log.yaml`:

```yaml
actions:
  - timestamp: "2026-03-19T14:00:00Z"
    service: namecheap
    action: "domain purchase: myapp.com"
    amount: 12.99
    tier: T3
    approved_by: user   # or "auto"
```

Update `session_total` and `day_total` by adding `amount`.

Write the updated file back to `.maestro/spending-log.yaml`.

## Spending Log Schema

```yaml
spending:
  session_total: 0.00        # cumulative cost this session
  day_total: 0.00            # cumulative cost today (resets at midnight)
  last_reset: "2026-03-19"   # ISO date of last day_total reset
  actions:
    - timestamp: ""          # ISO 8601 datetime
      service: ""            # service name
      action: ""             # human-readable description
      amount: 0.00           # cost in USD
      tier: ""               # T1, T2, or T3
      approved_by: ""        # "auto" or "user"
```

## Cost Anomaly Detection

Monitor per-story costs against estimates and flag anomalies.

### Detection Logic

After each story completes (Phase 7 CHECKPOINT):
1. Read story's `estimated_tokens` from the story spec
2. Read actual tokens from `token_ledger` or state
3. Compute ratio: `actual / estimated`
4. If ratio > 2.0: FLAG as cost anomaly

### Anomaly Response

| Ratio | Severity | Action |
|-------|----------|--------|
| <= 1.5x | Normal | Log only |
| 1.5x - 2.0x | Warning | Log + note in checkpoint summary |
| 2.0x - 3.0x | Anomaly | Log + alert + add to spending-log.yaml |
| > 3.0x | Critical | Log + alert + PAUSE if in checkpoint mode |

### Anomaly Log Format

Append to `.maestro/logs/spending-log.yaml`:
```yaml
anomalies:
  - story: "03-frontend-ui"
    timestamp: "2026-03-19T10:30:00Z"
    estimated_tokens: 15000
    actual_tokens: 48000
    ratio: 3.2
    severity: critical
    model: opus
    reason: "QA rejected 3 times, required model escalation"
```

### Root Cause Analysis

When an anomaly is detected, identify likely causes:
- **QA rejection loops**: Multiple QA iterations drive up cost
- **Model escalation**: haiku→sonnet→opus cascades
- **Context tier escalation**: T3→T2→T1 due to NEEDS_CONTEXT
- **Large file reads**: Agent reading unnecessary files
- **Self-heal loops**: Multiple fix attempts

Log the identified cause with the anomaly.

### Spending Dashboard Integration

Show anomalies in `/maestro dashboard`:
```
Cost Anomalies (this session):
  (!) Story 03: 3.2x over estimate (48K vs 15K tokens) — QA loops
  (!) Story 07: 2.1x over estimate (21K vs 10K tokens) — model escalation
```

## Integration with Other Skills

- **dev-loop / opus-loop:** Call this skill before dispatching any action to an external service.
- **notify skill:** Used in Step 4 to fan out approval requests to all configured channels.
- **`/maestro autonomy`:** The command at `commands/autonomy.md` provides the UI for reading and changing mode and limits.

## Error Handling

- If `.maestro/config.yaml` is missing or the `autonomy` section is absent, default to `tiered` mode with limits: per_action $50, per_session $500, per_day $1000.
- If the spending log cannot be written, log the failure but do not block execution — spending tracking is best-effort; safety approvals are not.
- If a notification channel fails to send the approval request, fall back to CLI approval only. Never block on notification failure.
- Never allow an unclassified action to silently auto-approve at T1. When classification is uncertain, escalate the tier.
