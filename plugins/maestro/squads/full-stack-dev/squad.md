---
name: "full-stack-dev"
description: "Full-stack web development team that builds web applications with proper architecture, frontend/backend separation, and quality gates"
version: "1.0.0"
author: "Maestro"
agents:
  - role: architect
    agent: "maestro:maestro-implementer"
    model: opus
    focus: "System design, API contracts, data models, and component boundaries. Produces architecture decisions, interface definitions, and the implementation plan that all other agents follow."
    tools: [Read, Grep, Glob, Write]
  - role: frontend
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "React/Next.js/Vue components, styling, UX, and responsive design. Consumes API contracts from architect. Uses design tokens, handles loading/error/empty states, and ensures accessibility."
    tools: [Read, Edit, Write, Bash, Grep, Glob]
  - role: backend
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "API routes, business logic, database queries, input validation, and authentication. Implements contracts defined by architect. Applies rate limiting, proper error responses, and security guards."
    tools: [Read, Edit, Write, Bash, Grep, Glob]
  - role: tester
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Unit tests, integration tests, and e2e test scaffolding. Writes tests against the interfaces defined by architect. Covers happy paths, edge cases, and error conditions for both frontend and backend."
    tools: [Read, Edit, Write, Bash, Grep, Glob]
  - role: qa
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "Cross-cutting review for security vulnerabilities, performance anti-patterns, and correctness against acceptance criteria. Read-only. Reports APPROVED or REJECTED with confidence-scored issues."
    tools: [Read, Grep, Glob]
orchestration_mode: dag
shared_context:
  - ".maestro/dna.md"
  - "CLAUDE.md"
quality_gates:
  - "Architect produces explicit API contracts and data models before implementation begins"
  - "Frontend and backend are implemented against the same interface definitions"
  - "All API routes have input validation, auth checks, and consistent error responses"
  - "All components handle loading, error, and empty states"
  - "Test coverage includes happy paths and edge cases for critical logic"
  - "QA reviewer approves with no issues at confidence >= 80"
---

# Squad: Full-Stack Dev

## Purpose

Build web applications end-to-end with proper separation of concerns. This squad enforces an architecture-first discipline: an architect defines the system design and API contracts before a single line of implementation is written. Frontend and backend can then proceed in parallel against shared interfaces, with a dedicated tester and a final QA gate to catch security and correctness issues before the story closes.

Use this squad when a story touches both frontend and backend, or when the implementation is substantial enough that ad-hoc architecture would create technical debt.

## Agents

### architect (opus)

The first agent to run on every story. Produces the blueprint the rest of the squad executes against.

Responsibilities:
- Define data models and database schema changes
- Specify API contracts: HTTP method, path, request shape, response shape, error cases
- Draw component boundaries: what is server-rendered vs client-interactive, what shared state looks like
- Identify cross-cutting concerns: authentication requirements, caching strategy, rate limiting needs
- Write the implementation plan that frontend and backend receive as context

The architect does not write production code. It writes specifications that make the parallel implementation phase safe.

### frontend (sonnet)

Implements everything the user sees and touches.

Responsibilities:
- React/Next.js components, pages, and layouts following the project's file organization
- Responsive design from mobile (375px) to desktop (1440px)
- Accessibility: keyboard navigation, screen-reader support, ARIA where semantic HTML is insufficient
- State management and data fetching against the API contracts defined by architect
- Loading states, error boundaries, and empty states on every data-dependent component
- Design token usage: CSS custom properties for colors, spacing, typography — no hardcoded values

### backend (sonnet)

Implements the server-side surface the frontend consumes.

Responsibilities:
- API routes with the HTTP methods, paths, and response shapes specified by architect
- Input validation using schema-based validation (Zod or equivalent) on every endpoint
- Authentication and authorization checks before any business logic executes
- Database queries that select only needed columns, use pagination for lists, and handle connection errors
- Rate limiting on public-facing endpoints
- Consistent JSON error objects with correct HTTP status codes
- No service-role client leakage to client-side code

### tester (sonnet)

Writes the tests that validate the implementation, not just confirm it runs.

Responsibilities:
- Unit tests for business logic: pure functions, data transformations, validation rules
- Integration tests for API routes: success cases, validation failures, auth rejection, edge inputs
- Component tests for critical UI interactions: form submission, empty state, error display
- E2e test scaffolding for user journeys that span frontend and backend
- Tests are named to describe behavior, not implementation details

### qa (opus)

The final gate before a story is marked done. Read-only — never modifies code.

Responsibilities:
- Verify every acceptance criterion is met by tracing it to a specific implementation
- Scan for OWASP top-10 patterns: injection, XSS, auth bypass, exposed secrets
- Flag performance anti-patterns on hot paths (O(n^2) queries, missing pagination, synchronous blocking)
- Verify test coverage of critical paths — not 100%, but the paths that matter
- Report APPROVED or REJECTED with confidence-scored issues (threshold: 80)

## Workflow

```
architect
    |
    +-- frontend (parallel)
    |
    +-- backend  (parallel)
         |
       tester
         |
          qa
```

1. **architect** receives the story and produces: data models, API contracts, component boundaries, and an implementation plan. This output is added to context for all subsequent agents.

2. **frontend** and **backend** run in parallel, each consuming the architect's contracts. They do not need to wait for each other.

3. **tester** runs after both frontend and backend complete. It receives the full diff and writes tests against the actual implementation, using the architect's contracts to know what to test.

4. **qa** runs last. It receives the full diff, test output, and any concerns flagged by previous agents. It approves or rejects with concrete, confidence-scored issues.

## Context Sharing

Every agent in this squad receives:
- `.maestro/dna.md` — Project DNA: tech stack, naming conventions, architectural decisions
- `CLAUDE.md` — Project-level rules all agents must follow

In addition:
- **frontend** and **backend** receive the architect's output as injected context
- **tester** receives the full implementation diff and architect contracts
- **qa** receives the full diff, test results, and any DONE_WITH_CONCERNS flags from prior agents

## Quality Gates

1. **Architecture gate** — Architect output must include explicit API contracts (not just intent) and data models before implementation proceeds.
2. **Contract conformance** — Frontend requests must match the backend's defined response shapes. Type mismatches are a rejection criterion.
3. **Validation coverage** — Every API route that accepts user input must have schema validation. Missing validation = automatic rejection.
4. **State completeness** — Every component that fetches data must render a loading state, an error state, and an empty state.
5. **Test gate** — Critical business logic and API routes must have test coverage. Passing tests in CI is a prerequisite for QA review.
6. **QA approval** — No issues with confidence >= 80 may remain open. QA must report STATUS: APPROVED.

## When to Use

- Stories that add or modify both a UI surface and its backing API
- New features that introduce data models or schema changes
- Any work where frontend and backend engineers would normally need to coordinate
- Stories where security (auth, validation, data exposure) is a concern
- Rewrites or refactors of existing features that need end-to-end validation
