# S3: Harden opus-daemon.sh with progress tracking and stall detection

**Milestone:** M1 — Full-Auto Reliability
**Priority:** Critical
**Effort:** Medium
**Status:** In Progress

## User Story
As a developer running the Opus daemon, I want it to detect when Claude stalls and automatically restart, so that autonomous operation continues 24/7.

## Tasks
- [ ] 1.1 Track iteration history in .maestro/logs/daemon-history.jsonl (timestamp, milestone, story, exit_code, duration)
- [ ] 1.2 Read heartbeat file before each iteration — if no heartbeat update in 5 minutes, consider stalled
- [ ] 1.3 On stall detection: kill any orphaned claude process, restart with fresh invocation
- [ ] 1.4 Add --session-id flag to associate daemon with specific Opus session
- [ ] 1.5 Improve continuation prompt to include vision summary, current milestone, and explicit "dispatch agents" instruction
- [ ] 1.6 Add progress summary at end of each iteration (stories completed, milestone progress)
- [ ] 2.1 Add color output with ANSI codes for better terminal readability
- [ ] 2.2 Handle edge case: claude binary returns non-zero but session is still active
- [ ] 2.3 Mirror to plugins/maestro/ (if daemon is in scripts/)

## Acceptance Criteria
```gherkin
GIVEN the daemon is running
WHEN Claude stalls (no heartbeat update for 5 minutes)
THEN the daemon logs a stall event, kills orphaned processes, and restarts

GIVEN the daemon is running
WHEN an iteration completes
THEN a JSONL entry is written with timestamp, milestone, story, exit_code, duration

GIVEN the daemon is running for 24+ hours
WHEN no fatal errors occur
THEN all iterations are logged and the project makes continuous progress
```

## Files to Modify
- scripts/opus-daemon.sh
