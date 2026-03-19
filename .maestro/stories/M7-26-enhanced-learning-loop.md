---
id: M7-26
slug: enhanced-learning-loop
title: "Enhanced learning loop — knowledge graph integration, cross-project patterns"
type: enhancement
depends_on: [M2-07]
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/learning-loop/SKILL.md` with:
   - **Knowledge graph integration**: After learning, update knowledge graph relationships
   - **Cross-project pattern sharing**: Lessons stored in `~/.claude/maestro-lessons.md` (global)
   - **Pattern confidence scoring**: Each lesson has a confidence score (0-1) that increases with repeated observations
   - **Lesson categories**: architecture, testing, security, performance, DX
2. Learning loop now runs in 5 phases (up from 4):
   - RETRIEVE → JUDGE → DISTILL → CONSOLIDATE → SHARE
   - New SHARE phase: promote high-confidence lessons to global store
3. Global lessons loaded by Context Engine for new projects
4. Lesson decay: confidence drops 0.05 per week without reinforcement
5. Mirror: skill in both root and plugins/maestro/

## Context for Implementer

Read the current `skills/learning-loop/SKILL.md` first. It has 4 phases: RETRIEVE→JUDGE→DISTILL→CONSOLIDATE.

Add:
1. **SHARE phase**: After CONSOLIDATE, check if any lesson has confidence > 0.8. If so, append to `~/.claude/maestro-lessons.md` (global, cross-project).
2. **Knowledge graph update**: When a lesson is about file relationships (e.g., "always update X when changing Y"), update the knowledge graph adjacency list.
3. **Confidence scoring**: Each lesson starts at 0.5. +0.1 each time the pattern is observed again. -0.05 per week without observation.
4. **Categories**: Tag each lesson with a category for easier retrieval.

The global lessons file format:
```markdown
## [timestamp] [category] Lesson
Confidence: 0.85
Projects: project-a, project-b
Pattern: [description]
```

Reference: skills/learning-loop/SKILL.md (current)
Reference: skills/memory/SKILL.md for memory persistence patterns
Reference: skills/knowledge-graph/SKILL.md for graph integration (new skill from M2-07)
