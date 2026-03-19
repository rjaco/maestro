---
id: M2-08
slug: claims-system
title: "Claims system — human-agent override protocol"
type: feature
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. New skill `skills/claims/SKILL.md` exists (130+ lines)
2. Defines a "claim" as an agent's proposed action that a human can override
3. Three claim types:
   - **Architecture claim**: "I'm going to restructure X this way" — human can redirect
   - **Quality claim**: "This code meets quality bar" — human can reject with reason
   - **Scope claim**: "This feature needs these stories" — human can add/remove
4. Override learning: When a human overrides a claim, the reason is saved to `.maestro/memory/memories.md` so future agents avoid the same mistake
5. Claim log: All claims and overrides recorded in `.maestro/logs/claims.md`
6. Integration with pair-programming skill for real-time claim/override flow
7. Mirror: skill exists in both root and plugins/maestro/skills/

## Context for Implementer

Ruflo's Claims System is a "human-agent coordination protocol enabling humans to override agent decisions while learning from those interventions." Maestro's equivalent:

1. **Claim**: When an agent makes a significant decision (architecture, scope, quality), it records it as a claim.
2. **Review**: In pair-programming or milestone-pause mode, claims are presented to the human for approval.
3. **Override**: If the human disagrees, they provide a reason. The reason is stored as a lesson.
4. **Learn**: Future agents receive relevant lessons from overrides, reducing repeat mistakes.

This is most useful in milestone_pause mode where the human reviews between milestones. In full_auto mode, claims are logged but not blocking.

Reference: skills/pair-programming/SKILL.md for interactive claim flow
Reference: skills/learning-loop/SKILL.md for storing override lessons
Reference: skills/memory/SKILL.md for memory persistence
