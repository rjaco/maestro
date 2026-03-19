---
name: skill-budget
description: "Documents and enforces frontmatter budget controls for Maestro skills. Defines effort, maxTurns, and disallowedTools fields, provides recommended values per skill category, and maps effort levels to model tiers for cost-routing integration."
---

# Skill Budget Controls

Maestro skills declare their own compute budget directly in YAML frontmatter. This lets the orchestrator reason about skill cost before invoking them and allows cost-routing to pre-select the appropriate model tier without running full signal scoring.

Claude Code v2.1 introduced three skill-level budget fields: `effort`, `maxTurns`, and `disallowedTools`.

---

## Frontmatter Budget Fields

### `effort`

Signals the expected reasoning load of the skill. Maps directly to cost-routing's model tier.

| Value | Meaning | Model tier |
|-------|---------|-----------|
| `low` | Minimal reasoning required. Retrieving state, formatting output. | haiku |
| `medium` | Standard reasoning. Executing a defined protocol with some branching. | sonnet |
| `high` | Deep reasoning required. Novel problems, multi-step synthesis, cross-cutting decisions. | opus |

When `effort` is present, cost-routing reads it before calling delegation's signal scorer. If `effort` is `low`, cost-routing pre-selects haiku (equivalent to a budget-tier pre-selection). If `effort` is `high`, cost-routing skips budget-tier evaluation entirely and routes directly to premium scoring.

**Default when absent:** `medium`.

### `maxTurns`

Hard cap on the number of agentic turns the skill may use. Prevents runaway loops and bounds worst-case token spend.

| Value | When to use |
|-------|-------------|
| 2–5 | Skills that read state or emit a formatted block — no tool iteration needed |
| 10–20 | Skills that perform a bounded search or a fixed protocol (e.g., 5 steps with verification) |
| 30–50 | Skills that may need to explore multiple paths or self-correct (e.g., complex planners) |

If the skill reaches `maxTurns` without completing, it must return `STATUS: BLOCKED` with a reason. The orchestrator decides whether to re-dispatch or surface to the user.

**Default when absent:** the runtime default (currently 50).

### `disallowedTools`

List of tool names the skill is prohibited from calling. Use this to enforce read-only guarantees for audit, review, or status skills.

Common values:

| Tool | When to disallow |
|------|-----------------|
| `Edit` | Skill must not modify files (review, audit, status skills) |
| `Write` | Skill must not create files |
| `Bash` | Skill must not execute shell commands |
| `Edit, Write` | Skill is fully read-only |
| `Edit, Write, Bash` | Skill is strictly observational — no side effects |

`disallowedTools` is enforced by the runtime before the skill runs. A skill that attempts to call a disallowed tool will have the call rejected with an error — this is a hard guardrail, not a soft suggestion.

**Default when absent:** no restrictions.

---

## Recommended Values by Skill Category

### Quick Operations

Skills that read existing state and emit a formatted summary. No file modifications, no iteration.

**Examples:** `token-budget summary`, `maestro status`, `/list` commands, `cost-dashboard`

```yaml
effort: low
maxTurns: 5
disallowedTools:
  - Edit
  - Write
  - Bash
```

### Standard Operations

Skills that execute a bounded protocol with conditional branching. May read files and make dispatch decisions.

**Examples:** `delegation`, `context-engine`, `model-router`, `checkpoint`, `git-craft`

```yaml
effort: medium
maxTurns: 30
```

### Complex Operations

Skills that require deep reasoning, multi-pass synthesis, or novel decision-making with unclear paths upfront.

**Examples:** `opus` deep research, `retrospective` cross-milestone analysis, `architecture` design sessions, `soul evolve`

```yaml
effort: high
maxTurns: 50
```

### Read-Only Operations

Skills that inspect artifacts without ever modifying them. QA reviewers, auditors, and monitors fall here.

**Examples:** `qa-reviewer`, `audit-log`, `compatibility`, `benchmark`

```yaml
effort: medium
maxTurns: 30
disallowedTools:
  - Edit
  - Write
```

---

## Adding Budget Controls to an Existing Skill

Open the skill's frontmatter and add the relevant fields. Add only the fields you intend to set — unset fields use their defaults.

**Before:**

```yaml
---
name: token-ledger
description: "Tracks cumulative token spend per story, model, and session."
---
```

**After:**

```yaml
---
name: token-ledger
description: "Tracks cumulative token spend per story, model, and session."
effort: low
maxTurns: 5
disallowedTools:
  - Edit
  - Write
  - Bash
---
```

**Decision guide for existing skills:**

1. Does the skill ever modify files or run bash commands? If no, add `disallowedTools: [Edit, Write, Bash]`.
2. Does the skill have a fixed protocol with a known number of steps? Set `maxTurns` to `(steps × 3)` as a safe ceiling.
3. Is the skill primarily a formatter/reader? Set `effort: low`. Does it do significant reasoning? `medium`. Is it a deep analysis or design task? `high`.

---

## Effort-to-Model Mapping in Cost-Routing

Cost-routing reads the `effort` field before calling delegation. The mapping:

```
effort: low   → pre-select haiku (budget tier, bypass signal scoring)
effort: medium → run delegation's full signal scoring
effort: high  → skip budget-tier check, route directly to sonnet/opus via signal scoring
```

This creates a fast path for skills with declared effort levels. Skills without an `effort` field always go through delegation's full signal scoring.

**Override chain (highest priority first):**

1. Story-level `model` field — user explicit override always wins
2. Global `model_override` in `.maestro/state.local.md`
3. `effort: high` — ensures opus/sonnet consideration without haiku bypass
4. `effort: low` — pre-selects haiku, equivalent to budget-tier pre-selection
5. Delegation's full signal scoring — fallback when `effort` is absent or `medium`

**Example: skill with `effort: low` routed to haiku**

```
cost-routing: token-budget/summary
  effort: low → budget-tier pre-selection
  model: haiku
  signal scoring: skipped
```

**Example: skill with `effort: high` routed via full scoring**

```
cost-routing: retrospective/analyze
  effort: high → premium tier, full scoring
  delegation score: 14/30 → sonnet
  override: none
```

---

## maxTurns Budget Enforcement

When a skill hits its `maxTurns` limit mid-execution:

1. The runtime halts the skill's agentic loop.
2. The skill must emit `STATUS: BLOCKED` with the reason `maxTurns reached`.
3. The orchestrator logs the event to `.maestro/logs/decisions.md`.
4. The orchestrator decides whether to re-dispatch (with a higher `maxTurns` override) or surface to the user.

**Re-dispatch with a higher turn ceiling (use sparingly):**

```yaml
# dispatcher can override maxTurns for a single invocation:
maxTurns_override: 60
```

Log every override with a reason. A skill consistently hitting its `maxTurns` is a signal that the limit was set too low or the skill needs refactoring.

---

## Integration Points

| Skill | Relationship |
|-------|-------------|
| `cost-routing` | Reads `effort` field before every skill dispatch to determine tier pre-selection |
| `delegation` | Receives the model pre-selection from cost-routing; `effort: low` bypasses signal scoring |
| `model-router` | Only invoked when `effort` is `medium` or absent; `effort: high` sends directly to premium scoring |
| `token-budget` | `maxTurns` bounds worst-case token spend; feeds into pre-dispatch cost estimation |
| `token-ledger` | Records actual turns used alongside token spend for calibration |

---

## Reference: Live Examples in This Codebase

`skills/token-budget/SKILL.md` — a read-only budget enforcement skill:

```yaml
effort: low
maxTurns: 2
disallowedTools:
  - Write
  - Edit
  - Bash
```

Use this as the canonical reference when adding budget controls to other read-only skills.
