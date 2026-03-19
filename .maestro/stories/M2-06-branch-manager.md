# S6: Branch Manager

**Milestone:** M2 — Multi-Instance Coordination
**Priority:** High
**Effort:** Medium

## User Story
As a developer running multiple Maestro instances, I want each instance to work on its own branch, so that parallel work doesn't create conflicts until merge time.

## Tasks
- [ ] 1.1 Create `skills/branch-manager/SKILL.md` — manages per-instance branches
- [ ] 1.2 Each instance creates a branch: `maestro/{session_id}/{story_slug}` or `maestro/{instance_id}/work`
- [ ] 1.3 Update branch-guard.sh to allow `maestro/*` branches (currently only allows development)
- [ ] 1.4 Instance works in its branch via worktree, commits there
- [ ] 1.5 After story completion, merge instance branch into development
- [ ] 1.6 Mirror to plugins/maestro/

## Acceptance Criteria
```gherkin
GIVEN a new Maestro instance starting work on story M1-S1
WHEN it begins implementation
THEN it creates branch maestro/opus-wave6-20260318/m1-s1
AND works in a worktree for that branch

GIVEN branch-guard.sh is active
WHEN an instance pushes to maestro/opus-wave6-20260318/m1-s1
THEN the push is allowed (not blocked like main pushes)
```

## Files to Create/Modify
- skills/branch-manager/SKILL.md
- hooks/branch-guard.sh (allow maestro/* branches)
- plugins/maestro/hooks/branch-guard.sh (mirror)
- plugins/maestro/skills/branch-manager/SKILL.md (mirror)
