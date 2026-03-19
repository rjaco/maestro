---
name: cost-routing
description: "3-tier cost-aware routing for agent dispatch. Classifies tasks as free (bash command), budget (haiku), or premium (sonnet/opus) before any agent is dispatched. Runs before delegation's model selection and can short-circuit a dispatch entirely."
---

# Cost-Aware Routing

Determines the cheapest adequate execution path for every task before dispatch. Cost-routing runs as the first gate in the delegation pipeline — it may resolve a task without any LLM call, or it constrains which model tier is eligible before delegation's signal scoring takes over.

**Core principle:** Never spend a token when a bash command will do. Never use Sonnet when Haiku is sufficient. The goal is the cheapest path that meets the quality bar for the task.

---

## The 3 Tiers

### Tier 0 — Free (No LLM)

Tasks resolved by a direct bash command or a deterministic file operation. Zero tokens spent.

**Qualifying patterns (keyword matching on story description):**

| Pattern | Example | Resolution |
|---------|---------|------------|
| `rename file` / `move file` | "Rename auth.ts to auth.service.ts" | `mv src/auth.ts src/auth.service.ts` |
| `format` / `lint fix` | "Run prettier on the utils directory" | `npx prettier --write src/utils/` |
| `add import` | "Add React import to Button.tsx" | Edit file: prepend import line |
| `apply lint fix` | "Fix ESLint no-unused-vars in config.ts" | Run `eslint --fix` |
| `delete file` / `remove file` | "Delete the legacy migration script" | `rm path/to/file` |
| `update version` | "Bump package.json version to 2.1.0" | `npm version 2.1.0 --no-git-tag-version` |
| `sort imports` | "Sort import statements in index.ts" | Run import-sort tool |
| `generate types` | "Regenerate Prisma client types" | `npx prisma generate` |

**Detection rule:** Check if the story description matches any free-tier pattern. If yes, resolve immediately with a bash command. Log the resolution as a `free` dispatch in `.maestro/state.local.md`. Do not invoke delegation.

**Constraint:** Free-tier resolution must be reversible (git-tracked) and must not require reasoning about code behavior. If there is any ambiguity about _what_ to rename or _which_ lint rule applies, escalate to Budget tier.

---

### Tier 1 — Budget (Haiku)

Tasks that are simple, repetitive, or clearly template-following. Haiku is dispatched via delegation with the model pre-selected — delegation's signal scoring is skipped.

**Qualifying signals:**

| Signal | Examples |
|--------|---------|
| Boilerplate generation | New CRUD route matching an existing pattern |
| Config file creation | Add ESLint rule, update tsconfig, add env variable |
| Styling changes | Update CSS class names, adjust Tailwind variants |
| Repetitive patterns | Copy a component structure and rename it |
| Simple test fixtures | Add a mock data file matching an existing schema |
| Documentation stubs | Generate JSDoc from function signatures |
| Single-file, no logic | Pure data transformation with a known schema |

**Delegation score pre-condition:** Budget tier applies when delegation's signal scoring would produce a score of 0–3. Cost-routing does not re-score; it checks whether all high-cost signals are absent:
- No security sensitivity (score 0 on that dimension)
- No novel pattern (score 0 or 1)
- No significant ambiguity (score 0 or 1)
- File count is 1–2

If all four conditions hold, pre-select `haiku` and pass to delegation with `model_override: haiku` for this dispatch only.

**Quality gate:** If a budget-tier task returns `NEEDS_CONTEXT` or fails QA review on the first attempt, escalate to Premium tier for the retry. Do not retry with haiku on the same task after a failure.

---

### Tier 2 — Premium (Sonnet / Opus)

Tasks that require reasoning, judgment, novelty, or high-stakes correctness. Delegation's full signal scoring applies.

**Qualifying signals:**

| Signal | Tier | Examples |
|--------|------|---------|
| Architecture decisions | Sonnet/Opus | New service layer, database schema design |
| Security-sensitive code | Sonnet/Opus | Auth middleware, token handling, input sanitization |
| Novel code (no prior pattern) | Sonnet | First implementation of a new feature type |
| Edge case handling | Sonnet | Retry logic, distributed error handling, race conditions |
| Complex algorithms | Sonnet/Opus | Parsing, optimization, state machines |
| Multi-file refactors | Sonnet | Changing a shared abstraction across 5+ files |
| 2+ prior QA rejections | Opus | Task has already failed at lower tiers |
| High ambiguity spec | Opus | Story has significant gaps or conflicting requirements |

**Score → Model:**

| Delegation Score | Model |
|----------------|-------|
| 0–3 | haiku (Budget tier pre-selected this) |
| 4–7 | sonnet |
| 8+ | opus |

Cost-routing does not override delegation's scoring for premium tasks. It only ensures that the pre-conditions for budget are clearly absent, so delegation runs its full scoring without interference.

---

## Decision Tree

```
Incoming task
     |
     v
Does the story description match a free-tier pattern?
     |               |
    YES              NO
     |               |
     v               v
Resolve with    Does the task pass ALL
bash command.   budget-tier conditions?
Log as free.         |          |
Skip dispatch.      YES         NO
                     |          |
                     v          v
              Pre-select    Run delegation
              haiku.        full signal scoring.
              Dispatch.     sonnet or opus.
              Skip scoring.
```

---

## Routing Decision Log

Every routing decision is logged to `.maestro/logs/cost-routing.md`:

```
[2026-03-18T10:14:02Z] TASK: rename auth.ts to auth.service.ts
  TIER: free
  RESOLUTION: mv src/auth.ts src/auth.service.ts
  TOKENS: 0

[2026-03-18T10:21:44Z] TASK: add new CTA button matching existing Button component
  TIER: budget
  MODEL: haiku
  REASON: boilerplate, single file, clear template, no security
  TOKENS: 812 (estimated)

[2026-03-18T10:45:11Z] TASK: implement JWT rotation logic with sliding window expiry
  TIER: premium
  MODEL: sonnet
  DELEGATION_SCORE: 6 (security: 2, pattern novelty: 2, logic: 1, file count: 1)
  TOKENS: 4,210 (estimated)
```

---

## Integration with Delegation

Cost-routing runs **before** delegation's model selection (Decision 2). The call sequence is:

1. Orchestrator receives a story or task
2. **Cost-routing evaluates the task** (free / budget / premium)
3. If free: resolve with bash, log, done
4. If budget: set `model_override: haiku` for this dispatch only, then call delegation
5. If premium: call delegation with no override; full signal scoring applies

Delegation's override priority chain still applies inside a dispatch:
1. Story-level `model` field (highest)
2. `model_override` from cost-routing (budget pre-selection)
3. Global `model_override` from `.maestro/state.local.md`
4. Escalation rules (never downgrade after escalation)
5. Signal scoring (default)

---

## Budget Guardrails

Cost-routing also enforces session-level spend limits.

**Per-story cap:** If a single story has consumed more than 3× its estimated complexity budget (tracked in token-ledger), cost-routing blocks further dispatch on that story and surfaces a warning:

```
[cost-routing] Story 04 has exceeded 3x its cost estimate.
  Estimated: ~2,000 tokens | Actual: 6,842 tokens
  Recommended: split the story or provide additional context before re-dispatching.
```

**Session budget alert:** If cumulative session tokens exceed a configurable `session_budget` (set in `.maestro/config.yaml`, default: 100,000 tokens), cost-routing emits a warning before each new dispatch and requires confirmation to continue.

**Haiku trust gate:** If haiku's first-pass QA rate on this project falls below 0.5 (tracked in delegation's trust.yaml), cost-routing automatically raises the budget-tier ceiling — tasks that would normally be routed to haiku are re-scored by delegation instead. This prevents throwing cheap tokens at tasks that haiku demonstrably cannot handle.

---

## Configuration

Set in `.maestro/config.yaml`:

```yaml
cost_routing:
  enabled: true                     # Set to false to skip tier evaluation and always use delegation scoring
  free_tier: true                   # Allow bash-command resolution
  budget_tier: true                 # Allow haiku pre-selection
  session_budget: 100000            # Token alert threshold (0 = no limit)
  haiku_trust_floor: 0.5            # Minimum first-pass rate before haiku is suppressed
  log_decisions: true               # Write every routing decision to cost-routing.md
```

---

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `delegation` | Cost-routing is a pre-filter; delegation handles the actual dispatch mechanics |
| `model-router` | Model-router scores complexity for premium tasks; cost-routing decides whether to invoke model-router at all |
| `token-ledger` | Reads per-story and per-session token totals for budget guardrail checks |
| `token-budget` | Cost-routing enforces the budget; token-budget tracks and visualizes spend |
| `squad` | Squad model assignments override cost-routing's budget pre-selection only if the squad specifies an explicit model |
