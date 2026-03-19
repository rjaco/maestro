# AioX Squads — Research Report

**Date**: 2026-03-18
**Researcher**: Maestro Research Agent
**Source Repo**: https://github.com/SynkraAI/aiox-squads (38 stars, 39 forks)
**Relationship**: Community extension of https://github.com/SynkraAI/aiox-core

---

## What Is AioX Squads?

AioX Squads is the community repository for sharing, discovering, and contributing
squad packages to the AioX framework. The analogy used in the repo:

> "If an AI agent is an employee, a Squad is an entire department."

This repo is to AioX what npm is to Node.js — a catalog of installable, self-contained
agent packages contributed by the community.

**The repo does not run independently**: squads require the AioX core framework.
The framework lives at `aiox-core`; this repo is where community squads are published.

---

## Squad Definitions and Structure

A squad is a self-contained directory with a defined structure. From the apex squad (the
most fully documented example):

```
squads/<name>/
├── squad.yaml              # manifest: tiers, tasks, workflows, data, commands
├── CLAUDE.md               # Claude Code-specific context file
├── agents/                 # agent definition markdown files
│   ├── <chief>.md
│   ├── <tier-1-agent>.md
│   └── ...
├── tasks/                  # task definition markdown files
│   └── <task-name>.md
├── workflows/              # YAML workflow definitions
│   └── <workflow>.yaml
├── data/                   # knowledge base, schemas, heuristics
│   ├── agent-registry.yaml
│   ├── veto-conditions.yaml
│   └── ...
├── checklists/             # quality gate checklists
│   └── <checklist>.md
└── templates/              # document templates
    └── <template>.md
```

**Key file — `squad.yaml`**: the manifest that defines everything. Contains:
- `name`, `version`, `title`, `description`
- `entry_agent`: the chief that receives all requests
- `tiers`: hierarchical agent roles
- `tasks`: list of available task definitions (id + path + description)
- `workflows`: multi-step automated pipelines
- `data`: knowledge base and configuration files
- `commands`: user-facing slash-style commands with descriptions
- `activation`: greeting, auto-activation, CLAUDE.md path

---

## Tier Architecture

Every squad follows this command chain:

```
Tier 0 — Chief (Orchestrator)
├── Receives mission, classifies intent, routes to specialist

Tier 1 — Masters
│   Primary domain experts. Execute core tasks.

Tier 2 — Specialists
│   Niche experts. Activated by Tier 1 for specific sub-tasks.

Tier 3 — Support
    Shared utilities. Quality gates, templates, analytics.
```

Routing is **intent classification**, not keyword matching. The chief reads the user request,
identifies what domain it belongs to, and delegates to the specialist with the best match.
If no specialist fits, the chief handles it directly.

**Handoff protocol** (from apex squad `apex-handoff-protocol.md`):
1. Agent introduces the next specialist by name and expertise
2. Agent states explicitly what was handed off
3. Next specialist greets and confirms understanding of the task
4. Chain is visible and narrated to the user

---

## How Squads Coordinate

**Within a squad**: agents coordinate through the chief. There is no direct peer-to-peer
agent communication — all coordination goes up to the chief and back down to the next
specialist. This is intentionally centralized to keep handoffs auditable.

**Cross-squad coordination**: squads declare composability. Example from apex squad:
> "Compatible with Kaizen (quality monitoring), Brand (design system), SEO (route analysis)"

Cross-squad calls use explicit squad-prefixed command syntax:
```bash
/copy:tasks:create-sales-page       # route to copy squad, task create-sales-page
/brand:tasks:token-audit            # route to brand squad, task token-audit
```

**No shared state by default**: squads do not share memory namespaces. Each squad's context
is self-contained. Cross-squad communication happens through outputs (files, PR comments, story
updates) not live message passing.

---

## Domain and Task Routing

The dispatch squad (community contribution) is the most explicit routing implementation.
It implements 7 immutable laws:

1. **No main context**: all execution via subagents. Never in the terminal principal session.
2. **CODE > LLM**: deterministic tasks → script. Reasoning tasks → LLM.
3. **Right model**: Haiku for well-defined tasks. Sonnet for judgment. Opus never as executor.
4. **Story-driven**: no story with acceptance criteria = no execution.
5. **Slash command map**: dispatch knows all `/` commands. Routes with full path.
6. **Wave optimized**: real DAG with topological sort. Maximum parallelism.
7. **Optimize everything**: apply decision tree (Q1–Q6) on each action.

**Wave planning** (dispatch squad's core pattern):
- Tasks decomposed into atomic sub-tasks
- Sub-tasks organized into a DAG (Directed Acyclic Graph)
- DAG topologically sorted into waves
- Wave N executes in parallel; Wave N+1 starts only when Wave N completes
- This maximizes concurrency while respecting dependencies

**Domain routing taxonomy** from the catalog of 12 squads:

| Domain | Squad | Entry Point | Specialization |
|--------|-------|-------------|---------------|
| Frontend | apex | `@apex-lead` | Web + Mobile + Spatial, 15 agents |
| Brand | brand | `@brand-chief` | Identity, voice, visual systems |
| Copywriting | copy (in core) | `@copy-chief` | Sales, content, persuasion |
| SEO | seo | `@seo-chief` | Post-design optimization |
| Education | education | `@edu-chief` | Learning journeys, cognitive science |
| Legal analysis | legal-analyst | `@legal-chief` | 15 agents, Brazilian law |
| Deep research | deep-research | `@research-chief` | 3-tier pipeline (diagnostic → execution → QA) |
| Parallel execution | dispatch | `@dispatch-chief` | DAG-based parallel execution engine |
| Quality monitoring | kaizen | `@kaizen-chief` | Ecosystem health, DORA metrics |
| Content curation | curator | `@curator-chief` | Existing content organization |
| Squad creation | squad-creator | `@creator-chief` | Template-driven new squad generation |
| Squad creation (pro) | squad-creator-pro | `@creator-pro-chief` | Mind cloning + model routing + 3 specialists |

---

## Squad Catalog — Key Examples

### Apex Squad (Frontend Ultra-Premium)

**15 agents**, 5-tier hierarchy. Covers Web (Next.js 15+), Mobile (React Native), Spatial (WebXR).

Profiling system: squad auto-detects project type from `package.json` and activates
appropriate agent subset:
- `full`: all 15 agents (monorepo with React Native)
- `web-next`: 11 agents (Next.js App Router)
- `web-spa`: 9 agents (React + Vite)
- `minimal`: 4 agents (quick fixes)

**Quality gates enforced in squad.yaml**:
- LCP < 1.2s, INP < 200ms, CLS < 0.1
- First load JS < 80KB gzipped
- WCAG 2.2 AA, axe score 100
- Visual regression: 0 pixel tolerance
- Motion: 60fps, reduced-motion mandatory

**Unique capability**: visual analysis tasks (`*apex-analyze`, `*apex-compare`, `*apex-consistency`)
take screenshots as input and perform multi-dimensional analysis.

### Dispatch Squad (Parallel Execution Engine)

**4 agents** in 3 tiers: chief, quality-gate, wave-planner, task-router.

The dispatch squad is designed to be composed with other squads — it handles the execution
orchestration while domain squads handle the domain expertise.

**Core technique**: Wave-based parallel execution:
1. quality-gate validates story sufficiency before dispatch
2. wave-planner decomposes task into atomic units and builds a DAG
3. task-router assigns each unit to the correct agent/squad/model
4. Execution proceeds wave by wave with maximum parallelism

**Model routing rules**:
- Well-defined task (no ambiguity) → Claude Haiku
- Judgment required → Claude Sonnet
- Opus never used as an executor (too expensive per token)

### Kaizen Squad (Ecosystem Monitor)

**7 agents**: chief, topology-analyst, performance-tracker, bottleneck-hunter,
capability-mapper, tech-radar, cost-analyst.

**Purpose**: meta-squad that monitors the health of all other squads. Runs weekly
automated analysis (Sunday 20:00 BRT by default). Reports DORA metrics, OKR progress,
tech radar updates, cost analysis.

**Autonomy level 2**: deterministic data collection (git log, Glob/Grep, template rendering)
runs automatically. LLM analysis (gap detection, recommendations, ROI estimates) requires
human trigger. Decisions require human approval.

**Self-improvement**: `*self-improve` command — the squad analyzes its own operation and
applies improvements. Meta-analysis with human-in-the-loop at the decision step.

### Deep Research Squad

**3-tier pipeline**:
- Tier 0 (Diagnostic): understands the research domain and failure modes before executing
- Tier 1 (Execution): runs the research pipeline
- Tier 2 (Quality Assurance): validates outputs against accuracy and completeness standards

This matches Ruflo's scout-before-execute pattern but in a domain-specific research context.

---

## Squad Creator (Meta-Pattern)

The squad-creator squad generates new squads from templates. The Pro version adds:
- **Mind cloning**: extracts thinking frameworks from expert documentation to embed in agents
- **Model routing**: assigns different LLM tiers per agent role (not all agents need Opus)
- **3 specialists**: architect, prompt-engineer, qa-validator working in sequence

This is a recursive pattern: a squad for building squads. It enforces structural standards
(YAML manifest, tier definitions, quality gates) on community contributions.

---

## Technical Patterns

### Pattern 1: Veto Conditions

Squads declare explicit veto conditions — situations where an agent must REFUSE to execute
and ESCALATE to the chief, even if a command was given:
```yaml
data:
  - data/veto-conditions.yaml
```

Example veto conditions from apex squad:
- Proceed with implementation when visual requirements are undefined → VETO
- Skip accessibility audit in production → VETO
- Merge conflicting design tokens without resolution → VETO

This gives squads "principled refusal" capability encoded in data, not agent instructions.

### Pattern 2: Quality Gates as Score Thresholds

AioX squads use numeric thresholds for quality validation, not boolean pass/fail:
- Performance scores (LCP, INP, CLS values)
- Accessibility scores (axe score 100 = 0 violations)
- Visual regression (pixel delta tolerance)

This allows partial passes with documented violations vs. hard blocks.

### Pattern 3: Deterministic vs. Probabilistic Automation Boundary

Kaizen squad explicitly separates what is deterministic (runs automatically) from what is
probabilistic (requires LLM + human):

```yaml
automation_boundary:
  deterministic:
    - "Glob/Grep for squad inventory"
    - "git log for activity metrics"
  probabilistic:
    - "detect-gaps — Wardley Maps analysis (LLM)"
    - "generate-recommendations — prioritized recs (LLM)"
```

This is a formalized version of Ruflo's "Agent Booster for simple tasks, LLM for complex."
The boundary is explicit in configuration, not just in implementation.

### Pattern 4: Community Contribution Pipeline

Squads are published via Pull Request. The catalog is auto-generated from merged PRs.
Each contribution requires:
- Passing structural validation (squad.yaml schema)
- Working greeting + one valid command demonstration
- At least one quality gate defined

This creates a supply chain for reusable agent packages — analogous to npm's PR-based
publishing flow for scoped packages.

---

## How AioX Squads Differs from Claude Code Plugins (Maestro)

| Dimension | AioX Squads | Maestro Skills |
|-----------|-------------|----------------|
| Package unit | Squad (multi-agent team with tiers) | Skill (single capability SKILL.md) |
| Routing | Chief classifies intent, routes to specialist | Maestro orchestrator routes to skill |
| Community | GitHub PR → auto-catalog | Plugin marketplace (IPFS-based) |
| Cross-domain | Explicit handoff protocol between squads | Skills compose via orchestrator commands |
| Domain coverage | 12 squads × 4–15 agents each | 128 skills × single responsibility |
| Installation | `*download-squad <name>` or copy folder | Skill copy or marketplace install |
| Quality gates | Encoded in squad.yaml and data files | Defined per-skill in SKILL.md |
| Model routing | Explicit per-tier (Haiku/Sonnet/Opus mapping) | No explicit per-skill model routing |

**Key structural difference**: in AioX Squads, the team structure (who works with whom, what
each agent handles, what quality standards apply) is encoded in `squad.yaml` and loaded with
the squad. In Maestro, the team structure is determined by the orchestrator at runtime based
on the task.

AioX Squads is more opinionated and prescriptive about team structure. Maestro is more
flexible and dynamic — any combination of skills can be orchestrated for any task.

---

## Anti-Patterns Observed

1. **Chief-only routing bottleneck**: all requests go through the chief. In a long workflow,
   if the chief has poor intent classification, sub-optimal specialists are activated. There
   is no peer routing or load-balancing between specialists.

2. **No shared memory across squads**: cross-squad handoffs produce file/PR outputs.
   A brand squad decision does not automatically flow into a copy squad's context.
   Human must re-introduce context across squad boundaries.

3. **Community quality variance**: 12 squads submitted via community PRs have varying depth.
   Apex squad has 100+ tasks and 25+ data files. Curator squad has minimal structure.
   No automated depth scoring enforced at contribution time.

4. **Portuguese community concentration**: most discussion and contribution is PT-BR.
   English speakers have reduced community support surface.

---

## Sources

- https://github.com/SynkraAI/aiox-squads
- https://github.com/SynkraAI/aiox-squads/blob/main/README.md
- https://github.com/SynkraAI/aiox-squads/blob/main/squads/apex/squad.yaml
- https://github.com/SynkraAI/aiox-squads/blob/main/squads/dispatch/config.yaml
- https://github.com/SynkraAI/aiox-squads/blob/main/squads/kaizen/squad.yaml
- https://github.com/SynkraAI/aiox-squads/blob/main/squads/dispatch/agents/ (directory)
- https://github.com/SynkraAI/aiox-squads/blob/main/doc/README.en.md
