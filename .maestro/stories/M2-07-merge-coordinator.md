# S7: Merge Coordinator

**Milestone:** M2 — Multi-Instance Coordination
**Priority:** High
**Effort:** Medium

## User Story
As a developer running multiple Maestro instances, I want merge conflicts between instances to be automatically resolved, so that parallel work converges cleanly.

## Tasks
- [ ] 1.1 Create `skills/merge-coordinator/SKILL.md` — manages merge to development
- [ ] 1.2 Before merging to development, pull latest and check for conflicts
- [ ] 1.3 If conflicts exist in non-overlapping files: auto-resolve by accepting both
- [ ] 1.4 If conflicts exist in overlapping files: use a merge strategy
        - For .md files: accept both changes (append)
        - For .sh files: attempt 3-way merge, escalate to human if fails
        - For .json files: deep merge keys
- [ ] 1.5 Use file-level locking: `.maestro/locks/{filename}.lock` to prevent simultaneous edits
- [ ] 1.6 If merge fails after 3 attempts: create a conflict report and pause the instance
- [ ] 1.7 Mirror to plugins/maestro/

## Acceptance Criteria
```gherkin
GIVEN instance A merged changes to development
WHEN instance B tries to merge its changes
THEN it rebases on latest development first
AND auto-resolves non-overlapping conflicts
AND reports overlapping conflicts clearly if they can't be auto-resolved
```

## Files to Create
- skills/merge-coordinator/SKILL.md
- plugins/maestro/skills/merge-coordinator/SKILL.md
