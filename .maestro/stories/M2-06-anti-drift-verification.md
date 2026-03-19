---
id: M2-06
slug: anti-drift-verification
title: "Anti-drift verification — post-task goal alignment check"
type: feature
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. New skill `skills/anti-drift/SKILL.md` exists (120+ lines)
2. Implements drift detection at 3 levels:
   - **Story drift**: After implementation, verify changes match story acceptance criteria
   - **Milestone drift**: After milestone, verify all stories serve the milestone goal
   - **Vision drift**: After N milestones, verify trajectory still serves the North Star vision
3. Drift score: 0-100 (0 = perfectly aligned, 100 = completely off track)
4. Auto-correction: When drift > 40, inject correction into next agent's context
5. Drift log: Record all drift scores in `.maestro/logs/drift.md`
6. Integrates with dev-loop QA phase and opus-loop milestone evaluation
7. Mirror: skill exists in both root and plugins/maestro/skills/

## Context for Implementer

Ruflo's anti-drift uses "hierarchical topology checkpoints" and "frequent validation gates." Maestro's equivalent should:

1. **Story-level**: After an implementer returns DONE, compare the actual diff against the story's acceptance criteria. Each criterion gets a pass/fail. If >30% fail, that's drift.
2. **Milestone-level**: After all stories in a milestone complete, re-read the milestone spec and verify the combined changes actually achieve the milestone goal.
3. **Vision-level**: Every 3 milestones, re-read .maestro/vision.md and assess whether the project is still heading toward the North Star.

The skill should be called from:
- dev-loop's QA phase (story drift)
- opus-loop's milestone evaluation (milestone drift)
- opus-loop's between-milestone retrospective (vision drift)

Reference: skills/truth-verifier/SKILL.md for existing claim verification pattern
Reference: skills/dev-loop/SKILL.md for QA phase integration point
Reference: skills/opus-loop/SKILL.md for milestone evaluation integration point
