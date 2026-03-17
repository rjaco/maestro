---
name: architecture
description: "Design or update technical architecture. Produces .maestro/architecture.md with tech stack decisions, data model, API design, component structure, and infrastructure map."
---

# Architecture

Designs or updates the technical architecture for a feature or project. Produces a comprehensive architecture document that bridges strategy requirements and implementation stories.

## Input

- `.maestro/vision.md` — Project vision and constraints (optional but recommended)
- `.maestro/research.md` — Competitive technical analysis (optional)
- `.maestro/strategy.md` — Strategy requirements that shape architecture (optional)
- `.maestro/dna.md` — Existing project DNA (read if updating, generate if greenfield)
- `$ARGUMENTS` — Specific architecture concern or feature scope
- Existing codebase — Scanned for current patterns when updating

## Process

### Step 1: Gather Requirements

1. Read all available `.maestro/` documents for context.
2. If updating an existing project, read `.maestro/dna.md` and scan the codebase:
   - Package manifest (package.json, Cargo.toml, pyproject.toml, go.mod)
   - Directory structure (top 2 levels)
   - Existing architecture docs (architecture.md, CLAUDE.md)
   - Key configuration files (tsconfig, next.config, docker-compose)
3. If greenfield, note the absence of existing code and that all decisions are open.
4. Identify non-functional requirements: performance targets, scale expectations, security needs, budget constraints, team size.

### Step 2: Tech Stack Decisions

For each layer, recommend a technology with rationale:

| Layer | Technology | Rationale | Alternatives Considered |
|-------|-----------|-----------|------------------------|
| Framework | [choice] | [why] | [what else was considered] |
| Database | [choice] | [why] | [what else was considered] |
| Hosting | [choice] | [why] | [what else was considered] |
| Styling | [choice] | [why] | [what else was considered] |
| Auth | [choice] | [why] | [what else was considered] |

If updating an existing project, note which stack decisions are locked (already in use) versus open for this feature.

Every recommendation must cite a concrete reason — performance data, ecosystem maturity, team familiarity, cost, or a requirement from the strategy document. No "it's popular" justifications.

### Step 3: Data Model

Design the data model for the feature or system:

1. **Entities** — List all entities with their attributes and types.
2. **Relationships** — Define relationships (1:1, 1:N, N:M) with foreign keys.
3. **Indexes** — Identify query patterns and the indexes they require.
4. **Migrations** — If modifying an existing schema, describe the migration path.

Present the model as a table or entity-relationship description:

```
Entity: [name]
  - id: uuid (PK)
  - [field]: [type] [constraints]
  - [field]: [type] [constraints]
  -> [relationship] to [other entity]
```

### Step 4: API Design

Design the API surface:

1. **Endpoints** — Method, path, purpose, request/response shape.
2. **Authentication** — Which endpoints are public, which require auth, what auth method.
3. **Validation** — Input validation strategy (Zod, JSON Schema, custom).
4. **Error handling** — Error response format, status code conventions.
5. **Rate limiting** — Which endpoints need rate limiting, what thresholds.
6. **Versioning** — API versioning strategy (path, header, none).

For each endpoint:
```
[METHOD] [path]
  Auth: [public / authenticated / admin]
  Input: { field: type, ... }
  Output: { field: type, ... }
  Errors: [list of possible error codes]
```

### Step 5: Component Architecture

Design the component structure:

1. **Pages** — Route structure and which components each page uses.
2. **Shared components** — Reusable UI components with their props interface.
3. **State management** — Where state lives (server components, URL params, React state, context, external store).
4. **Data flow** — How data moves from database to UI (server components, API calls, real-time subscriptions).

Present as a component tree or directory structure:

```
src/
  app/
    [route]/
      page.tsx          — [description]
      layout.tsx        — [description]
  components/
    [feature]/
      [Component].tsx   — [description, key props]
```

### Step 6: Infrastructure

Define the infrastructure layer:

1. **Hosting** — Where the application runs, why this choice.
2. **CI/CD** — Build pipeline, test stages, deployment triggers.
3. **Monitoring** — Error tracking, performance monitoring, logging.
4. **Caching** — Cache layers (CDN, application cache, database cache), invalidation strategy.
5. **Security** — HTTPS, CSP headers, CORS, secret management, input sanitization.

### Step 7: Write Architecture Document

Write `.maestro/architecture.md` with all sections from Steps 2-6.

If updating an existing architecture document:
- Clearly mark what changed with `[NEW]` or `[CHANGED]` annotations.
- Explain the rationale for each change.
- Note any migration steps required to move from old to new architecture.

### Step 8: Validate

Before finalizing, check:

- [ ] Every strategy requirement has a corresponding architecture decision.
- [ ] No technology choice contradicts existing project constraints.
- [ ] Data model supports all identified query patterns.
- [ ] API design covers all user-facing features.
- [ ] Infrastructure choices fit the budget and scale requirements.
- [ ] No circular dependencies in the component architecture.

## Output

- `.maestro/architecture.md` — Complete architecture document
- Architecture decisions inform `decompose` for story generation (data stories, API stories, frontend stories, infra stories)
