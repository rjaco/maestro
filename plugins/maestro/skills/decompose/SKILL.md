---
name: decompose
description: "Break features into 2-8 stories with dependency graph, acceptance criteria, and model recommendations. Use when a feature needs to be decomposed into implementable units."
---

# Decompose

Breaks a feature request into 2-8 implementable stories with a dependency graph, acceptance criteria, complexity estimates, and model recommendations.

## Input

- Feature description (from `$ARGUMENTS` or upstream classifier)
- Project DNA (`.maestro/dna.md`) for tech stack, patterns, and conventions
- `--skip-clarify` flag — if present, skip Phase 0 and proceed directly to decomposition

## Process

### Phase 0: Clarify

Skip this phase if `--skip-clarify` is present in `$ARGUMENTS`.

#### 0.1 — Scan for Ambiguities

Read the feature description and identify:

- **Ambiguous requirements** — aspects that can be interpreted multiple ways (e.g., "user authentication" could mean email/password, OAuth, or both)
- **Missing specifications** — decisions the user needs to make before implementation can be scoped correctly (auth strategy, data model, UI framework, API design)
- **Edge cases** — failure modes, empty states, concurrent access, rate limiting

Only flag items that would meaningfully change how the feature is decomposed. Skip this phase entirely (proceed to Step 1) if the feature description is fully self-contained and unambiguous.

#### 0.2 — Present Clarification Summary

If ambiguities were found, present them using AskUserQuestion with the following structured format:

```
+---------------------------------------------+
| Clarification Needed                        |
+---------------------------------------------+
  Ambiguous:
    [1] "user authentication" — email/password? OAuth? Both?
    [2] "dashboard" — admin dashboard or user-facing?

  Missing:
    [3] No data model specified — what entities are needed?
    [4] No error handling strategy mentioned

  Edge Cases:
    [5] What happens if the user has no data yet? (empty state)
    [6] Rate limiting on the API endpoints?
```

Use AskUserQuestion:
- Question: "Want to clarify these before I decompose?"
- Header: "Clarification Needed"
- Options: "Clarify now" / "Skip — decompose as-is" / "I'll answer inline"

#### 0.3 — Handle Response

**"Clarify now"** — Present each numbered item as an individual question. Collect all answers before proceeding to Step 1. Incorporate the answers into the feature description used for decomposition.

**"Skip — decompose as-is"** — Proceed to Step 1. At the top of the decomposition output, include an "Assumptions" block listing how each ambiguous item was resolved:

```
Assumptions (unresolved — flagged for review):
  [1] Assumed email/password auth only
  [2] Assumed user-facing dashboard
  [3] Assumed minimal data model — single entity
```

**"I'll answer inline"** — Present all items as a single numbered list and let the user type free-form answers. Parse the answers and incorporate them before proceeding to Step 1.

---

### Step 1: Read Context

1. Read the feature description carefully. Identify every distinct concern.
2. Read `.maestro/dna.md` for project conventions, tech stack, file structure, and existing patterns.
3. If a `CLAUDE.md` exists in the project root, read the relevant sections (architecture, file organization, allowed modifications).
4. If the feature touches existing code, scan the relevant directories to understand current structure.

### Step 2: Analyze Scope

Determine the number of distinct concerns:

| Concern Type | Examples |
|-------------|----------|
| Data layer | New tables, schema changes, migrations, seed data |
| Backend | API routes, server functions, business logic, validation |
| Frontend | New pages, components, layouts, styling |
| Integration | External APIs, webhooks, third-party services |
| Infrastructure | Config, deployment, environment, CI/CD |
| Testing | Unit tests, integration tests, e2e tests |

Count how many files will be created or modified. This informs the number of stories.

### Step 3: Generate Stories

Create 2-8 stories. Each story must be:

- **Atomic** — Delivers one testable unit of work
- **Independent where possible** — Minimize cross-story dependencies
- **Ordered by dependency** — Foundation stories first, integration stories last
- **Right-sized** — Not so small it is trivial, not so large it is unwieldy

For each story, determine:

#### ID and Metadata

- `id`: Sequential integer (1, 2, 3...)
- `slug`: Kebab-case descriptor (e.g., `user-auth-api`, `dashboard-layout`)
- `title`: Human-readable title
- `type`: One of `frontend`, `backend`, `integration`, `data`, `infrastructure`

#### Dependencies

- `depends_on`: List of story IDs this story requires to be completed first
- `parallel_safe`: `true` if this story can run in a separate worktree alongside other parallel-safe stories with no `depends_on` conflicts

Dependency rules:
- Data stories typically have no dependencies (they come first)
- Backend stories depend on data stories
- Frontend stories depend on backend stories (unless using mocked data)
- Integration stories depend on both backend and frontend
- Infrastructure stories are often independent

#### Complexity Estimation

| Complexity | Estimated Tokens | Signals |
|-----------|-----------------|---------|
| Simple | ~20,000 | Single file, clear pattern to follow, config change, simple CRUD |
| Medium | ~35,000 | 2-4 files, some logic, needs tests, follows existing patterns |
| Complex | ~50,000 | 5+ files, new patterns, edge cases, significant business logic |

#### Model Recommendation

| Model | When to Use |
|-------|------------|
| `haiku` | Boilerplate, config files, simple CRUD, repetitive patterns, styling tweaks |
| `sonnet` | Standard features, moderate logic, test writing, component building |
| `opus` | Complex architecture, novel algorithms, security-critical code, subtle edge cases |

#### Acceptance Criteria

Write 3-6 clear, testable criteria per story. Each criterion must be verifiable by running code or inspecting output. Avoid vague criteria like "works correctly" — be specific about inputs, outputs, and behavior.

#### Context for Implementer

Provide bullet points the implementer agent will need:
- Which existing patterns to follow (with file path references)
- Which utilities/helpers to use
- Which conventions apply (from CLAUDE.md or project DNA)
- Any gotchas or non-obvious constraints

#### Files

List files to:
- **Create** — New files this story introduces
- **Modify** — Existing files this story changes
- **Reference** — Files the implementer should read for context (not modified)

### Step 4: Write Story Files

Write each story to `.maestro/stories/NN-slug.md` using the format defined in `story-template.md`.

Create the directory if it does not exist:
```
.maestro/stories/
  01-slug.md
  02-slug.md
  ...
```

### Step 5: Generate Dependency Graph

Visualize the dependency graph as ASCII art:

```
01-data-schema
  |
  v
02-api-routes -----> 04-integration-tests
  |
  v
03-frontend-ui
```

Mark parallel-safe stories with `[P]`:

```
01-data-schema
  |
  +--> 02-api-routes
  |       |
  |       v
  |    04-integration-tests
  |
  +--> 03-frontend-ui [P]
```

### Step 6: Present for Approval

Show the user:

1. The story list (ID, title, type, model, estimated tokens)
2. The dependency graph
3. Total estimated token cost
4. Recommended execution order

Ask: "Ready to build? You can reorder, skip, add, or modify stories before execution begins."

**Important**: Story approval MUST use AskUserQuestion:
- Question: "Decomposed into [N] stories. Approve this plan?"
- Header: "Stories"
- Options: Approve and start (Recommended) / Adjust stories / Abort

The user can:
- **Approve** — Proceed to `dev-loop`
- **Reorder** — Change execution sequence (within dependency constraints)
- **Skip** — Mark stories to skip (with reason noted)
- **Add** — Request additional stories
- **Modify** — Change scope, acceptance criteria, or model for specific stories
- **Abort** — Cancel decomposition

## Output

- Story files in `.maestro/stories/NN-slug.md`
- Dependency graph logged to `.maestro/state.local.md`
- Story manifest (ordered list with metadata) for `dev-loop` consumption
