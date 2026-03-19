# M6: OpenClaw-Inspired Enhancements

## Scope
Adopt the most impactful patterns from OpenClaw (321k+ stars) — the most-starred software project on GitHub. Focus on skill system improvements that make Maestro more robust and extensible.

## Acceptance Criteria
1. Skills can declare OS, binary, and env var requirements in frontmatter
2. Workspace skills override global/bundled skills with same name
3. Skill file changes are detected and refresh happens on next session
4. All existing skills pass the new dependency gating without errors

## Stories
- S18: Declarative skill dependency gating
- S19: Three-tier skill precedence
- S20: Skill watcher with session-scoped snapshots
