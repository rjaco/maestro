---
name: ""
description: ""
version: "1.0.0"
author: ""
agents:
  - role: ""
    agent: "maestro:"           # e.g. maestro:maestro-implementer, or a path to a local agent file
    model: sonnet               # opus | sonnet | haiku
    focus: ""                   # One-line description of this role's specific focus within the squad
orchestration_mode: sequential  # sequential | parallel | dag
shared_context:
  - ".maestro/dna.md"           # Files and patterns every agent in the squad receives
  - "CLAUDE.md"
quality_gates:
  - ""                          # Conditions that must be true before the squad's output is accepted
---

# [Squad Name]

## Purpose

What category of tasks does this squad handle? When should an orchestrator choose this squad over a single agent?

[1-3 sentences. Be specific: "Handles full-stack feature development from database schema through UI" is better than "Builds features".]

## Agents

Each agent in this squad has a defined role and scope. Agents should not duplicate work — their responsibilities must be non-overlapping.

### [Role Name]

- **Agent:** `maestro:[agent-name]`
- **Model:** opus | sonnet | haiku
- **Focus:** [What specifically this role owns — files, layers, concerns]
- **Inputs:** [What this role receives before starting work]
- **Outputs:** [What this role produces when done]

<!-- Repeat for each agent in the squad -->

## Workflow

How do agents coordinate? Describe the handoff sequence or dependency graph.

### Orchestration Mode: [sequential | parallel | dag]

**Sequential** — agents run one after another. Each receives the previous agent's output.

```
Agent A → Agent B → Agent C
```

**Parallel** — agents run simultaneously on independent concerns.

```
Agent A ─┐
Agent B ─┤→ merge → Agent C
Agent D ─┘
```

**DAG** — agents run in a dependency graph. Use this for complex pipelines where some agents can parallelize while others must wait.

```
Agent A ─┐
         ├→ Agent C → Agent D
Agent B ─┘
```

### Handoff Protocol

Describe what gets passed between agents:

1. **[Agent A] → [Agent B]:** [What A produces that B needs — file paths, artifacts, summary format]
2. **[Agent B] → [Agent C]:** [What B produces that C needs]

## Context Sharing

Not all agents need all context. Define what each role sees to minimize token waste and keep agents focused.

| Agent Role | Receives |
|------------|----------|
| [Role A]   | `shared_context` + [additional files specific to this role] |
| [Role B]   | `shared_context` + [additional files specific to this role] |

### Shared Context

Files listed in `shared_context` are injected into every agent's prompt automatically:

- `.maestro/dna.md` — Technical DNA: stack, conventions, patterns
- `CLAUDE.md` — Project-level rules every agent must follow

### Role-Specific Context

Additional context injected only for a specific role:

- **[Role Name]:** `[file or glob pattern]` — [Why this role needs it]

## Quality Gates

The squad's output is not accepted until all quality gates pass. The orchestrator enforces these before marking the squad's task complete.

- [ ] [Concrete, verifiable condition — e.g. "All tests pass (`npm test`)"]
- [ ] [Another condition — e.g. "QA reviewer reports APPROVED"]
- [ ] [Another condition — e.g. "No TypeScript errors (`npx tsc --noEmit`)"]

Gates must be binary: pass or fail. Avoid vague gates like "code is clean."
