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

## Acceptance Criteria

1. First testable criterion with specific expected behavior
2. Second testable criterion with measurable outcome
3. Third testable criterion covering edge case or error handling
4. (Optional) Fourth criterion for completeness
5. (Optional) Fifth criterion for non-functional requirements
6. (Optional) Sixth criterion for integration verification

## Context for Implementer

- Follow the existing pattern in `src/path/to/similar-feature.ts` for structure and naming
- Use the `utilityFunction()` helper from `src/lib/utils.ts` for formatting
- Adhere to project convention: server components by default, `'use client'` only when needed
- This story's output will be consumed by story NN (provide stable interfaces)
- Gotcha: describe any non-obvious constraint or edge case the implementer should know

## Files

### Create
- `src/path/to/new-file.ts` — Description of what this file contains
- `src/path/to/new-file.test.ts` — Tests for the above

### Modify
- `src/path/to/existing-file.ts` — What changes and why

### Reference
- `src/path/to/pattern-example.ts` — Read this for the pattern to follow
- `src/types/relevant-types.ts` — Type definitions needed

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Tests written and passing
- [ ] TypeScript compiles without errors (`tsc --noEmit`)
- [ ] Linter passes (`npm run lint`)
- [ ] No regressions in existing tests
- [ ] Code follows project conventions (from CLAUDE.md / project DNA)
