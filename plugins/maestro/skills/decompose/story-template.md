---
id: 0
slug: "story-slug"
title: "Human-Readable Story Title"
depends_on: []
parallel_safe: false
estimated_tokens: 35000
model_recommendation: "sonnet"
type: "backend"
---

# Story: Human-Readable Story Title

## Requirements Context

[Excerpt from the feature description relevant to THIS story only — not the whole feature.]
[Why this story exists — what user need or system requirement it addresses.]
[How this story fits into the broader feature: what it builds on and what depends on it.]

## Architecture Decisions

[Relevant architectural decisions from the plan that directly affect this story.]
[Patterns to follow, with specific file examples from the codebase — e.g., "Follow the repository pattern in `src/lib/userRepo.ts`".]
[Data model or API changes this story implements, if any.]
[Any technology or library choices locked in for this story and why.]

## Acceptance Criteria (BDD)

Given [precondition describing the system state]
When [action taken by user or system]
Then [expected, verifiable outcome]

Given [precondition 2]
When [action 2]
Then [expected outcome 2]

Given [precondition 3 — error or edge case]
When [action 3]
Then [expected error handling or boundary behavior]

## Files

- Create: `src/path/to/new-file.ts` — [what this file does]
- Create: `src/path/to/new-file.test.ts` — [what is tested and why]
- Modify: `src/path/to/existing-file.ts` — [what changes and why]
- Reference: `src/path/to/pattern-example.ts` — [follow this pattern for X]
- Reference: `src/types/relevant-types.ts` — [type definitions needed]

## Interfaces to Maintain

[Function signatures, API contracts, or type definitions that must not break. If this story adds to an existing interface, show the current shape and what is being added.]

```typescript
// Current interface from src/types/foo.ts
interface Foo {
  bar: string;
  baz: number;
}
// This story adds: qux: boolean
```

## Edge Cases

- [Edge case 1 and how to handle it — e.g., empty input, null values, concurrent writes]
- [Edge case 2 — e.g., what happens when a dependency story's output is missing]
- [Edge case 3 — e.g., partial state, network failure, permission denial]

## Test Requirements

- Unit: `src/path/to/new-file.test.ts` — test [specific behaviors: happy path, error path, boundary conditions]
- Integration: [if applicable — describe what cross-component behavior to verify]

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Interfaces preserved (or migration documented if changed)
- [ ] Tests written and passing
- [ ] TypeScript compiles without errors (`tsc --noEmit`)
- [ ] Linter passes (`npm run lint`)
- [ ] No regressions in existing tests
- [ ] Code follows project conventions (from CLAUDE.md / project DNA)
