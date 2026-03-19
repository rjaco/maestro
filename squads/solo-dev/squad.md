---
name: "solo-dev"
description: "Single-agent development for simple tasks, bug fixes, and small changes. One agent implements and self-reviews — no handoffs, no overhead."
version: "1.0.0"
author: "Maestro"
agents:
  - role: solo-implementer
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Implement the story and then self-review before reporting done. After writing the code, pause and re-read the acceptance criteria against what was produced. Flag any criterion not fully met before closing. Produce clean, idiomatic code that follows project conventions — this is the only pass."
    tools: [Read, Edit, Write, Bash, Grep, Glob]
orchestration_mode: sequential
shared_context:
  - ".maestro/dna.md"
  - "CLAUDE.md"
quality_gates:
  - "Every acceptance criterion is met before reporting STATUS: DONE"
  - "Self-review step is explicit — implementer re-reads criteria against the diff before closing"
  - "No silent partial completions — report DONE_WITH_CONCERNS if any criterion is partially met"
---

# Squad: Solo Dev

## Purpose

A single capable agent that implements a story and self-reviews its own work before closing. No parallelism, no handoffs, no orchestration overhead. One agent, one pass.

Use this squad for simple tasks where a second opinion would add latency without adding value: small bug fixes, minor refactors, configuration changes, documentation updates, or any story where the scope is narrow and the risk is low.

Do not use this squad for stories that touch security-sensitive code, involve complex architecture decisions, or require coordinated changes across multiple system layers. Use `full-stack-dev` or `quality-gate` for those.

## Agents

### solo-implementer (sonnet)

One agent that does everything: reads the story, implements the changes, self-reviews against the acceptance criteria, and reports status.

Responsibilities:
- Read and understand all acceptance criteria before writing any code
- Implement the complete, working solution following project conventions
- After implementation, explicitly re-read each acceptance criterion and verify it against the produced diff
- Report STATUS: DONE only when every criterion is verifiably met
- Report STATUS: DONE_WITH_CONCERNS if any criterion is partially met or carries risk
- Report STATUS: BLOCKED with a specific blocker description if the story cannot be completed

Self-review discipline:
- Do not report DONE immediately after writing code
- Reread the acceptance criteria one by one
- For each criterion, identify the specific file and line that satisfies it
- If a criterion has no satisfying implementation, add it before closing

## Workflow

```
solo-implementer (implement → self-review → report)
```

1. **solo-implementer** reads the story and acceptance criteria.
2. Implements all required changes.
3. Pauses and re-reads each acceptance criterion against the actual diff.
4. Reports STATUS: DONE, DONE_WITH_CONCERNS, or BLOCKED.

There is no second agent. The self-review step happens within the same agent turn, not as a separate pass.

## Context Sharing

The solo-implementer receives:
- `.maestro/dna.md` — Project DNA: tech stack, conventions, naming rules
- `CLAUDE.md` — Project-level rules to follow

## Quality Gates

1. **Explicit self-review** — The implementer must re-read acceptance criteria against the diff before reporting status. This is not optional — it is part of the workflow.
2. **No partial closes** — If a criterion is only partially met, report DONE_WITH_CONCERNS and describe the gap. Do not report DONE.
3. **Idiomatic code** — Changes must follow the conventions in dna.md. No new patterns introduced without justification.

## When to Use

- Small bug fixes with a clear, isolated root cause
- Minor refactors that don't change public interfaces
- Configuration changes, environment updates, or dependency bumps
- Documentation and comment updates
- Simple feature additions with very narrow scope (one file, one function)
- Stories where the acceptance criteria are unambiguous and the implementation is obvious
