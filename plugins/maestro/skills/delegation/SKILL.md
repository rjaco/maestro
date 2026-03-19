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

## Token Accounting

After each dispatch, log the token spend:
- Model used and token count (input + output)
- Context package size
- Running total for the session

Feed this data to the `token-ledger` skill for budget tracking.
