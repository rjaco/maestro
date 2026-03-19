# S1: Harden opus-loop-hook

**Milestone:** M1 — Full-Auto Reliability
**Priority:** Critical
**Effort:** Medium
**Status:** In Progress

## User Story
As a developer using full-auto mode, I want the opus loop to never silently stop, so that my project continuously improves without my intervention.

## Tasks
### Phase 1: Diagnose and Fix
- [ ] 1.1 Add inline vision summary to re-injection prompt (read first 3 lines of vision.md and embed)
- [ ] 1.2 Include current milestone acceptance criteria in the re-injection context
- [ ] 1.3 Add iteration counter to state file, increment on each re-injection
- [ ] 1.4 Write heartbeat timestamp to .maestro/logs/heartbeat on each hook fire
- [ ] 1.5 Add fallback: if opus-loop-hook has blocked 3+ times, output a stronger "CONTINUE NOW" prompt

### Phase 2: Robustness
- [ ] 2.1 Handle missing/corrupt state file gracefully (recreate from vision.md + roadmap.md)
- [ ] 2.2 Add shellcheck compliance
- [ ] 2.3 Mirror to plugins/maestro/hooks/opus-loop-hook.sh

## Acceptance Criteria
```gherkin
GIVEN an active Opus session in full_auto mode
WHEN Claude attempts to stop
THEN the hook blocks exit and re-injects a rich prompt with vision summary, milestone context, and next action
AND a heartbeat timestamp is written to .maestro/logs/heartbeat
AND the iteration counter in state is incremented

GIVEN the hook has blocked exit 3+ consecutive times
WHEN Claude attempts to stop again
THEN the hook includes an escalated "EXECUTE IMMEDIATELY" directive

GIVEN a corrupt or missing state file
WHEN the hook fires
THEN it falls back to approving exit rather than crashing
```

## Files to Modify
- hooks/opus-loop-hook.sh
- plugins/maestro/hooks/opus-loop-hook.sh (mirror)
