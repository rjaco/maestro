---
name: rollback-engine
description: "Rollback engine for task chains. Reverses completed steps in reverse order when a chain step fails. Part of the task-chain skill."
---

# Rollback Engine

When a task chain step fails, the rollback engine reverses all previously completed steps in reverse order of completion. This is a sub-component of the task-chain skill — it is not invoked directly by users.

## Trigger Conditions

The rollback engine is triggered when:

1. A step exits with a non-zero status or reports an error
2. A step times out (default timeout: 5 minutes per step)
3. An approval for a T3 step is denied mid-chain (user aborts)
4. The `/maestro chain abort` command is issued while a chain is running

## Rollback Algorithm

```
On failure at step FAILED_STEP:

1. Log failure:
   - Step ID, service, action
   - Error message / exit code
   - Timestamp

2. Identify completed steps:
   - All steps whose status is "done" in chain state
   - Sorted in reverse completion order

3. For each completed step (reverse order):
   a. Check rollback field:
      - If rollback is null: skip, log "cannot rollback (irreversible)"
      - If rollback is a string: execute the rollback action
   b. Mark step status as "rolling-back"
   c. Invoke the service skill with the rollback instruction
   d. If rollback succeeds: mark status "rolled-back", send receipt
   e. If rollback fails: log failure, mark status "rollback-failed", continue

4. Generate rollback summary

5. Send rollback notification to all channels

6. Write final chain state to .maestro/logs/chains/<name>-<timestamp>.yaml
```

## Rollback Display

```
Rollback triggered at step: deploy-app (exit code 1)
Error: Build failed — missing environment variable NEXT_PUBLIC_API_URL
═══════════════════════════════════════════════════
Rolling back completed steps in reverse order...

  rolling-back  setup-dns     Deleting DNS zone for myapp.com...   done
  cannot-undo   buy-domain    Cannot rollback (irreversible)        logged

Rollback complete. 1 of 2 steps reversed.
1 step cannot be rolled back (irreversible purchase).

Notification sent to all channels.
```

Rollback status icons:
- `rolling-back` → in progress
- `done` → successfully reversed
- `cannot-undo` → `rollback: null`, skipped with log entry
- `failed` → rollback action itself failed

## Rollback State Tracking

Update `.maestro/chains/<chain-name>.state.yaml` throughout rollback:

```yaml
chain: "Launch myapp.com"
status: rolling-back
failed_step: deploy-app
failure_reason: "Build failed — missing environment variable NEXT_PUBLIC_API_URL"
failed_at: "2026-03-19T14:01:33Z"
rollback_log:
  - step: setup-dns
    rollback_action: "Delete DNS zone for myapp.com"
    status: rolled-back
    completed_at: "2026-03-19T14:01:40Z"
  - step: buy-domain
    rollback_action: null
    status: cannot-rollback
    reason: "irreversible purchase"
    logged_at: "2026-03-19T14:01:41Z"
rollback_completed_at: "2026-03-19T14:01:41Z"
```

## Rollback Notification

After rollback completes, send a notification via the notify skill:

Event type: `chain_rollback_complete`

```
[Maestro Chain] Launch myapp.com — FAILED + rolled back
Failed at: deploy-app (Build failed)
Rolled back: 1 step | Cannot undo: 1 step (buy-domain — purchase)
Time elapsed before failure: 33s | Cost incurred: $12.99 (non-recoverable)
```

## Rules

**Execution order**: Always reverse chronological. If step A completed before step B, roll back B before A.

**Irreversible steps**: Steps with `rollback: null` are skipped. They are logged with reason "irreversible" and included in the summary. A domain purchase, a sent email, or a public post cannot be undone — the user is notified that manual review may be needed.

**Failed rollbacks**: If a rollback step itself fails, log the failure, mark it `rollback-failed`, and continue with the remaining rollbacks. Never let a failed rollback block other rollbacks.

**Partial rollback notification**: If some rollbacks cannot complete (either irreversible or rollback-failed), the notification explicitly lists what was NOT reversed so the user can act manually.

**Receipt per rollback step**: Each rollback step sends its own action receipt to the notification hub (at a lower severity than the failure notification).

**Concurrent rollbacks**: Rollback runs sequentially (never in parallel) to avoid ordering conflicts between services.

## Rollback Summary Format

```
Chain Rollback Summary: Launch myapp.com
═══════════════════════════════════════════════════
Failure at:    deploy-app (Build error)
Failed at:     2026-03-19T14:01:33Z
Rollback time: 8s

Results:
  setup-dns     rolled-back   DNS zone deleted
  buy-domain    cannot-undo   Domain purchase is irreversible — manual action may be needed

Cost already incurred: $12.99 (buy-domain — non-recoverable)

Next steps:
  - Fix the build error in deploy-app
  - Re-run the chain (setup-dns will be recreated)
  - Note: buy-domain will be skipped if domain already exists
```

## Integration with Chain State

The rollback engine reads from and writes to the chain state file maintained by the task-chain orchestrator. It does not manage state independently — it is the orchestrator that calls the rollback engine on failure.

Call pattern from task-chain/SKILL.md:

```
on step failure:
  invoke rollback-engine with:
    - chain name
    - failed step ID
    - failure reason
    - completed steps list (in completion order)
    - chain context (outputs captured so far)
```

## Idempotency

Rollback actions should be written to be safe to run multiple times:
- "Delete DNS zone" — safe if zone already deleted
- "Remove Vercel deployment" — safe if project already removed
- "Cancel subscription" — may fail if already cancelled; log and continue

Service skills are responsible for making their rollback actions idempotent where possible. The rollback engine logs any idempotency errors as warnings, not failures.
