---
name: notify-action-receipts
description: "Action receipt format and rules. Every external action generates a receipt notification regardless of approval type."
---

# Action Receipts

Every external action taken by Maestro generates a receipt — a compact notification recording what happened, whether it was approved, what it cost, and when. Receipts fire even for auto-approved actions so there is always a full audit trail.

## Receipt Format

```
[STATUS] Service — Action description — $cost — HH:MM
```

### Status Prefixes

| Prefix | Meaning |
|--------|---------|
| `[AUTO]` | Action was auto-approved by the autonomy engine |
| `[APPROVED]` | Action was explicitly approved by the user |
| `[DENIED]` | Action was explicitly denied by the user or policy |
| `[FAILED]` | Action was attempted but failed with an error |

### Examples

```
[AUTO] Vercel — Deploy to production — $0 — 14:05
[APPROVED] Namecheap — Purchase domain myapp.com — $12.99 — 14:10
[DENIED] Mailgun — Send email to clients — blocked by user — 14:12
[FAILED] AWS EC2 — Launch t3.medium instance — InsufficientCapacity — 14:15
```

### Field Rules

- **Service** — the external service or provider (e.g., AWS, Vercel, Namecheap)
- **Action description** — concise human-readable description of what was done
- **Cost** — monetary cost if applicable; `$0` for free actions; omit for `[DENIED]` and replace with reason
- **Timestamp** — local time in `HH:MM` format at the moment the action completed (or was denied/failed)

For `[DENIED]` receipts, replace the cost field with the denial reason:
```
[DENIED] Mailgun — Send email to clients — blocked by user — 14:12
[DENIED] Stripe — Create subscription — spending limit reached — 15:30
```

For `[FAILED]` receipts, replace the cost field with the error summary (truncated to ~40 chars):
```
[FAILED] AWS EC2 — Launch t3.medium — InsufficientCapacity — 14:15
[FAILED] GitHub Actions — Trigger release workflow — 403 Forbidden — 16:00
```

## Batch Receipts

When more than 5 actions complete within a 60-second window, group them into a single batch receipt to avoid flooding channels:

```
[BATCH] 8 actions completed (7 auto, 1 user-approved) — total $0.50
  Details: 5x AWS list, 1x Vercel deploy, 1x DNS update, 1x domain check
```

### Batch Rules

- Trigger when: more than 5 action receipts would be sent within any 60-second rolling window
- Group by: approval status breakdown (auto / user-approved / denied / failed)
- Always include: total count, breakdown counts, total cost
- Detail line: list unique action types with counts, up to 5 types; if more, append `+ N more`
- Failed or denied actions within a batch are still called out explicitly after the batch summary:
  ```
  [BATCH] 9 actions completed (7 auto, 1 user-approved, 1 failed) — total $0.50
    Details: 5x AWS list, 1x Vercel deploy, 1x DNS update, 1x domain check + 1 more
    [FAILED] AWS S3 — Delete bucket — BucketNotEmpty — 14:22
  ```

## Delivery

Receipts are sent via the standard `notify.send()` pipeline and subject to channel-level filtering. At the `all` level a channel receives every individual receipt. At `important` or `critical` levels, individual `[AUTO]` receipts are suppressed; `[APPROVED]`, `[DENIED]`, `[FAILED]`, and `[BATCH]` receipts pass through.

Receipt level mapping:

| Receipt type | Notification level |
|-------------|-------------------|
| `[AUTO]` | all |
| `[APPROVED]` | all |
| `[DENIED]` | important |
| `[FAILED]` | critical |
| `[BATCH]` | all (batch itself counts as `all`; any FAILED inside escalates the batch to `critical`) |

## Storage

All receipts are appended to `.maestro/logs/action-receipts.log` regardless of channel delivery, so the full trail is always available locally. Format in the log file:

```
2026-03-19T14:05:00Z [AUTO]     Vercel       Deploy to production             $0.00
2026-03-19T14:10:00Z [APPROVED] Namecheap    Purchase domain myapp.com        $12.99
2026-03-19T14:12:00Z [DENIED]   Mailgun      Send email to clients            blocked by user
2026-03-19T14:15:00Z [FAILED]   AWS EC2      Launch t3.medium instance        InsufficientCapacity
```

Use `/maestro notifications receipts` to view the last 20 entries from this log.
