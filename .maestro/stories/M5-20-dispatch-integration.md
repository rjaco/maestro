---
id: M5-20
slug: dispatch-integration
title: "Dispatch integration — remote control, mobile status, webhooks"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/dispatch-compat/SKILL.md` with:
   - Mobile-friendly status output (shorter, emoji-based progress)
   - Remote control commands: pause, resume, status, abort
   - Webhook endpoints for external service integration
2. Enhanced `skills/remote-control/SKILL.md` with:
   - Discord bot integration pattern
   - Telegram bot integration pattern
   - HTTP webhook receiver pattern
3. Remote status format (mobile-friendly):
```
Maestro M2/7 S3/5 ▶ IMPLEMENT
✓✓✓○○ | $2.40 | 45m
QA: 80% first-pass
```
4. Remote commands supported:
   - PAUSE — graceful stop
   - RESUME — continue from saved state
   - STATUS — send current progress
   - ABORT — stop immediately
5. Mirror: skills in both root and plugins/maestro/

## Context for Implementer

Read the current `skills/dispatch-compat/SKILL.md` and `skills/remote-control/SKILL.md` first.

Claude Code's Dispatch feature allows controlling sessions from a phone. Maestro should provide meaningful output in this context — short, structured, actionable.

For webhook integration, define the expected JSON format:
```json
{
  "command": "STATUS",
  "session_id": "optional"
}
```

Response:
```json
{
  "milestone": "2/7",
  "story": "3/5",
  "phase": "IMPLEMENT",
  "cost": "$2.40",
  "elapsed": "45m"
}
```

Reference: skills/dispatch-compat/SKILL.md (current)
Reference: skills/remote-control/SKILL.md (current)
Reference: skills/notify/SKILL.md for notification patterns
