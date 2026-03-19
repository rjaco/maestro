---
name: context-inject
description: "Pre-dispatch project knowledge injection. Runs before every agent dispatch to prepend SOUL, preferences, CLAUDE.md rules, ADRs, and active lessons into the agent prompt. Handles PROJECT-LEVEL knowledge; the Context Engine handles TASK-SPECIFIC knowledge."
effort: low
maxTurns: 5
disallowedTools:
  - Edit
  - Write
  - Bash
---

# Context Inject

Runs as a pre-processing step before every agent dispatch. Assembles a compressed block of project-level knowledge — principles, constraints, architecture decisions, and active lessons — and prepends it to the agent prompt before the Context Engine's task-specific package is attached.

**Core distinction:**

| Skill | Handles | Scope |
|-------|---------|-------|
| `context-inject` | PROJECT knowledge | Stable: SOUL, preferences, CLAUDE.md, ADRs, lessons |
| `context-engine` | TASK-SPECIFIC knowledge | Dynamic: story spec, file contents, patterns, QA history |

Context Inject runs first. Its output is a fixed header in the agent prompt. The Context Engine then appends the task-specific package below it.

---

## What Gets Injected

Five knowledge sources are assembled into the injection block:

| # | Source | File/Location | What it provides |
|---|--------|--------------|-----------------|
| 1 | SOUL | `.maestro/soul.md` or `~/.claude/maestro-soul.md` | Decision principles, quality bar, autonomy level, learned patterns |
| 2 | Preferences | `~/.claude/maestro-preferences.md` | Developer's global tech stack and coding conventions |
| 3 | CLAUDE.md rules | `CLAUDE.md` (project root and any nested) | Project-specific constraints, naming conventions, NEVER/ALWAYS rules |
| 4 | ADRs | `.maestro/adrs/*.md` | Architecture decisions that constrain future implementation |
| 5 | Active lessons | `.maestro/state.local.md` → `tuning.qa_gotchas` | Patterns learned from prior QA failures in this project |

---

## Injection Priority Order

Sources are assembled highest-priority first. When the total exceeds the 800-token budget, lower-priority sources are trimmed from the bottom.

```
1. SOUL              (highest — orchestrator identity and quality bar)
2. Preferences       (developer intent overrides project convention)
3. CLAUDE.md rules   (project constraints and style enforcement)
4. ADRs              (architecture decisions that constrain new code)
5. Active lessons    (lowest — learned patterns from this project's history)
```

Higher-priority blocks are never trimmed to make room for lower-priority ones. If SOUL + Preferences already consume the full budget, no ADRs or lessons are injected.

---

## Token Budget

**Total injection budget: 800 tokens (compressed).**

This is a hard ceiling. The injection block is prepended to every agent invocation, so its cost multiplies across the full dispatch pipeline. Keeping it under 800 tokens ensures the overhead is predictable and bounded.

**Per-source token targets:**

| Source | Target | Hard Max | Behavior when over |
|--------|--------|----------|--------------------|
| SOUL | 150–300 | 350 | Trim `Learned Patterns` section first, then `Communication Style` |
| Preferences | 100–200 | 250 | Trim `Conventions` first, never trim `Anti-Patterns` |
| CLAUDE.md rules | 100–200 | 250 | Keep only NEVER/ALWAYS rules and general rules; drop path-specific rules |
| ADRs | 50–150 | 200 | Include only Decision line per ADR (omit Context and Consequences) |
| Active lessons | 50–100 | 150 | Cap at 5 most recent/relevant; drop the rest |

**Total ceiling enforcement:**

1. Assemble all sources at their target sizes.
2. Sum token counts.
3. If over 800: trim from the bottom (lessons first, then ADRs, then CLAUDE.md rules) until under budget.
4. Never trim SOUL or Preferences — they are always injected at full fidelity within their hard maxes.

---

## Assembly Protocol

### Step 1: Load SOUL

Read `.maestro/soul.md`. If absent, read `~/.claude/maestro-soul.md`. If neither exists, skip SOUL injection entirely — do not use template defaults for injection (they are too generic to be useful as constraints).

Extract the sections in this order: Decision Principles, Quality Bar, Learned Patterns, Autonomy Level. Drop Communication Style (agent-facing injection, not orchestrator style).

### Step 2: Load Preferences

Call `preferences.load()`. If preferences file does not exist, skip this source.

Use the full `preferences.build_context()` block as-is. The `Priority: HIGH` header is load-bearing — preserve it.

### Step 3: Load CLAUDE.md Rules

Read all `CLAUDE.md` files in the project (root + any nested). Apply the following filter:

1. Keep all rules containing `NEVER`, `ALWAYS`, `must`, `required`, or `prohibited`.
2. Keep all general rules (no file path references).
3. Drop rules that reference specific directories unless they apply to the current agent's role:
   - Implementers and fixers: keep all rules.
   - QA reviewers: keep all rules (they check against all paths).
   - Researchers and strategists: keep only general rules.

### Step 4: Load ADRs

List all files in `.maestro/adrs/` sorted by filename (newest last). For each ADR, extract only:

- ADR number and title
- `## Decision` section (one-sentence summary only — the first sentence of the Decision section)

Format as a compact list:

```
ADR-0001: Adopt Supabase — Use @supabase/supabase-js, no direct pg queries.
ADR-0002: App Router — Use app/ directory exclusively, no pages/.
ADR-0003: Zod v4 — Use safeParse() + prettifyError() for all validation.
```

Cap at 10 ADRs. If more exist, include the 10 most recent (highest numbers).

### Step 5: Load Active Lessons

Read `.maestro/state.local.md`. Extract `tuning.qa_gotchas` and `tuning.self_heal_gotchas` arrays. Merge them and deduplicate. Format as a compact list:

```
Lessons:
- Always validate null inputs in API route handlers
- Include rate limit tests for /api/ endpoints
- Use optional chaining for strict null checks
```

Cap at 5 lessons. Prioritize by recency, then by relevance to the current agent role.

---

## Output Format

The assembled injection block is prepended to the agent prompt as a clearly delimited section:

```
[Project Context — injected by context-inject]
Priority: These constraints are non-negotiable. They override patterns found elsewhere.

## Principles
- Correctness over speed. Never ship code that silently fails.
- [Additional SOUL principles...]

## Quality Bar
- QA confidence threshold: 85
- Self-heal max cycles: 3

## Developer Preferences
Priority: HIGH — these preferences override project conventions.
- Framework: Next.js (App Router)
- Language: TypeScript (strict mode)
[...]

## Project Constraints (CLAUDE.md)
- NEVER use default exports
- ALWAYS use Zod v4 safeParse() for input validation
- API routes must include Cache-Control headers via CACHE_HEADERS
[...]

## Architecture Decisions
- ADR-0001: Adopt Supabase — Use @supabase/supabase-js, no direct pg queries.
- ADR-0002: App Router — Use app/ directory exclusively, no pages/.

## Active Lessons
- Always validate null inputs in API route handlers
- Include rate limit tests for /api/ endpoints

[End Project Context — 643 tokens]
[/Project Context]
```

The `[End Project Context — N tokens]` line is included for token accounting. The orchestrator logs this count to `.maestro/context-log.md`.

---

## Role Filtering

Not all agents receive all sources. Apply role filtering before assembly:

| Source | orchestrator | implementer | qa-reviewer | fixer | researcher | strategist |
|--------|-------------|-------------|-------------|-------|-----------|-----------|
| SOUL | Full | Principles + Quality Bar only | Quality Bar only | Quality Bar only | Skip | Skip |
| Preferences | Full | Full | Full | Full | Skip | Skip |
| CLAUDE.md | Full | Full | Full | Full | Skip | Full |
| ADRs | Full | Full | Full | Skip | Skip | Full |
| Active lessons | Full | Full | Full | Full | Skip | Skip |

**Rationale:**
- Researchers and strategists operate on external or strategic information — project constraints would distort their analysis.
- Fixers don't need ADRs — they're fixing a specific error, not making architectural decisions.
- SOUL is injected to the orchestrator in full; implementers receive only the directly actionable subset.

---

## Difference from Context Engine

```
                    ┌─────────────────────────────────┐
  Every dispatch    │        context-inject           │
  ──────────────►  │  PROJECT knowledge (stable)     │
                    │  SOUL + prefs + rules + ADRs    │
                    │  800 tokens, compressed          │
                    └──────────────┬──────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────┐
                    │        context-engine           │
                    │  TASK knowledge (dynamic)       │
                    │  story spec + files + patterns  │
                    │  1.5K–8K tokens, role-tiered    │
                    └──────────────┬──────────────────┘
                                   │
                                   ▼
                            agent prompt
```

**context-inject** answers: "What does this agent always need to know about this project?"

**context-engine** answers: "What does this agent need to know about this specific task?"

The two packages are concatenated. context-inject's block comes first (project context sets the frame; task context fills in the detail).

---

## Integration with Delegation

context-inject runs as a preprocessing step inside delegation's Decision 3 (What Context), before the Context Engine is invoked:

```
Decision 3 flow:
  1. context-inject.assemble(role, agent_type) → project_block (800 tokens max)
  2. context-engine.compose(role, story, task) → task_block (tier-budgeted)
  3. prompt = project_block + task_block
  4. Log total token count to .maestro/context-log.md
  5. Dispatch agent with prompt
```

The context-inject token count is deducted from the tier budget BEFORE the Context Engine begins composing the task package. If the injection block is 600 tokens and the tier is T3 (4–8K budget), the Context Engine works with an effective budget of 3,400–7,400 tokens for the task package.

**Budget deduction:**

```
effective_task_budget = tier_budget - injection_tokens
```

The Context Engine must always be given this reduced budget. If `injection_tokens > tier_budget_min`, log a warning and reduce the injection block by trimming from the bottom until it fits within 30% of `tier_budget_min`.

---

## Caching

The injection block is expensive to assemble from scratch for every dispatch — but it changes rarely. Cache the assembled block in the orchestrator's working memory:

**Cache key:** `sha256(soul_mtime + prefs_mtime + claudes_mtime + adrs_mtime + lessons_hash)`

**Invalidation triggers:**

| Event | Invalidate? |
|-------|-------------|
| SOUL file modified | Yes |
| Preferences file modified | Yes |
| Any CLAUDE.md file saved | Yes |
| New ADR written | Yes |
| `tuning.qa_gotchas` updated in state | Yes |
| Story completed (no relevant file changes) | No |
| Model selection change | No |

When the cache is valid, skip reassembly and reuse the cached block. Log a cache hit:

```
[context-inject] Cache hit (key: a3f8c2d). Injection block: 643 tokens. Skipping reassembly.
```

When the cache is invalid, reassemble and update the cache. Log the rebuild:

```
[context-inject] Cache miss (soul.md modified). Reassembling injection block...
[context-inject] New block: 671 tokens. Cache updated.
```

---

## Logging

Every injection is logged to `.maestro/context-log.md`:

```
[2026-03-18T10:14:02Z] context-inject | agent: implementer | story: 03-api-routes
  Block: 643 tokens
  Sources: soul(182), preferences(201), claude-md(148), adrs(62), lessons(50)
  Cache: HIT
  Effective T3 budget after deduction: 3,400–7,400 tokens
```

---

## Integration Points

- **Invoked by:** `delegation` skill (Step 3, before Context Engine)
- **Reads:** `.maestro/soul.md`, `~/.claude/maestro-soul.md`, `~/.claude/maestro-preferences.md`, `CLAUDE.md` (project root + nested), `.maestro/adrs/*.md`, `.maestro/state.local.md` (`tuning` section)
- **Writes to:** `.maestro/context-log.md` (append-only, injection log entries)
- **Feeds into:** `context-engine` (reduces available task-package budget by injection token count)
- **Depends on:** `preferences` skill (`load()` and `build_context()` operations), `soul` skill (file resolution logic)
