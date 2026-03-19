---
name: stream-chain
description: "Chain agent outputs directly into the next agent's input context without file-based intermediaries. Reduces end-to-end latency by 40-60% on multi-agent pipelines by eliminating the write/read cycle between agents."
---

# Stream Chain

Defines a protocol for passing structured agent output directly into the next agent's input context. Instead of writing to an intermediary file and reading it back, the orchestrator captures the upstream agent's output in memory and injects it as context into the downstream agent's prompt.

## Why Stream Chaining

In a typical multi-agent pipeline, agents communicate through files: agent A writes `.maestro/findings.md`, then agent B reads it. Each file write/read cycle adds latency, especially over network filesystems or in high-frequency pipelines.

Stream chaining bypasses that cycle. The orchestrator holds the upstream output in memory and injects it directly into the downstream agent's context package. No file write happens between agents unless the chain definition explicitly requests a checkpoint.

This reduces latency by 40-60% on sequential agent chains measured in the Ruflo NDJSON piping prototype.

## Chain Definition

Define a chain in the story spec under the `chain:` key. Each step names an agent and declares what it outputs and what it expects as input:

```yaml
chain:
  - agent: researcher
    output: findings

  - agent: strategist
    input: findings
    output: strategy

  - agent: implementer
    input: strategy
    output: code_diff

  - agent: qa-reviewer
    input: code_diff
```

### Step Fields

| Field | Required | Description |
|-------|----------|-------------|
| `agent` | Yes | Subagent type to dispatch (e.g., `researcher`, `implementer`) |
| `input` | No | Named output from the previous step to inject as context |
| `output` | No | Named label for this step's output — referenced by the next step's `input` |

The first step in a chain has no `input` (it receives the original story context). The last step has no `output` unless the result should be labeled for downstream use outside the chain.

## Common Use Cases

### researcher → strategist

The researcher produces a findings summary. The strategist receives it as part of its context alongside the original brief.

```yaml
chain:
  - agent: researcher
    output: findings
  - agent: strategist
    input: findings
    output: strategy
```

### implementer → qa-reviewer

The implementer produces a code diff and test results. The QA reviewer receives both without needing to read from disk.

```yaml
chain:
  - agent: implementer
    output: code_diff
  - agent: qa-reviewer
    input: code_diff
```

### architect → decomposer

The architect produces a design document. The decomposer receives it as context to produce stories that respect the architectural decisions.

```yaml
chain:
  - agent: architect
    output: design
  - agent: decomposer
    input: design
    output: stories
```

## Orchestrator Protocol

When the orchestrator encounters a `chain:` definition in a story spec, it executes the following steps:

### Step 1: Validate the chain

Before dispatching any agent:
1. Verify each `agent` value is a registered Maestro subagent type.
2. Verify each `input` value references an `output` from a prior step.
3. If validation fails, report `BLOCKED` with the specific invalid reference.

### Step 2: Execute step N

1. Dispatch the agent using the standard delegation skill.
2. Pass the original story context plus any `input` payload from the prior step.
3. Wait for the agent to complete (status: DONE, DONE_WITH_CONCERNS, BLOCKED, or NEEDS_CONTEXT).
4. If the agent reports BLOCKED or NEEDS_CONTEXT, halt the chain and surface the issue to the user.

### Step 3: Extract output

After the agent completes, extract the named output from the agent's response:

1. Look for a `## Chain Output` section in the agent's response body.
2. If present, capture its contents as the named output payload.
3. If absent but an `output` label was declared, capture the agent's full response as the payload.
4. Label the payload with the declared `output` name and store it in the chain state.

### Step 4: Inject into next step

Before dispatching the next agent, inject the prior step's output as a context section:

```
## Chain Input: <label>

<payload from prior step>
```

This section is prepended to the agent's context package alongside the story spec and any other context files.

### Step 5: Log the exchange

Each chain step is appended to `.maestro/chain-log.md`:

```
## Chain: <story-id> — Step <N>

- Agent:    <agent type>
- Input:    <label> (<N chars>)
- Output:   <label> (<N chars>)
- Status:   DONE
- Duration: <elapsed ms>
- Tokens:   <input>→<output>
```

This log is append-only. It provides full auditability of what data flowed between agents.

## Agent Output Format

Agents participating in a chain SHOULD include a `## Chain Output` section at the end of their response. This section contains the structured payload intended for the next agent — separate from the human-readable status report.

Example from an implementer:

```
STATUS: DONE
Tests: 5 passing
Files: src/pricing.ts (modified)

## Chain Output

### Changed Files
- src/pricing.ts — added `sortByPrice(direction)` function

### Test Results
- 5 tests passing, 0 failing

### Diff Summary
Added 47 lines, removed 12 lines across 1 file.
```

The QA reviewer receives the `## Chain Output` block as its `code_diff` input, not the full response.

If an agent does not include `## Chain Output`, the orchestrator uses the agent's full response as the payload. This is a fallback — agents participating in known chains should always declare their output section explicitly.

## Checkpoints

By default, stream chaining does not write intermediary files. If a chain step should be checkpointed to disk (for debugging, rollback, or long-running chains), add `checkpoint: true` to that step:

```yaml
chain:
  - agent: researcher
    output: findings
    checkpoint: true    # writes .maestro/chain/<story-id>/findings.md

  - agent: strategist
    input: findings
    output: strategy
```

When `checkpoint: true` is set, the orchestrator writes the output payload to `.maestro/chain/<story-id>/<output-label>.md` before proceeding to the next step. If the chain is re-run (e.g., after a BLOCKED step is resolved), the orchestrator checks for an existing checkpoint and skips the step if one is found.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Agent reports BLOCKED | Halt chain. Surface BLOCKED status and message to user. Log step as BLOCKED in chain-log. |
| Agent reports NEEDS_CONTEXT | Halt chain. Present context request to user. Resume chain from the halted step once resolved. |
| Agent reports DONE_WITH_CONCERNS | Continue chain. Log concerns in chain-log. Surface concerns in final summary. |
| Output label not found in response | Use full agent response as payload. Log warning in chain-log. |
| Chain validation failure | Do not dispatch any agents. Report BLOCKED with specific validation error. |

## Integration with Other Skills

- **delegation:** Chain steps are dispatched via the delegation skill. All normal delegation behavior (model selection, squad overrides, token budget) applies per step.
- **audit-log:** Each chain step dispatch is logged as a standard audit entry alongside the chain-log entry.
- **output-contracts:** If a chain step's agent skill declares an `output_contract`, the orchestrator validates the output before extracting the chain payload. Validation failure halts the chain.
- **checkpoint:** If `checkpoint: true` is set on a step, the checkpoint skill manages the file write and resume logic.
- **hooks-integration:** The `SubagentStop` hook fires after each chain step completes, giving the orchestrator the signal to extract output and dispatch the next step.
