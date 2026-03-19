---
id: AA-M3
title: Enhanced Notification Hub
status: pending
stories: 3
depends_on: AA-M1
---

# AA-M3: Enhanced Notification Hub

## Purpose
All-channel notifications with configurable levels. Every action generates a notification — even auto-approved ones. The user is ALWAYS informed about what Maestro is doing.

## Stories

### S9: Notification Levels & Channel Routing
- Four notification levels: all / important / critical / none
- Per-channel level configuration (e.g., Telegram=all, Email=critical)
- Notification types: action_started, action_completed, action_failed, approval_needed, spending_alert, milestone_complete
- Config in `.maestro/config.yaml` under `notifications`

### S10: Action Receipts
- Every external action generates a receipt notification
- Receipt format: service, action, cost (if any), result, timestamp
- Auto-approved actions clearly marked as "[AUTO] Deployed to Vercel — $0"
- Failed actions include error details
- Batch receipts for rapid sequences (group if >5 actions in 60 seconds)

### S11: Approval Prompts via Messaging Channels
- When approval needed, send rich prompt to ALL connected channels
- Include: action description, cost estimate, risk tier, service
- Accept response from ANY channel (first response wins)
- Timeout configurable (default: wait indefinitely in tiered, 5min in full-auto)
- Quick-reply buttons where platform supports (Telegram inline keyboard)

## Acceptance Criteria
1. Notifications reach all configured channels
2. Notification levels respected per-channel
3. Every action generates a receipt (even auto-approved)
4. Approval prompts work bidirectionally on messaging channels
5. Batch notifications prevent spam during rapid operations
