---
name: delegation
description: "Dispatch protocol for agent assignment. Classifies tasks, selects models, invokes Context Engine for right-sized context, handles agent responses."
---

# Delegation

Handles every agent dispatch decision in Maestro. For each task that needs an agent, Delegation answers three questions: Who executes it, What model powers it, and What context it receives. It then dispatches, monitors the response, and routes the outcome.

## Three Decisions Per Dispatch

### Decision 1: Who (Agent Type)

Select the agent type based on the task classification:

| Task | Agent Type | Context Tier |
|------|-----------|-------------|
| Write code for a story | `implementer` | T3 |
| Review a code diff | `qa-reviewer` | T3 |
| Fix a build/lint/type error | `self-heal` | T4 |
| Design system architecture | `architect` | T2 |
| Synthesize research findings | `strategist` | T1 |
| Write content or copy | `copywriter` | T3 |
| Audit security posture | `security-reviewer` | T3 |
| Coordinate a milestone | `orchestrator` | T0 |

If the task does not clearly map to one type, default to `implementer` with a T3 context package.

### Decision 2: What Model

Select the model based on task complexity signals:

| Model | Cost | When to Use | Signals |
|-------|------|-------------|---------|
| `haiku` | Lowest | Boilerplate, config, simple CRUD, formatting, repetitive patterns | Single file, clear template to follow, no logic branching |
| `sonnet` | Medium | Standard features, moderate logic, test writing, component building | 2-4 files, follows existing patterns, some conditionals |
| `opus` | Highest | Novel architecture, complex algorithms, security-critical, subtle edge cases | 5+ files, new patterns, ambiguous requirements, high stakes |

**Override rules:**
- If the story specifies a `model` field, use that model regardless of signals.
- If the user set a global `model_override` in state, use that for all dispatches.
- If a `haiku` agent fails twice on the same task, escalate to `sonnet`.
- If a `sonnet` agent fails twice, escalate to `opus`.
- Never downgrade from a user-specified model.

### Decision 2b: Complexity Re-evaluation (Auto-Downgrade)

After the initial model assignment, re-evaluate complexity at dispatch time using simplicity signals before invoking the agent. This prevents over-spending when a story turns out to be simpler than initial classification suggested.

**Simplicity signals — check each:**

1. Story touches only 1 file
2. Story follows an existing pattern exactly (the implementation is template-like)
3. Story is purely additive — no refactoring, no deleted lines in non-test files
4. Story is config or data only — no logic, no conditionals
5. Story has a clear template in the codebase that can be lifted and adapted

**Auto-downgrade rules:**

| Signal Count | Action |
|---|---|
| 3 or more signals | Downgrade: `opus` → `sonnet`, or `sonnet` → `haiku` |
| Exactly 2 signals | Log the observation; do not force a downgrade |
| 0–1 signals | No change; keep the initially assigned model |

**Safety constraints (always enforced):**

- Never downgrade below the minimum model for the agent type. Each agent type has a floor: `orchestrator` and `architect` floor at `sonnet`; all others floor at `haiku`.
- Never downgrade if the user explicitly specified a model (story `model` field or global `model_override`).
- Never downgrade if the story is security-critical or has ambiguous requirements (those signals already push toward `opus`).

**Logging requirement:**

Every downgrade decision — forced or deferred — must be logged to `.maestro/state.local.md` with:
- The model before and after the downgrade
- Which simplicity signals fired
- Whether the downgrade was applied or only noted

Example log entry:
```
[Auto-downgrade] Story 07 | haiku (3 signals: single-file, additive, config-only) | sonnet → haiku applied
[Auto-downgrade] Story 11 | 2 signals: single-file, additive | downgrade noted but not forced
```

### Decision 3: What Context

Invoke the Context Engine to compose the right-sized context package:

1. Pass the agent type, story spec, and task description to the Context Engine.
2. Receive the composed context package with token count.
3. Attach the context package to the agent prompt.

See `skills/context-engine/SKILL.md` for the full composition pipeline.

## Dispatch Protocol

1. Log the dispatch decision to `.maestro/state.local.md`:
   ```
   Dispatching: Story 03 | Agent: implementer | Model: sonnet | Context: 3,412 tokens
   ```

2. Compose the agent prompt:
   - System prompt: The agent's skill definition (from skill-factory or built-in)
   - Context block: The Context Engine's composed package
   - Task block: Specific instructions for this dispatch (what to produce, where to write)
   - Response format: Structured output the agent must return

3. Invoke the agent via `claude --model <model> --prompt <composed_prompt>` or the SubAgent tool.

4. Capture the agent's response.

## Response Handling

Every agent must return a structured response with a status field:

| Status | Meaning | Action |
|--------|---------|--------|
| `DONE` | Task completed successfully | Accept output, advance to next phase (QA or next story) |
| `DONE_WITH_CONCERNS` | Completed but with noted risks | Accept output, flag concerns for QA reviewer, add concerns to QA context |
| `NEEDS_CONTEXT` | Agent lacks information to proceed | Invoke Context Engine adaptive escalation (add items, bump tier, or ask user) |
| `BLOCKED` | Cannot proceed due to external dependency | Log blocker, attempt re-dispatch with different approach, or escalate to user |
| `FAILED` | Unrecoverable error during execution | Log failure, attempt self-heal dispatch if build/lint error, or escalate |

**Escalation chain for NEEDS_CONTEXT:**
1. Context Engine adds next-relevance items (+30% budget) and re-dispatches.
2. Context Engine bumps tier (T3 to T2) and recomposes full package.
3. Surface to user with the agent's description of what it needs.

**Escalation chain for BLOCKED/FAILED:**
1. If build/lint/type error: dispatch `self-heal` agent (T4) with the error.
2. If self-heal fails 3 times: escalate to user with full error context.
3. If blocked on external dependency: skip story, mark as blocked, continue with next independent story.

## Token Accounting

After each dispatch, log the token spend:
- Model used and token count (input + output)
- Context package size
- Running total for the session

Feed this data to the `token-ledger` skill for budget tracking.

## Cost Awareness

Track cumulative spend per feature (a feature = one orchestration run or named milestone). At each checkpoint summary, include a cost delta line:

| Spend vs. forecast | Action |
|---|---|
| More than 150% of forecast | Flag to user: "Spend is 50%+ over forecast — no auto-stop, but review model assignments" |
| Within 50–150% of forecast | Normal; no action |
| Below 50% of forecast | Note efficiency: "Spend is under half of forecast — consider whether scope changed" |

**How to compute the forecast:**

The `token-ledger` skill holds the per-story cost estimates produced at planning time. Sum estimates for all stories in the current milestone to get the forecast. Compare against actual running total.

**Checkpoint summary format (cost delta line):**

```
Cost: $0.42 actual / $0.60 forecast (70% — on track)
```

or, if over threshold:

```
Cost: $0.91 actual / $0.60 forecast (152% — FLAG: over budget)
```

Do not halt execution based on cost alone. Flag and continue unless the user explicitly sets a budget ceiling in state.

## Model Routing Optimization

Use historical QA pass-rate data to progressively shift model assignments toward cheaper models when the project demonstrates they are sufficient.

**Progressive downgrade patterns:**

1. **Last-3 sonnet pattern:** If the last 3 stories dispatched to `sonnet` all received QA first-pass (no rework cycle), treat stories of similar complexity as candidates for `haiku` on next dispatch. Log the observation; apply on the next matching story.

2. **Haiku 80% rule:** If `haiku` has achieved an 80%+ QA first-pass rate across all stories in this project so far, default `haiku` for any story initially classified as "standard" complexity (sonnet tier). Override still yields to user-specified models and the safety constraints from Decision 2b.

**Tracking QA pass rates per model:**

After each QA reviewer response, record in `.maestro/state.local.md`:
```
[QA result] Story 05 | model: sonnet | pass: true | first-pass: true
[QA result] Story 06 | model: haiku  | pass: true | first-pass: false (1 rework cycle)
```

Compute running rates from these log lines when evaluating patterns above.

**State fields to maintain:**

```
model_stats:
  haiku:  { dispatched: 8, qa_first_pass: 7, rate: 0.875 }
  sonnet: { dispatched: 5, qa_first_pass: 5, rate: 1.0 }
  opus:   { dispatched: 1, qa_first_pass: 1, rate: 1.0 }
```

Reset per project (not per session). The orchestrator persists these in `.maestro/state.local.md`.

## Effort-Level Routing

Set the `--effort` flag based on agent tier before each dispatch:

| Agent Tier | Effort | Rationale |
|-----------|--------|-----------|
| Planning (opus) | high | Maximum reasoning for architecture |
| Implementation (sonnet) | medium | Balanced for coding tasks |
| QA Review (sonnet/opus) | medium | Thorough but efficient |
| Simple tasks (haiku) | low | Fast responses, minimal cost |
| Background workers | low | Lightweight monitoring |

When dispatching via Agent SDK or CLI, include `--effort {level}` flag.
This reduces token usage without quality loss on routine tasks.

## Token-Ledger Integration

After each agent dispatch completes:

1. Record actual token spend (input + output tokens, model, story ID) to the `token-ledger` skill.
2. Retrieve the token-ledger's stored estimate for this story.
3. Compute cost efficiency: `actual / estimate`. Values below 1.0 are under-budget; above 1.0 are over-budget.
4. Feed the cost efficiency value back into model selection state:
   - If efficiency < 0.6 for 3 consecutive stories at a given model tier: add one simplicity signal weight (lowers the threshold for future downgrades).
   - If efficiency > 1.5 for any story: log a warning and flag the story's model assignment as a candidate for review.

This feedback loop means Delegation becomes more conservative (cheaper) over time when stories are consistently under-budget, and more cautious when stories are regularly over-budget.

**Token-ledger call pattern (after each dispatch):**
```
token-ledger record:
  story_id: <id>
  model: <model used>
  input_tokens: <n>
  output_tokens: <n>
  estimated_tokens: <from planning>
```

See `skills/token-ledger/SKILL.md` for the full ledger protocol.
