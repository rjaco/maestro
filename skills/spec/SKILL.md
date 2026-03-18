---
name: spec
description: "Spec-driven workflow — write a structured feature spec first, then all agents consume it as a shared context artifact throughout implementation."
---

# Spec

A spec is a structured, immutable artifact that defines a feature before any agent writes code. All agents in the dev-loop receive the active spec as T1 context, preventing scope creep and spec drift.

## Spec File Format

Specs live at `.maestro/specs/{slug}.md`:

```markdown
---
name: "User Authentication"
status: draft
created: 2026-03-18
author: rodrigo
priority: high
---

## Problem
[What problem does this solve? Why now?]

## Solution
[High-level approach. What will be built?]

## Requirements
- [ ] REQ-1: [Requirement with acceptance criterion]
- [ ] REQ-2: [Another requirement]

## Non-Goals
- [Explicitly out of scope]

## Technical Constraints
- [Must use X framework]
- [Must be backward compatible]

## Success Metrics
- [How do we know this is done?]
```

Six required sections: Problem, Solution, Requirements, Non-Goals, Technical Constraints, Success Metrics. All must be present and non-empty before a spec can be activated.

## Spec Lifecycle

```
draft → active → implementing → complete
```

| Status | Meaning | Who sets it |
|--------|---------|------------|
| `draft` | Being written, not yet committed | Author |
| `active` | Finalized, immutable, ready to build | `/maestro spec activate` |
| `implementing` | Dev-loop has started against this spec | Maestro automatically |
| `complete` | All requirements checked off | `/maestro spec complete` |

**Immutability rule:** Once a spec reaches `active`, its Requirements section is frozen. Requirements cannot be edited, only superseded. To add scope, create a new spec version (e.g., `user-auth-v2.md`) and link to the original.

**One active spec at a time** per project. Activating a new spec moves the current active spec to `implementing` if execution is in progress, or back to `draft` if not.

## Context Engine Integration

The active spec is loaded as **T1 context** — always included in every agent package while `status: implementing`.

| Agent Role | What the spec provides |
|-----------|----------------------|
| `orchestrator` | Full spec as T1 source of truth |
| `decompose` | Requirements list → story acceptance criteria |
| `implementer` | Referenced requirements for the story being built |
| `qa-reviewer` | Requirements checklist to validate against |
| `strategist` | Problem + Non-Goals to prevent scope creep |

The context-engine loads the spec from `.maestro/specs/` when composing packages — no manual injection needed.

## Integration with Decompose

When a spec is active, `decompose/SKILL.md` reads the Requirements section and maps each `REQ-N` to one or more stories:

- Each story cites the requirement IDs it satisfies: `satisfies: [REQ-1, REQ-3]`
- Stories that cannot be traced to a requirement are flagged as out-of-scope
- Decompose marks each `REQ-N` checkbox as the implementing story is assigned

This creates a traceable line from spec requirement → story → code.

## Integration with QA Reviewer

The QA reviewer receives the spec alongside the story diff. For each story, it checks:

1. The story's acceptance criteria align with the cited requirements
2. No code was added that satisfies an un-spec'd requirement (scope creep)
3. No spec requirement was silently ignored

Failing QA on scope grounds returns the story to the implementer with the specific requirement mismatch noted.

## Completion

A spec is complete when all requirement checkboxes are checked:

```
- [x] REQ-1: Login endpoint accepts email/password
- [x] REQ-2: JWT tokens expire after 15 minutes
- [ ] REQ-3: Refresh token rotation on use
```

`/maestro spec complete <slug>` verifies all boxes are checked before writing `status: complete`. If unchecked requirements remain, it lists them and blocks completion.

## Relationship to Other Patterns

| Pattern | Scope | Relationship |
|---------|-------|-------------|
| Steering files | Project-wide, permanent | Spec complements — steering = project DNA, spec = feature definition |
| Feature registry | Persistent requirement IDs across sessions | Spec requirements become registry entries when decompose runs |
| vision.md | Ad-hoc per-feature notes | Spec replaces vision.md for structured feature work |
| Plan | Session-scoped architecture | Plan consumes the spec; spec is the "why", plan is the "how" |
