---
id: M6-23
slug: worker-scheduling
title: "Worker scheduling — context-triggered workers, priority queue"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/background-workers/SKILL.md` with scheduling improvements:
   - **Context-triggered workers**: Workers that activate on file changes (e.g., run lint when .ts files change)
   - **Priority queue**: Critical workers run first, info-level workers run when idle
   - **Worker health**: Track last run time, success rate, average duration per worker
2. New scheduling modes:
   - **Periodic**: Run every N minutes (existing behavior)
   - **On-change**: Run when specific file patterns change (via git diff)
   - **On-event**: Run on specific hook events (milestone complete, story done)
3. Worker health dashboard section (integrates with M3-10 health dashboard)
4. Worker configuration in `.maestro/config.yaml`:
   ```yaml
   workers:
     security-scan: { schedule: "daily", priority: high, enabled: true }
     convention-drift: { schedule: "hourly", priority: medium, enabled: true }
   ```
5. Mirror: skill in both root and plugins/maestro/

## Context for Implementer

Read the current `skills/background-workers/SKILL.md` first.

Ruflo has 12 context-triggered workers that auto-dispatch on file changes, pattern detection, or session events. Maestro should adopt the context-triggered pattern:

1. **On-change**: After each story completes, diff the changed files. If .test files changed, trigger test-coverage worker. If package.json changed, trigger dependency-audit worker.
2. **Priority**: Workers have priority levels (high=security, medium=quality, low=info). High-priority workers interrupt low-priority ones.
3. **Health tracking**: Each worker logs its last run time and result. If a worker fails 3 times in a row, it's disabled with a warning.

Reference: skills/background-workers/SKILL.md (current)
Reference: skills/scheduler/SKILL.md for cron-based scheduling
Reference: skills/watch/SKILL.md for file monitoring patterns
