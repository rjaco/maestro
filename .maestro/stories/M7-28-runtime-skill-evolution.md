---
id: M7-28
slug: runtime-skill-evolution
title: "Runtime skill evolution — automatic refinement from QA feedback"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/runtime-author/SKILL.md` with evolution capabilities:
   - **QA-driven refinement**: When QA repeatedly rejects for the same pattern, update the relevant skill
   - **Feedback loop**: Track rejection reasons per skill, refine after 3+ similar rejections
   - **Skill versioning**: Before modifying a skill, create a backup (SKILL.md.v1, SKILL.md.v2)
   - **Rollback**: If a refined skill performs worse, revert to previous version
2. Evolution triggers:
   - 3+ QA rejections with similar feedback → refine the responsible skill
   - Same NEEDS_CONTEXT escalation 3+ times → add context requirement to skill
   - User override on same decision 3+ times → update decision logic in skill
3. Evolution log: `.maestro/logs/skill-evolution.md` with before/after diffs
4. Safety: only project-scoped skills evolve (bundled skills are read-only)
5. Mirror: skill in both root and plugins/maestro/

## Context for Implementer

Read the current `skills/runtime-author/SKILL.md` first. It creates new skills when gaps are detected. This enhancement adds EVOLUTION — existing skills get better over time.

The flow:
1. Agent implements story using skill X
2. QA rejects with feedback "missing error handling pattern"
3. This rejection is logged against skill X
4. After 3 similar rejections, a refinement agent is dispatched:
   - Reads skill X
   - Reads the 3 rejection feedbacks
   - Identifies the common pattern
   - Adds the missing guidance to skill X
   - Backs up the original as SKILL.md.vN
5. Next time skill X is used, the refined version includes the missing guidance

Safety constraints:
- Only modify skills in the project's skills/ directory
- Never modify bundled plugin skills
- Always backup before modification
- Track performance before/after to validate improvement

Reference: skills/runtime-author/SKILL.md (current)
Reference: skills/self-correct/SKILL.md for self-correction patterns
Reference: skills/learning-loop/SKILL.md for learning integration
