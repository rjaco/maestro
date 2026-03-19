# S4: Add heartbeat + progress tracking system

**Milestone:** M1 — Full-Auto Reliability
**Priority:** High
**Effort:** Small
**Status:** In Progress

## User Story
As a developer monitoring Maestro, I want a heartbeat system that tracks activity, so that stalls can be detected and progress can be measured.

## Tasks
- [ ] 1.1 Create heartbeat skill that writes JSON to .maestro/logs/heartbeat.json
- [ ] 1.2 Heartbeat contains: timestamp, phase, milestone, story, agent_dispatches, last_action
- [ ] 1.3 Update opus-loop skill to call heartbeat after each agent dispatch
- [ ] 1.4 Update dev-loop skill to call heartbeat after each phase transition
- [ ] 1.5 Add /maestro heartbeat command to display last heartbeat and time since
- [ ] 2.1 Create .maestro/logs/progress.jsonl for historical progress tracking
- [ ] 2.2 Each entry: timestamp, event_type (story_complete, milestone_complete, agent_dispatch), details

## Acceptance Criteria
```gherkin
GIVEN an active Maestro session
WHEN an agent is dispatched or a phase transitions
THEN .maestro/logs/heartbeat.json is updated with current timestamp and state

GIVEN a running daemon
WHEN it reads heartbeat.json
THEN it can determine if Claude is still making progress (timestamp < 5 min ago)
```

## Files to Create
- skills/heartbeat/SKILL.md
- plugins/maestro/skills/heartbeat/SKILL.md (mirror)
- commands/heartbeat.md (optional)

## Files to Modify
- skills/opus-loop/SKILL.md (add heartbeat calls)
- skills/dev-loop/SKILL.md (add heartbeat calls)
