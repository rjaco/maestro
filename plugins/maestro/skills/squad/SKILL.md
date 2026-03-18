---
name: squad
description: "Define and manage a team of specialized agents for a feature or project. Reads .maestro/squad.md to configure agent composition, model assignments, and coordination rules used by decompose, delegation, and dev-loop."
---

# Squad

Defines the team of agents that will work on a feature or project. A squad is a named composition of agent types, each with a model assignment and coordination mode. Other skills read the squad definition to make dispatch, model, and parallelism decisions.

## Squad Definition Format

Create `.maestro/squad.md` at the project root (project-wide default) or alongside a feature spec (per-feature override):

```yaml
---
name: "Feature Squad"
composition: [implementer, qa-reviewer, security-reviewer]
coordination: parallel  # parallel | sequential
model_overrides:
  implementer: sonnet
  qa-reviewer: sonnet
  security-reviewer: opus
---
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Human-readable squad name |
| `composition` | Yes | Ordered list of agent types to include |
| `coordination` | Yes | `parallel` runs eligible agents concurrently; `sequential` runs one at a time |
| `model_overrides` | No | Per-agent model assignment; overrides story recommendations and delegation defaults |

### Valid Agent Types

| Agent | Role |
|-------|------|
| `implementer` | Writes code and creates files |
| `qa-reviewer` | Reviews diffs and catches issues |
| `security-reviewer` | Audits for vulnerabilities and posture |
| `architect` | Designs system structure and interfaces |
| `strategist` | Synthesizes research and makes recommendations |
| `self-heal` | Auto-fixes build, lint, and type errors |

### Coordination Modes

**`parallel`** — Eligible agents (those with no blocking dependencies) are dispatched concurrently across worktrees. Use when throughput matters more than cost.

**`sequential`** — Agents run one at a time in composition order. Use when output from one agent must feed the next, or when debugging an unfamiliar codebase.

## Pre-Built Squad Templates

Copy any template into `.maestro/squad.md` and customize as needed.

### speed-squad

Fast and cheap. Two haiku agents for rapid iteration on well-understood work.

```yaml
---
name: "Speed Squad"
composition: [implementer, qa-reviewer]
coordination: parallel
model_overrides:
  implementer: haiku
  qa-reviewer: haiku
---
```

Best for: boilerplate, config files, styling tweaks, simple CRUD, repetitive patterns.

### quality-squad

Thorough and reliable. Sonnet for implementation and QA, Opus for security review.

```yaml
---
name: "Quality Squad"
composition: [implementer, qa-reviewer, security-reviewer]
coordination: sequential
model_overrides:
  implementer: sonnet
  qa-reviewer: sonnet
  security-reviewer: opus
---
```

Best for: production features, auth-adjacent code, payment flows, API surface changes.

### full-squad

Maximum coverage. All agent types, mixed models, sequential coordination for full traceability.

```yaml
---
name: "Full Squad"
composition: [architect, implementer, qa-reviewer, security-reviewer, strategist]
coordination: sequential
model_overrides:
  architect: opus
  implementer: sonnet
  qa-reviewer: sonnet
  security-reviewer: opus
  strategist: opus
---
```

Best for: greenfield systems, migrations, major refactors, high-stakes features.

### solo

Minimal overhead. A single implementer, no QA pass. Use when you want to move fast and review manually.

```yaml
---
name: "Solo"
composition: [implementer]
coordination: sequential
model_overrides:
  implementer: sonnet
---
```

Best for: prototyping, spikes, internal tooling, throwaway scripts.

## Squad Lifecycle

### 1. Created

At project init (`/maestro quick-start`) or feature start, the user picks a squad template or defines a custom one. The squad file is written to `.maestro/squad.md`.

If no squad file exists, delegation and dev-loop fall back to their built-in defaults (single sonnet implementer, single opus QA reviewer).

### 2. Active During Dev Loop

While `dev-loop` is executing stories, it reads the squad on every dispatch decision:

- Phase 2 (DELEGATE): reads `model_overrides` to select model per agent type
- Phase 3 (IMPLEMENT): reads `coordination` to decide parallel vs sequential worktree dispatch
- Phase 5 (QA REVIEW): reads `composition` to determine if a QA reviewer or security reviewer (or both) should run

### 3. Referenced by Retrospective

After feature completion, retrospective reads the squad alongside session performance data to evaluate: which agents were dispatched, whether model overrides were appropriate (e.g., did haiku agents need escalation?), and whether composition matched actual work. It may propose squad adjustments — all require user approval.

### 4. Updated

The user can update `.maestro/squad.md` at any checkpoint. Changes take effect on the next story dispatch.

## Integration Points

### decompose/SKILL.md

When generating stories, decompose reads the squad composition to set default `assigned_agent` and `model_recommendation` fields per story:

- If squad has `security-reviewer`, decompose adds a security review story for stories touching auth or data handling
- If squad is `solo`, decompose reduces story count (fewer review stories, more consolidated work)
- Story-level `model` field still overrides squad `model_overrides`

### delegation/SKILL.md

On every agent dispatch, delegation checks `.maestro/squad.md` in this order:

1. Story-level `model` field (highest priority — explicit override)
2. Squad `model_overrides` for the agent type being dispatched
3. Delegation's built-in complexity signals (lowest priority — default)

If the squad has no `model_overrides` entry for an agent type, delegation uses its default model selection logic.

### dev-loop/SKILL.md

Dev loop reads squad `coordination` to determine how stories are executed:

- `parallel`: stories marked `parallel_safe: true` are dispatched concurrently across isolated worktrees
- `sequential`: all stories run in dependency order, one at a time

Dev loop also reads `composition` to know which review phases to run. If `security-reviewer` is not in the squad, Phase 5 skips the security review step even if decompose generated a security story.

### retrospective/SKILL.md

Retrospective reads the squad to contextualize agent performance:

- Compares configured models vs actual models used (escalations show where the squad was under-specified)
- Tracks squad effectiveness: first-pass QA rate per squad type, token cost per squad type
- Proposes template changes or new custom squad definitions based on session data

## Selecting a Squad

Use this decision guide:

| If you need... | Use |
|----------------|-----|
| Maximum speed, cost is secondary concern | speed-squad |
| Production quality with security checks | quality-squad |
| Full traceability, complex system | full-squad |
| Prototype or internal tool | solo |
| Custom mix for your project | Define a custom squad |

When in doubt, start with `quality-squad`. It covers the common case (implementer + QA + security) without the overhead of the full-squad's architecture and strategy passes.
