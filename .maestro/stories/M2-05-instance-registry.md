# S5: Instance Registry

**Milestone:** M2 — Multi-Instance Coordination
**Priority:** High
**Effort:** Medium

## User Story
As a developer running multiple Maestro instances, I want each instance to register itself and claim stories, so that no two instances work on the same story.

## Tasks
- [ ] 1.1 Create `skills/instance-registry/SKILL.md` — manages instance lifecycle
- [ ] 1.2 On session start, write `.maestro/instances/{session_id}.json` with: session_id, pid, started_at, hostname, current_story, branch, last_heartbeat
- [ ] 1.3 Before claiming a story, read all instance files — if story is claimed by active instance, skip to next
- [ ] 1.4 Mark story as claimed: write `claimed_by: {session_id}` to story file frontmatter
- [ ] 1.5 On session end (or daemon stop), remove instance file
- [ ] 1.6 Stale instance cleanup: if last_heartbeat > 10 min ago, release claimed stories and remove instance file
- [ ] 1.7 Mirror to plugins/maestro/

## Acceptance Criteria
```gherkin
GIVEN two Maestro instances starting simultaneously
WHEN instance A claims story S1
THEN instance B sees S1 as claimed and picks S2 instead

GIVEN an instance that crashed 15 minutes ago
WHEN another instance checks the registry
THEN the crashed instance's claims are released
```

## Files to Create
- skills/instance-registry/SKILL.md
- plugins/maestro/skills/instance-registry/SKILL.md
