# S2: Enhance session-start-hook for post-compact Opus recovery

**Milestone:** M1 — Full-Auto Reliability
**Priority:** Critical
**Effort:** Medium
**Status:** In Progress

## User Story
As a developer in a long Opus session, I want context compaction to seamlessly restore my Opus state, so that the autonomous loop continues without interruption.

## Tasks
- [ ] 1.1 When layer=opus and active=true, inject full Opus context: vision summary, current milestone scope, current story, phase
- [ ] 1.2 Read first 5 lines of .maestro/vision.md and include as inline North Star
- [ ] 1.3 Read current milestone spec and include scope summary
- [ ] 1.4 Include explicit instruction: "Continue the Magnum Opus loop. Execute the next story."
- [ ] 1.5 Include opus_mode in the injected context
- [ ] 2.1 Mirror to plugins/maestro/hooks/session-start-hook.sh
- [ ] 2.2 Add shellcheck compliance

## Acceptance Criteria
```gherkin
GIVEN an active Opus session after context compaction
WHEN a new session starts (or context is restored)
THEN the hook injects: vision summary, milestone N/total, story N/total, phase, opus_mode
AND includes the directive "Continue the Magnum Opus loop"
AND the session continues executing without user intervention
```

## Files to Modify
- hooks/session-start-hook.sh
- plugins/maestro/hooks/session-start-hook.sh (mirror)
