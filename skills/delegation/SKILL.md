---
name: delegation
description: "Dispatch protocol for agent assignment. Classifies tasks, selects models, invokes Context Engine for right-sized context, handles agent responses. Supports parallel dispatch for independent stories."
---

# Delegation

Handles every agent dispatch decision in Maestro. For each task that needs an agent, Delegation answers three questions: Who executes it, What model powers it, and What context it receives. It then dispatches, monitors the response, and routes the outcome.

**Core principle:** The orchestrator NEVER implements directly. Every code change, content creation, and review goes through a dispatched agent. This is enforced by the PreToolUse hook (see hooks/hooks.json) — attempting to Edit/Write files directly during an active Maestro session will be blocked.

## Three Decisions Per Dispatch

### Decision 1: Who (Agent Type)

Select the agent type based on the task classification:

| Task | Agent Type | Subagent Type | Context Tier |
|------|-----------|---------------|-------------|
| Write code for a story | `implementer` | `maestro:maestro-implementer` | T3 |
| Review a code diff | `qa-reviewer` | `maestro:maestro-qa-reviewer` | T3 |
| Fix a build/lint/type error | `fixer` | `maestro:maestro-fixer` | T4 |
| Research market/competitors | `researcher` | `maestro:maestro-researcher` | T1 |
| Synthesize strategy/positioning | `strategist` | `maestro:maestro-strategist` | T1 |
| Scheduled monitoring/health | `proactive` | `maestro:maestro-proactive` | T4 |

If the task does not clearly map to one type, default to `implementer` with a T3 context package.

**Agent capability mapping:**

| Agent | Can Edit Files | Can Search Web | Can Run Bash | Isolation |
|-------|---------------|----------------|-------------|-----------|
| implementer | Yes | No (code) / Yes (knowledge) | Yes | worktree (mandatory) |
| qa-reviewer | **NO** (read-only) | No | Yes (read commands) | none |
| fixer | Yes | No | Yes | worktree (mandatory) |
| researcher | No | Yes | No | none |
| strategist | Yes (writes .maestro/ only) | No | No | none |
| proactive | No | No | Yes (read commands) | none |

### Decision 2: What Model

Select the model using a multi-signal scoring system. Each signal contributes a score; the sum determines the model.

#### Signal Scoring

| Signal | haiku (+0) | sonnet (+1) | opus (+2) |
|--------|-----------|-------------|-----------|
| **File count** | 1 file | 2-4 files | 5+ files |
| **Story type** | config, styling, boilerplate | standard feature, tests | architecture, security, novel |
| **Pattern availability** | Clear template exists | Follows existing patterns | No existing pattern to follow |
| **Logic complexity** | No branching | Some conditionals | Complex algorithms, edge cases |
| **QA history** | First attempt | 1 prior rejection | 2+ prior rejections |
| **Previous failures** | None on this task | 1 failure | 2+ failures |

**Score → Model mapping:**

| Total Score | Model | Rationale |
|-------------|-------|-----------|
| 0-3 | `haiku` | Simple, template-following work |
| 4-7 | `sonnet` | Standard development work |
| 8+ | `opus` | Complex, novel, or high-stakes work |

#### Override Rules

Priority order (highest wins):

1. **User override**: If the story specifies a `model` field, use that model unconditionally.
2. **Global override**: If `model_override` is set in `.maestro/state.local.md`, use that for all dispatches.
3. **Escalation**: If agent failed 2+ times on the same task with current model, escalate one tier.
4. **QA reviewer**: Always `opus` (QA accuracy is worth the cost — catching bugs saves re-dispatches).
5. **Signal scoring**: Use the table above.
6. **Never downgrade**: Once escalated, do not go back to a cheaper model for the same task.

#### Cost-Aware Routing

Track cumulative cost per story. If a story's cost exceeds 3x its complexity estimate:
- Log a warning to `.maestro/logs/cost-alerts.md`
- Consider whether the story should be split into smaller pieces
- Do NOT automatically escalate model (more expensive models on bad tasks = waste)

### Decision 3: What Context

Invoke the Context Engine to compose the right-sized context package:

1. Pass the agent type, story spec, and task description to the Context Engine.
2. Receive the composed context package with token count.
3. Attach the context package to the agent prompt.
4. Log the composition to `.maestro/context-log.md`.

See `skills/context-engine/SKILL.md` for the full composition pipeline.

## Dispatch Protocol

### Single Story Dispatch (Sequential)

For stories that have dependencies or are the only ready story:

```
Agent(
  subagent_type: "maestro:maestro-implementer",
  description: "Implement story NN: [title]",
  isolation: "worktree",
  run_in_background: true,
  model: "[selected model]",
  prompt: "[North Star + story spec + context package]"
)
```

**MANDATORY fields:**
- `isolation: "worktree"` — Every implementer and fixer runs in an isolated worktree
- `run_in_background: true` — Keeps the orchestrator responsive to user messages
- `subagent_type` — Must match a registered Maestro agent
- `model` — From Decision 2 model selection

### Parallel Story Dispatch (Independent Stories)

When decomposition marks multiple stories as `parallel_safe: true` with no mutual dependencies, dispatch them simultaneously in a SINGLE message with MULTIPLE Agent tool calls:

```
// In a single response, dispatch all independent stories at once:

Agent(
  subagent_type: "maestro:maestro-implementer",
  description: "Implement story 02: [title]",
  isolation: "worktree",
  run_in_background: true,
  model: "sonnet",
  prompt: "[story 02 context]"
)

Agent(
  subagent_type: "maestro:maestro-implementer",
  description: "Implement story 03: [title]",
  isolation: "worktree",
  run_in_background: true,
  model: "sonnet",
  prompt: "[story 03 context]"
)
```

**Parallel dispatch rules:**
1. Only dispatch stories that have ALL dependencies met (all `depends_on` stories are DONE).
2. Only dispatch stories marked `parallel_safe: true` together.
3. Maximum 3 parallel agents at once (more causes context thrashing and merge conflicts).
4. Each parallel story gets its own worktree — no shared state.
5. After ALL parallel stories complete, run validation on each, then merge in dependency order.
6. If any parallel story fails, the others' results are still valid (they're independent).

### Merge Coordination for Parallel Stories

When multiple parallel stories complete:

1. Sort completed stories by their ID (lowest first).
2. For each completed story in order:
   a. Check for merge conflicts with the main working tree.
   b. If clean: merge worktree, run validation, QA review, git craft.
   c. If conflicts: attempt auto-resolve. If auto-resolve fails, PAUSE and ask user.
3. After merging all parallel stories, run the FULL test suite once (catches cross-story integration issues).

### QA Dispatch

QA agents are dispatched differently — they do NOT need worktree isolation:

```
Agent(
  subagent_type: "maestro:maestro-qa-reviewer",
  description: "QA review story NN: [title]",
  run_in_background: true,
  model: "opus",
  prompt: "[story spec + git diff + test output + project rules]"
)
```

### Fix Dispatch

Fix agents are laser-focused — minimal context, worktree isolation:

```
Agent(
  subagent_type: "maestro:maestro-fixer",
  description: "Fix: [error summary]",
  isolation: "worktree",
  run_in_background: false,   // Wait for fix before re-running checks
  model: "sonnet",
  prompt: "[error output + affected file content + fix pattern]"
)
```

Note: `run_in_background: false` for fixers because the orchestrator needs the fix result immediately to re-run validation.

## Response Handling

Every agent must return a structured response with a status field:

| Status | Meaning | Action |
|--------|---------|--------|
| `DONE` | Task completed successfully | Accept output, advance to next phase |
| `DONE_WITH_CONCERNS` | Completed with noted risks | Accept output, flag concerns for QA reviewer |
| `NEEDS_CONTEXT` | Agent lacks information | Context Engine adaptive escalation |
| `BLOCKED` | External dependency prevents completion | Log blocker, skip to next independent story, or escalate |
| `FAILED` | Unrecoverable error | Dispatch fixer if build error, otherwise escalate to user |

### Response Parsing

The agent's final message contains its status. Parse it by searching for these patterns:

```
STATUS: DONE
STATUS: DONE_WITH_CONCERNS
STATUS: NEEDS_CONTEXT
STATUS: BLOCKED
```

If no explicit status found, analyze the agent's output:
- Contains "all tests passing" + files created/modified → treat as DONE
- Contains "error" or "failed" + no resolution → treat as FAILED
- Contains "missing" or "need" + question → treat as NEEDS_CONTEXT

### Escalation Chain: NEEDS_CONTEXT

1. **First attempt**: Context Engine adds next-relevance items (+30% budget). Re-dispatch at same tier.
2. **Second attempt**: Context Engine bumps tier (T3→T2→T1). Recompose full package. Re-dispatch.
3. **Third attempt**: Surface to user. Present what the agent needs. Ask user to provide missing context directly or point to files.

Between escalations, log what was tried:
```
ESCALATION Story 03 | Attempt 1: Added cache-manager.ts, isr-config.ts (+1.2K tokens)
ESCALATION Story 03 | Attempt 2: Bumped T3→T2, full recompose (8.1K tokens)
ESCALATION Story 03 | Attempt 3: Surfacing to user — agent needs Supabase RLS policy context
```

### Escalation Chain: BLOCKED/FAILED

1. If build/lint/type error: dispatch `fixer` agent (T4) with the error message + affected file.
2. If fixer fails 3 times: escalate to user with full error context.
3. If blocked on external dependency: mark story as BLOCKED, skip to next independent story, continue with others.
4. If blocked story blocks downstream stories: log a warning and mark all downstream as BLOCKED.

## Token Accounting

After each dispatch, log the token spend to `.maestro/state.local.md`:

```yaml
dispatches:
  - story: "03-api-routes"
    agent: implementer
    model: sonnet
    context_tokens: 3412
    attempt: 1
    status: DONE
    timestamp: "2026-03-17T14:22:01Z"
```

Aggregations tracked:
- **Per story**: Total tokens across all dispatch attempts
- **Per milestone**: Sum of all story tokens
- **Per session**: Running total for budget tracking
- **Per model**: Breakdown by haiku/sonnet/opus for cost analysis

Feed this data to `token-ledger` for budget tracking and to `retrospective` for model selection optimization.

## Progressive Trust

Track agent reliability over time in `.maestro/trust.yaml`:

```yaml
trust:
  implementer:
    sonnet:
      total_dispatches: 47
      first_pass_qa: 38          # DONE on first QA review
      first_pass_rate: 0.81
      avg_qa_iterations: 1.2
      avg_self_heal_cycles: 0.3
    haiku:
      total_dispatches: 12
      first_pass_qa: 7
      first_pass_rate: 0.58
      avg_qa_iterations: 1.8
      avg_self_heal_cycles: 0.8
  qa-reviewer:
    opus:
      total_dispatches: 47
      false_rejections: 3        # REJECTED but implementer was correct
      false_approvals: 1         # APPROVED but milestone eval found issues
      accuracy: 0.91
```

**Trust-based adjustments (applied automatically):**
- If `first_pass_rate` for haiku < 0.5: stop using haiku for this project, default to sonnet.
- If `first_pass_rate` for sonnet > 0.85 for 10+ dispatches: try haiku for simple stories (save cost).
- If QA `false_rejections` > 20%: lower confidence threshold to 85 (QA is too strict).
- If QA `false_approvals` > 10%: raise confidence threshold to 75 (QA is too lenient).

## Retry and Backoff

When an agent fails, apply exponential context enrichment (not time delays):

| Attempt | Context Change | Model Change |
|---------|---------------|-------------|
| 1st | Original package | Original model |
| 2nd | +30% budget, add relevant items | Same model |
| 3rd | Bump tier (T3→T2) | Same model |
| 4th | Same tier | Escalate model (sonnet→opus) |
| 5th | PAUSE and escalate to user | N/A |

Never retry the exact same dispatch — each retry must change either the context, the model, or both.
