---
id: [milestone]-[number]
slug: [kebab-case-title]
title: "[Human-Readable Story Title]"
type: [frontend|backend|integration|data|infrastructure|test]
status: created
execution_mode: interactive
depends_on: []
parallel_safe: [true|false]
complexity: [simple|medium|complex]
model_recommendation: [haiku|sonnet|opus]
estimated_tokens: [number]
---

## User Story

As a [role], I want [action], so that [benefit].

Example:
> As a frontend developer, I want a paginated vehicle list endpoint, so that I can render the vehicle catalogue without loading all records at once.

## Task Description

[1–3 sentences: what to build and why. Be concrete — name the function, endpoint, component, or behavior being added. Explain what user need or system requirement this addresses and how it fits into the broader feature.]

Example:
> Add a `GET /api/v1/vehicles` endpoint that returns paginated vehicle records from the database. This is the data layer for the vehicle list screen and is required before the frontend listing story can begin.

## Acceptance Criteria

[Each criterion must be specific and independently testable. Use Gherkin format. Include at least one error/edge-case scenario.]

```gherkin
Scenario: [Happy path]
  GIVEN [system precondition]
  WHEN [action]
  THEN [verifiable outcome]

Scenario: [Error or edge case]
  GIVEN [error precondition]
  WHEN [action]
  THEN [expected error handling or boundary behavior]
```

Example:

```gherkin
Scenario: Paginated vehicle list
  GIVEN the database contains vehicle records
  WHEN GET /api/v1/vehicles is called with page=1&limit=10
  THEN it returns 200 with a JSON array of up to 10 vehicle objects and a total count

Scenario: Invalid pagination parameter
  GIVEN a caller passes page=-1
  WHEN GET /api/v1/vehicles is called
  THEN it returns 400 with a descriptive error message

Scenario: Empty dataset
  GIVEN no vehicle records exist
  WHEN GET /api/v1/vehicles is called
  THEN it returns 200 with an empty array and total: 0
```

## Execution Mode

<!-- Choose one and delete the others. Controls orchestrator behavior at CHECKPOINT phase. -->

**interactive** (default) — Orchestrator pauses after each story for user review and direction.

<!-- **yolo** — Auto-continue without interruption (0-1 prompts). Use for low-risk, high-confidence stories. -->
<!-- **preflight** — Full static analysis + multi-reviewer QA before implementation begins. Use for complex or risky stories. -->

## Architecture Context

[Embed the actual code patterns the implementer must follow. Do NOT write "see architecture.md" or "follow the pattern in X". Copy the relevant snippet directly here. Include the source path as a comment so the implementer knows where it came from.]

Example:

API routes in this project follow this pattern (from `src/app/api/v1/vehicles/route.ts`):

```typescript
// src/app/api/v1/vehicles/route.ts
export async function GET(request: NextRequest) {
  const { valid, error, params } = validateParams(request, schema)
  if (!valid) return NextResponse.json({ error }, { status: 400 })

  const data = await vehicleRepo.list(params)
  return NextResponse.json(data, { headers: CACHE_HEADERS })
}
```

Repository functions follow this shape (from `src/lib/userRepo.ts`):

```typescript
// src/lib/userRepo.ts
export async function list(params: ListParams): Promise<{ items: User[]; total: number }> {
  const { page = 1, limit = 20 } = params
  const offset = (page - 1) * limit
  const [items, total] = await Promise.all([
    db.select().from(users).limit(limit).offset(offset),
    db.select({ count: count() }).from(users),
  ])
  return { items, total: total[0].count }
}
```

## File Operations

[List every file the implementer will touch. For created files, state their purpose. For modified files, state what changes. For reference files, state what pattern or type to extract from them. Never say "see X for context" without listing it here.]

### Create
- `src/path/to/new-file.ts` — [what this file does]
- `src/path/to/new-file.test.ts` — [what behaviors are tested: happy path, errors, edge cases]

### Modify
- `src/path/to/existing-file.ts` — [what changes and why; if adding to an interface, show current shape and the addition]

### Reference (read-only)
- `src/path/to/pattern-file.ts` lines [N–M] — [what to extract: a type, a pattern, a constant]

## Test Expectations

[Describe exactly what tests to write and how. Name the test file. List the scenarios. Reference the test pattern used in the project if relevant — embed it inline rather than pointing to a file.]

Example:

Write unit tests in `src/lib/vehicleRepo.test.ts` using Vitest. Each test should use the real database via `testDb` (do not mock the database — the project uses real DB integration tests).

Scenarios to cover:
- Returns paginated results with correct `total`.
- Returns empty array with `total: 0` when no records exist.
- Throws a typed error when the DB connection fails.

Test pattern (from `src/lib/userRepo.test.ts`):

```typescript
import { testDb } from '@/test/helpers'
import { list } from './vehicleRepo'

describe('vehicleRepo.list', () => {
  it('returns paginated vehicles', async () => {
    await testDb.seed.vehicles(5)
    const result = await list({ page: 1, limit: 3 })
    expect(result.items).toHaveLength(3)
    expect(result.total).toBe(5)
  })
})
```

## Dependencies (Resolved)

[List every story this one depends on. State the actual status and what this story requires from it. Do NOT write "TBD" or "see dependency graph". Resolve it here.]

Example:
- `M1-S1` (DB schema migration): DONE — `vehicles` table exists with columns `id`, `make`, `model`, `year`, `price`.
- `M1-S2` (auth middleware): IN_PROGRESS — endpoint must be behind `requireAuth()` middleware once available; stub with `// TODO: add requireAuth()` until merged.

If there are no dependencies: `None.`

## Project Rules (Inline)

[Copy the CLAUDE.md rules that are directly relevant to this story. Do NOT write "follow CLAUDE.md". The implementer receives only this story — they have no access to CLAUDE.md unless it is embedded here.]

Example:
- Use `zod` for all request validation. Never validate manually with `if` checks.
- All database access must go through repository functions in `src/lib/`. Do not call `db` directly from route handlers.
- TypeScript strict mode is enabled. No `any` types.
- Tests must not mock the database. Use `testDb` from `src/test/helpers`.

## Project Lessons (Inline)

[Copy retrospective lessons that apply to this story. If there are no relevant lessons, write `None.`]

Example:
- The `validateParams` helper does not strip unknown fields by default — pass `{ stripUnknown: true }` or validation will pass through garbage data.
- `CACHE_HEADERS` must not be used on authenticated endpoints — it caused a data-leak incident in M0. Use `NO_CACHE_HEADERS` instead.

## Constraints

[Any limitations or non-obvious requirements that do not fit elsewhere.]

Example:
- The endpoint must respond in under 200ms at p95 for up to 10,000 records.
- Do not add new npm dependencies. Use only what is already in `package.json`.
- This story scope ends at the API layer. Do NOT build the UI component — that is M2-S4.

---

## Dev Agent Record

<!-- Filled in by the implementer agent during Phase 3: IMPLEMENT. Do not edit manually. -->

```yaml
agent: ~
model: ~
started_at: ~
completed_at: ~
status: ~           # DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
tests_passing: ~
files_created: []
files_modified: []
concerns: []        # populated only when status is DONE_WITH_CONCERNS
```

---

## QA Results

<!-- Filled in by the QA reviewer agent during Phase 5: QA REVIEW. Do not edit manually. -->

```yaml
reviewer: ~
model: ~
verdict: ~          # APPROVED | REJECTED
iteration: ~        # 1 = first review attempt
findings: []        # each entry: { criterion, confidence, issue, suggestion }
reviewed_at: ~
```

---

<!-- Story lifecycle: created → validated → implementing → reviewing → done -->
