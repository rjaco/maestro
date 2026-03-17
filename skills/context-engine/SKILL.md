---
name: context-engine
description: "Optimal context management engine. Composes right-sized context packages for each agent based on role, task, and relevance. Reduces token usage by 70-85% while improving agent performance."
---

# Context Engine

Composes right-sized context packages for each dispatched agent. Instead of dumping the entire project context (CLAUDE.md, DNA, research, stories, history) into every agent invocation, the Context Engine scores each context piece for relevance and assembles a minimal, high-signal package tailored to the agent's role and current task.

A naive approach sends ~24K tokens to every agent. The Context Engine typically produces 1.5-8K packages depending on tier, cutting token spend by 70-85% while improving agent focus and output quality.

## 5-Step Composition Pipeline

### Step 1: Classify Role

Determine what kind of agent will receive this context package.

| Role | Purpose | Default Tier |
|------|---------|-------------|
| `orchestrator` | Coordinates multi-story execution, makes strategic decisions | T0 |
| `strategist` | Vision, research synthesis, competitive analysis, roadmap | T1 |
| `architect` | System design, component boundaries, API contracts, data models | T2 |
| `implementer` | Write code for a specific story | T3 |
| `qa-reviewer` | Review code diff against acceptance criteria | T3 |
| `researcher` | Gather external information, analyze markets | T1 |
| `self-heal` | Fix a specific error from a failed build/lint/test | T4 |

The role is provided by the `delegation` skill when it invokes the Context Engine.

### Step 2: Select Tier

Each tier defines a token budget and determines what categories of context are included or excluded.

| Tier | Name | Budget | Gets | Does NOT Get |
|------|------|--------|------|-------------|
| T0 | Orchestrator | 15-25K | Everything: vision, roadmap, research, DNA, state, stories, agent results, trust scores | Nothing excluded |
| T1 | Strategic | 10-15K | Vision, research, roadmap, competitive intel, market data, DNA summary | File contents, test code, implementation details |
| T2 | Architect | 8-12K | Architecture, component map, API design, data model, milestone scope, DNA | Marketing copy, competitive analysis, monetization strategy |
| T3 | Implementer | 4-8K | Story spec, acceptance criteria, relevant file contents, patterns, interfaces, QA feedback | Other stories, roadmap, research, vision |
| T4 | Fix | 1-3K | Error message, affected file content, relevant fix pattern | Story context, project state, DNA, research |

See `references/tier-definitions.md` for detailed breakdowns.

### Step 3: Relevance Filter

Score each available context piece (0.0-1.0) against the current task. Only include pieces that score above the tier's threshold.

**Scoring signals:**

1. **Story type alignment** — A `backend` story scores API patterns at 1.0 and component patterns at 0.1. A `frontend` story does the reverse. See `references/relevance-rules.md`.

2. **File path matching** — If the story modifies `src/app/api/`, API route conventions score 1.0. If it modifies `src/components/`, component patterns score 1.0. Files outside the story's scope score 0.0-0.2.

3. **Keyword extraction** — Extract keywords from the story title, description, and acceptance criteria. Match against context piece content. "rate limiting" triggers cache/Redis rules. "authentication" triggers security/middleware rules. "form validation" triggers Zod/form rules.

4. **QA history filtering** — Include QA feedback only from stories of the same TYPE as the current story. A frontend implementer does not need backend QA history.

5. **CLAUDE.md rule filtering** — Parse CLAUDE.md rules and include only those that reference files or directories the current story touches. A story modifying `src/app/api/` gets API route rules but not component pattern rules.

**Thresholds:**

| Tier | Include Threshold | Max Items |
|------|------------------|-----------|
| T0 | 0.0 (include all) | No limit |
| T1 | 0.2 | 20 |
| T2 | 0.3 | 15 |
| T3 | 0.5 | 10 |
| T4 | 0.7 | 5 |

### Step 4: Compose Package

Assemble the filtered context pieces in priority order. Each piece is tagged with its token count.

**Assembly order (highest priority first):**

1. **Task instructions** — The story spec, acceptance criteria, files to create/modify. Always included at full fidelity.
2. **Constraints** — Rules from CLAUDE.md that passed the relevance filter. "NEVER modify", "ALWAYS preserve", naming conventions.
3. **Patterns** — Relevant code patterns, conventions, examples. Trimmed to only the sections that scored above threshold.
4. **File contents** — Targeted sections of files the agent needs to read or modify. Use line ranges, not full files. A 500-line file where the agent needs lines 40-80 sends only those lines plus 5 lines of surrounding context.
5. **Interfaces** — Type definitions, function signatures, API contracts that the story's code must conform to. Extracted, not full files.
6. **History** — QA feedback from previous iterations of this story, or from same-type stories in the current session. Only if relevant.

### Step 5: Budget Check

Sum the token counts of all assembled pieces.

- **Within budget?** Dispatch the package as-is.
- **Over budget by less than 20%?** Trim the lowest-scoring items from the bottom of the priority stack (history first, then file contents, then patterns).
- **Over budget by more than 20%?** Aggressively trim: reduce file contents to signatures only, reduce patterns to one-liners, drop history entirely. If still over, bump to the next tier up.

Log the final package composition to `.maestro/context-log.md`:

```
[2026-03-17T14:22:01] Story 03-api-routes | Agent: implementer | Tier: T3
  Composed: 3,412 tokens (budget: 4,000-8,000)
  Included: story-spec(312), rules(198), api-patterns(287), file:route.ts[40-80](423),
            file:types.ts[1-30](189), interfaces(401), qa-feedback-story03(212)
  Excluded: component-patterns(0.12), vision(0.05), roadmap(0.08), research(0.03)
```

## Example: T3 Implementer Package

**Story:** "Add rate-limited `/api/v1/vehicles/search` endpoint with FTS"

**Naive approach (24K tokens):** Full CLAUDE.md (3K) + full DNA (2K) + all stories (4K) + full research (8K) + full architecture (3K) + all referenced files complete (4K) = ~24K tokens.

**Context Engine package (3.4K tokens):**

```
Task (312 tokens):
  Story 03: Add rate-limited /api/v1/vehicles/search endpoint
  Type: backend
  Acceptance: [6 criteria]
  Create: src/app/api/v1/vehicles/search/route.ts
  Modify: src/types/vehicles.ts (add SearchParams type)
  Reference: src/app/api/v1/vehicles/route.ts

Rules (198 tokens):
  - API routes use Zod v4 safeParse() + prettifyError()
  - Rate limiting: Upstash Redis with in-memory fallback (withRateLimit())
  - Responses include Cache-Control headers via CACHE_HEADERS
  - Public API: /api/v1/* uses resolveApiKey() auth

Patterns (287 tokens):
  [Extracted API route pattern from existing route.ts - GET handler structure]

Files (423 + 189 = 612 tokens):
  src/app/api/v1/vehicles/route.ts [lines 1-45] — existing pattern to follow
  src/types/vehicles.ts [lines 88-120] — VehicleFilter type to extend

Interfaces (401 tokens):
  withRateLimit() signature + usage
  resolveApiKey() signature + usage
  CACHE_HEADERS constant shape

QA History (212 tokens):
  [Feedback from story 02 (also backend): "Missing error handler for invalid query params"]
```

**Result:** 3,412 tokens. Agent has everything it needs, nothing it doesn't. 86% reduction.

## Adaptive Escalation

When an agent returns `NEEDS_CONTEXT` with a description of what is missing:

1. **First escalation:** Search excluded context pieces for matches against the agent's description. Add the top 3 matching items. Re-dispatch at the same tier with an expanded budget (+30%).

2. **Second escalation:** Bump the agent to the next tier up (T3 to T2). Recompose the full package at the higher tier's budget and thresholds. Re-dispatch.

3. **Third escalation:** Surface to the user. Present what the agent is asking for and let the user provide the missing context directly or point to specific files.

Log each escalation:

```
[2026-03-17T14:25:00] ESCALATION Story 03 | Agent: implementer
  Reason: "Need to understand the caching layer for search results"
  Action: Added cache-manager.ts[1-60], isr-config.ts[1-25] (+1,200 tokens)
  New total: 4,612 tokens (still within T3 budget)
```

## Integration Points

- **Invoked by:** `delegation` skill (every agent dispatch)
- **Reads from:** `.maestro/dna.md`, `.maestro/stories/`, `.maestro/state.local.md`, project CLAUDE.md, source files
- **Writes to:** `.maestro/context-log.md` (append-only log)
- **References:** `references/tier-definitions.md`, `references/relevance-rules.md`, `references/budget-profiles.md`
