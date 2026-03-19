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

## Cross-Session Intelligence

Tracks which files were accessed, which context packages worked, and uses that history to improve context selection in future sessions. Inspired by Windsurf's Cascade memory model.

### File Access Pattern Tracking

At the end of every session, append learned file patterns to `.maestro/memory/context-history.md`. The file is human-readable and manually editable.

**Storage format:**

```markdown
## File Access Patterns
- [auth features] → src/auth/*, src/middleware/*, tests/auth/*
- [API endpoints] → src/routes/*, src/validators/*, tests/api/*
- [UI components] → src/components/*, src/styles/*, tests/components/*
- [database] → src/db/*, src/models/*, prisma/*, tests/db/*
- [payments] → src/billing/*, src/webhooks/stripe/*, tests/billing/*

## Pattern Hit Rates
<!-- Format: feature-type | file-glob | sessions-included | sessions-useful | hit-rate -->
- [auth features] | src/auth/* | 12 | 11 | 0.92
- [auth features] | src/middleware/* | 12 | 9 | 0.75
- [API endpoints] | src/routes/* | 18 | 18 | 1.00
- [API endpoints] | src/validators/* | 18 | 14 | 0.78
- [UI components] | src/styles/* | 7 | 4 | 0.57

## Session Log
<!-- One line per session with outcome -->
- 2026-03-17 | story:auth-refresh | feature:auth | outcome:QA_PASS | package:3412t | missing:none
- 2026-03-17 | story:search-api | feature:API endpoints | outcome:NEEDS_CONTEXT | package:2800t | missing:src/cache/manager.ts
- 2026-03-16 | story:login-form | feature:UI components | outcome:QA_PASS | package:5100t | missing:none
```

**Feature-type detection:** Classify the current story's feature type by matching keywords from the story title and acceptance criteria against known feature types. If no match is found, classify as `unknown` and record without pre-including files.

| Keyword signals | Feature type |
|----------------|--------------|
| auth, login, session, token, permission, role | auth features |
| route, endpoint, API, REST, GraphQL, request, response | API endpoints |
| component, UI, form, modal, page, layout, style | UI components |
| database, query, migration, schema, model, ORM | database |
| payment, billing, subscription, invoice, stripe | payments |

### Learning Signals

The context engine updates `.maestro/memory/context-history.md` based on three outcome signals:

**Signal 1 — NEEDS_CONTEXT (negative signal):**
When an implementer returns `NEEDS_CONTEXT`, record which files were missing. These files were under-represented in the context package.

```
Action: Append to Session Log with outcome:NEEDS_CONTEXT and missing:<file-path>
Action: Increment sessions-included for existing patterns, do NOT increment sessions-useful
Action: If the missing file belongs to a recognizable glob, add a new Pattern Hit Rate entry
```

**Signal 2 — QA passes first try (positive signal):**
When a QA reviewer returns DONE on the first attempt (no prior self-heal or NEEDS_CONTEXT in the same story), record the context package as "good".

```
Action: Append to Session Log with outcome:QA_PASS and missing:none
Action: Increment both sessions-included and sessions-useful for all globs that were included
```

**Signal 3 — Self-heal succeeds (error-to-file mapping):**
When self-heal resolves an error, record the error category → file mapping. This improves T4 fix packages.

```
Action: Append to Session Log with outcome:SELF_HEAL_PASS
Action: Record the error type and which file contained the fix under a ## Self-Heal Patterns section
```

**Self-heal pattern format:**

```markdown
## Self-Heal Patterns
- [TypeScript type error] → src/types/*, tsconfig.json
- [ESLint rule violation] → .eslintrc.*, src/**/*.ts (file where error occurred)
- [missing import] → src/lib/*, src/utils/*, package.json
- [test assertion failure] → tests/*, src/<file-under-test>
```

### Context Prediction

Before composing a context package for a T3 implementer or T4 fix agent, check `.maestro/memory/context-history.md` for pre-established patterns.

**Prediction algorithm:**

1. Detect the story's feature type from keyword signals (see table above).
2. Look up all Pattern Hit Rate entries for that feature type.
3. Collect file globs where `hit-rate > 0.7`.
4. Resolve those globs against the current project tree (use `git ls-files`).
5. Score the resolved files using the normal relevance filter (Step 3).
6. Pre-include any file that scores above the T3 threshold (0.5) AND has a hit-rate above 0.7.
7. Label these files as `[predicted]` in the assembled package so the implementer knows they were added proactively.

**Confidence log entry:**

```
[2026-03-18T09:10:00] Story 07-auth-refresh | Prediction: auth features
  Pre-included (hit-rate ≥ 0.70): src/auth/session.ts(0.92), src/middleware/auth.ts(0.75)
  Skipped (hit-rate < 0.70): src/auth/oauth.ts(0.50)
  Predicted tokens: +612 | New total: 4,024 (within T3 budget)
```

**When no history exists:** Skip prediction entirely. Do not pre-include any files on guesses. Build history first.

**When history exists but hit-rate is below 0.7 for all files:** Skip prediction. Include only what the standard relevance filter selects.

### Recent Changes Awareness

At session start, check for files modified since the last recorded session in `.maestro/memory/context-history.md`.

**Step-by-step:**

1. Read the last session date from the Session Log (most recent entry).
2. Run: `git log --since="<last-session-date>" --name-only --pretty=format: | sort -u`
3. Collect the resulting file list as "recently changed files".
4. When composing any context package, cross-reference the story's file list against recently changed files.
5. If any file the story touches was also recently changed, flag it in the package.

**Flag format in composed package:**

```
Files (flagged):
  src/auth/session.ts [lines 1-60] — [RECENTLY CHANGED: modified since last session]
  src/middleware/auth.ts [lines 10-45]
```

**Warn the implementer:**

Prepend a warning block to the context package when any flagged file is present:

```
[!] RECENT CHANGES DETECTED
The following files were modified since the last recorded session and may conflict
with assumptions in this story:
  - src/auth/session.ts (changed 2026-03-17)
Review these files carefully before implementing. Interfaces or behaviors may have shifted.
```

**If no session log exists yet:** Skip recent-changes check. There is no baseline to diff against.

### Integration with Memory Skill

The memory skill and context engine serve complementary roles. They do not duplicate each other.

| Concern | Memory Skill | Context Engine |
|---------|-------------|----------------|
| Scope | Semantic facts about the project (decisions, constraints, patterns, why) | Tactical file-level context for a specific agent dispatch |
| Storage | `.claude/agent-memory/` | `.maestro/memory/context-history.md` |
| Lifetime | Persistent across all sessions, manually curated | Persistent across sessions, auto-updated by outcomes |
| Input to agent | "What to do and why" — project knowledge, conventions, rationale | "Where to do it" — the exact files, line ranges, and interfaces needed |
| Updated by | User edits, agent memory writes | Context engine itself, based on NEEDS_CONTEXT / QA_PASS / SELF_HEAL signals |

**Composition rule:** When building a T3 or T4 package, pull semantic facts from the memory skill first (constraints, conventions, rationale), then layer file-level context from the context engine on top. The memory skill is read-only input to the context engine's Step 3 (relevance filter) — facts stored in memory can raise the relevance score of related files.

**Example:** If memory contains "auth refresh uses sliding window expiry — see src/auth/session.ts", and the current story is tagged `auth features`, that memory fact boosts the relevance score of `src/auth/session.ts` even before the prediction step runs.

## Context Optimization

### Context Deduplication

Before composing a context package, the engine checks for duplicate file contents across all candidate context sources. The same file may appear in multiple places — as a direct story reference, as a pattern match, as a predicted file from context history, and as a recently changed file. Including it multiple times wastes tokens without adding information.

**Deduplication algorithm:**

1. Collect all candidate context pieces from every source (story spec, relevance filter output, predictions, recent-changes flags, memory skill facts).
2. Build a map keyed by canonical file path: `{ "src/auth/session.ts": [piece_A, piece_B] }`.
3. For any file with more than one candidate piece, merge them into a single piece:
   - Use the union of all requested line ranges (e.g., `[1-30]` + `[25-60]` → `[1-60]`).
   - Carry forward all labels from every source (e.g., `[predicted]`, `[RECENTLY CHANGED]`).
   - Keep the highest relevance score of the duplicates.
4. Replace the duplicate entries with the single merged piece.
5. Log the deduplication result:

```
[2026-03-18T10:00:00] Dedup | Story 07-auth-refresh
  Merged: src/auth/session.ts appeared in 3 sources → merged to [1-80], saved 412 tokens
  Merged: src/types/vehicles.ts appeared in 2 sources → merged to [88-140], saved 198 tokens
  Net savings: 610 tokens
```

**Identical content guard:** If two context sources reference the same file at the exact same line range, deduplicate trivially — include once, discard the duplicate. No merge needed.

**Do not deduplicate across different files**, even if their content overlaps (e.g., a type exported from one file and re-exported from another). Treat file path as the identity boundary.

### Cache-Friendly Ordering

Order the assembled context package to maximize Anthropic's prompt caching. Anthropic caches the longest matching prefix of a prompt. Stable content at the front of the context window is more likely to hit the cache on repeated dispatches.

**Ordering tiers (assemble in this sequence):**

1. **Stable context** — content that changes rarely and is shared across many dispatches. Cache hits here yield the highest savings. Include first.
   - `CLAUDE.md` (project conventions)
   - `.maestro/dna.md` (product DNA)
   - Steering documents and global constraints
   - Skill definitions referenced by this agent role

2. **Semi-stable context** — content that changes occasionally (between milestones or sprints, not between stories). Include second.
   - Architecture documents
   - Component maps and API contracts
   - Shared type definitions (e.g., `src/types/*.ts` files that rarely change)
   - Pattern libraries and code conventions extracted from the codebase

3. **Volatile context** — content that changes with every story or dispatch. Include last.
   - Story spec and acceptance criteria
   - Recently changed files (flagged by recent-changes detection)
   - QA feedback from the current session
   - The specific file contents and line ranges targeted by this story

**Why this ordering matters:** Anthropic's cache operates on a prefix match. If the first 8K tokens of a 12K prompt are identical to a prior request, those 8K tokens are served from cache at 10% of the normal input cost. By placing stable content first, repeated dispatches (same session, or next-day continuation) benefit from cache hits on the most expensive context sources.

**Log the ordering in the context log:**

```
[2026-03-18T10:05:00] Cache-friendly assembly | Story 07-auth-refresh
  Stable (6,200 tokens): CLAUDE.md, dna.md, implementer-skill-def
  Semi-stable (1,800 tokens): api-patterns, src/types/vehicles.ts[88-140]
  Volatile (2,400 tokens): story-spec, src/auth/session.ts[1-80][RECENTLY CHANGED], qa-feedback
  Total: 10,400 tokens | Cache prefix opportunity: up to 6,200 tokens
```

**Do not reorder within each tier.** The priority ordering from Step 4 (Compose Package) governs ranking within tiers. This cache-friendly ordering governs the sequence of tiers, not the internal order of items within a tier.

### Relevance Threshold

Only include context pieces that score above the minimum relevance threshold for their tier. Pieces below the threshold add noise without value — they consume token budget and can distract agents with irrelevant information.

**Per-tier thresholds (updated):**

| Tier | Include Threshold | Hard Floor | Max Items |
|------|------------------|------------|-----------|
| T0 | 0.0 (include all) | 0.0 | No limit |
| T1 | 0.2 | 0.15 | 20 |
| T2 | 0.3 | 0.25 | 15 |
| T3 | 0.5 | 0.30 | 10 |
| T4 | 0.7 | 0.50 | 5 |

The **Hard Floor** is the absolute minimum below which a piece is excluded regardless of budget. Even if the assembled package is under budget, pieces below the hard floor are not included — budget slack does not justify including irrelevant content.

**The 0.3 rule:** No file scoring below 0.3 relevance is included in any package, for any tier. Files below this threshold are categorically noise. Log all such exclusions explicitly:

```
Excluded (below 0.3 threshold): vision.md(0.05), roadmap.md(0.08), research-notes.md(0.12),
  competitor-analysis.md(0.21), monetization-strategy.md(0.18)
```

**Threshold override for predicted files:** Files pre-included by the prediction step (based on context history hit-rate ≥ 0.7) bypass the relevance threshold check. They were included because historical evidence suggests they will be needed, not because the relevance scorer scored them highly. Log these separately:

```
Predicted (bypassing threshold): src/auth/session.ts (hit-rate: 0.92, relevance: 0.45 — included via prediction)
```

**Threshold tuning:** After 10+ sessions, the orchestrator may adjust per-tier thresholds based on observed NEEDS_CONTEXT rates. If T3 packages frequently trigger NEEDS_CONTEXT, lower the T3 threshold toward 0.4. If T3 packages are frequently over budget, raise it toward 0.6. Log any threshold adjustments in `.maestro/memory/context-history.md` under a `## Threshold History` section.

## Integration Points

- **Invoked by:** `delegation` skill (every agent dispatch)
- **Reads from:** `.maestro/dna.md`, `.maestro/stories/`, `.maestro/state.local.md`, project CLAUDE.md, source files, `.maestro/memory/context-history.md`
- **Writes to:** `.maestro/context-log.md` (append-only log), `.maestro/memory/context-history.md` (cross-session learning)
- **References:** `references/tier-definitions.md`, `references/relevance-rules.md`, `references/budget-profiles.md`
