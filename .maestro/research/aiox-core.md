# AioX Core — Research Report

**Date**: 2026-03-18
**Researcher**: Maestro Research Agent
**Source Repo**: https://github.com/SynkraAI/aiox-core (2.4k stars, 786 forks)
**npm**: `aiox-core`
**Language**: JavaScript/TypeScript

---

## What Is AioX?

AIOX (Artificial Intelligence Orchestration eXperience) is an open-source multi-IDE, multi-agent
development framework. It structures agentic development around a "Scrum team" metaphor:
specialized agents (analyst, pm, architect, sm, dev, qa) coordinate through story files to
plan, implement, and validate software.

**Core tagline**: "Devolvendo às pessoas o poder de criar" (Giving people the power to create back)

**Version**: 4.2 (AIOX Core 4.0 framework, current release 4.2.11)

**Two-innovation summary**:
1. **Agentic planning**: dedicated analyst/pm/architect agents produce detailed PRD + Architecture
   documents through human-in-the-loop refinement
2. **Hyperdetailed stories**: the sm (Scrum Master) agent transforms plans into stories containing
   complete implementation context so the dev agent opens a story file with full understanding
   of what to build, how, and why — eliminating context loss

**Positioning vs. Maestro**: AioX is "full-stack agile team simulator in a markdown folder,"
with a heavier emphasis on planning phases and story-driven handoff between agents.
Maestro is closer to a "Claude Code power tool system" with stronger skill routing.

---

## Architecture: CLI First

AIOX enforces a strict priority hierarchy:

```
CLI First → Observability Second → UI Third
```

- The CLI is the source of truth. All execution and automation lives there.
- Dashboards (if any) only observe — they never control.
- New features must work 100% via CLI before any UI is built.

This is architecturally similar to Maestro's terminal-first approach.

---

## Squad Management System

Squads are the central organizing concept in AioX. A squad is a team of specialized agents
bundled together to solve a domain.

**Squad structure** (from `squad.yaml`):

```yaml
name: <squad-id>
version: "1.0.0"
entry_agent: <chief-agent>
tiers:
  orchestrator: <chief>
  tier_1: [primary-specialists]
  tier_2: [secondary-specialists]
  tier_3: [support-utilities]
tasks:
  - id: task-name
    path: tasks/task-name.md
    description: "what it does"
workflows:
  - id: workflow-id
    path: workflows/workflow.yaml
data:
  - data/knowledge-base.yaml
checklists:
  - checklists/quality-gate.md
commands:
  - "*command-name — what it does"
activation:
  greetingEnabled: true
  claudeMdPath: "squads/<name>/CLAUDE.md"
```

**Routing**: the chief agent (`entry_agent`) is always Tier 0. It receives the request,
classifies intent, and routes to the correct specialist. Specialists delegate down the tier
chain as needed. Handoffs are explicit: the agent introduces the next specialist and
explains what was handed off.

**Drop-in install**: squads are self-contained directories. Install with:
```bash
*download-squad <squad-name>
```
Or manually: copy the squad folder into `squads/` in your project.

**Squad lifecycle**:
1. User activates chief: `@squad-chief`
2. Chief greets and confirms activation
3. User runs command: `*task-name` or `*help`
4. Chief routes to specialist
5. Specialist executes, optionally delegates to sub-specialist
6. Handoff chain is visible and narrated

---

## Hook Parity Approach

AioX 4.2 explicitly documents hook parity across IDEs as a first-class concern.
The parity matrix is version-controlled and enforced by a validator.

**Parity validation command**:
```bash
npm run validate:parity
```

**Contract file**: `.aiox-core/infrastructure/contracts/compatibility/aiox-4.2.11.yaml`

**Hook parity matrix** (AIOX 4.2.11):

| IDE/CLI | Hooks Parity vs. Claude Code | Impact |
|---------|------------------------------|--------|
| Claude Code | Complete (reference) | Maximum automation — pre/post tool, session, guardrails, audit |
| Gemini CLI | High (native events) | Strong pre/post tool coverage; minor event-handling differences |
| Codex CLI | Partial/limited | Compensate via `AGENTS.md`, `/skills`, MCP, and manual sync scripts |
| Cursor | No lifecycle hooks | Compensate via rules, MCP, agent flow; run validators manually |
| GitHub Copilot | No lifecycle hooks | Compensate via repo instructions + VS Code MCP |
| AntiGravity | Workflow-based (not hook-based) | Integrate via generated workflows |

**Key insight**: AioX treats Claude Code's hook system as the gold standard reference
implementation. All other IDEs are measured against Claude Code capability and deficiencies
are explicitly documented with workarounds.

**What is lost without full hook support**:
- Automatic session tracking (start/end detection)
- Pre/post-action guardrails (auto-checks before each tool use)
- Automatic audit trail (session recording)
- Context injection automation (code-intel XML context on tool call)

**Implication for Maestro**: AioX explicitly validates that Claude Code is the richest
hook environment and builds workarounds for other IDEs. Maestro's Claude Code-only focus
is consistent with AioX's assessment of where hooks are most powerful.

---

## Multi-IDE Support — Technical Implementation

AioX maintains separate sync scripts per IDE:

```bash
npm run sync:ide:claude     # → .claude/commands/AIOX/agents/
npm run sync:ide:codex      # → AGENTS.md + /skills directory
npm run sync:ide:gemini     # → .gemini/rules.md + .gemini/commands/*.toml
npm run validate:claude-sync
npm run validate:codex-sync
npm run validate:gemini-sync
npm run validate:parity     # cross-IDE parity check
```

**Claude Code integration**: agents exposed as slash commands (`/dev`, `/qa`, `/architect`).
The `.claude/CLAUDE.md` is auto-loaded. Full hooks support.

**Codex CLI integration**: `AGENTS.md` at repo root is the primary context file. Skills
generated to `/skills` directory. Session tracking and pre/post guardrails are partial —
compensated by running sync scripts.

**Gemini CLI integration**: slash commands (`/aiox-menu`, `/aiox-dev`, `/aiox-architect`).
Rules in `.gemini/rules.md`. TOML command files for each agent.

**Cursor/Copilot**: rules-only integration, no hook equivalents. Less automation.

**Activation entry point** (all IDEs): 10-minute first-value guarantee — agent activation +
greeting + one useful command output in under 10 minutes.

---

## Agent Roster (Core AIOX agents)

| Agent | Role | When Used |
|-------|------|-----------|
| `@analyst` | Brainstorming, market research, project brief creation | Planning phase |
| `@pm` | PRD creation with human-in-the-loop refinement | Planning phase |
| `@architect` | Architecture specification, technical design | Planning phase |
| `@sm` | Scrum Master — transforms PRD+arch into hyperdetailed stories | Pre-dev |
| `@dev` | Implementation from story files | Dev cycle |
| `@qa` | Quality assurance, test validation | Post-dev |
| `@po` | Product Owner — backlog management, acceptance validation | Planning + review |

The sm-dev-qa cycle is the core dev loop: sm writes story → dev implements → qa validates → sm writes next story.

**Hyperdetailed stories** (key differentiator): story files contain not just acceptance criteria
but full implementation context, architectural decisions, code patterns, and what NOT to do.
The dev agent reads the story file and should have everything needed to implement without
asking follow-up questions.

---

## How AioX Differs from Claude Code Plugins

| Dimension | AioX Core | Claude Code Plugins (e.g., Maestro) |
|-----------|-----------|--------------------------------------|
| Scope | Multi-IDE framework; Claude Code is one target | Claude Code native; other IDEs not primary targets |
| Planning | First-class: analyst → pm → architect agents produce PRDs | No equivalent planning agent chain |
| Story format | Hyperdetailed story files with full context embedding | Stories via Maestro skill, less opinionated format |
| Squad concept | Packaged teams with tier-based routing, drop-in install | Skills are individual; no packaged team concept |
| Hook strategy | Explicit parity matrix; workarounds documented per IDE | Claude Code hooks; no multi-IDE abstraction |
| Community | Squads contributed via PR to aiox-squads repo | Plugin marketplace via .claude-plugin |
| Installation | `npx aiox-core init` / `npx aiox-core install` | `claude mcp add` or skill copy |
| Context management | Story files carry implementation context | Context managed via CLAUDE.md + dna.md |
| Config persistence | 5-layer (framework → project → user → session → override) | `.maestro/config.yaml` + trust.yaml |
| Dashboard | SSE-based observability layer (separate from CLI) | No dashboard |

**AioX's key advantage over Maestro**: the planning-to-story pipeline. The sm agent's
hyperdetailed story generation eliminates context gaps between planning and implementation.
A Maestro agent receiving a task has whatever the human wrote in the story; an AioX dev
agent receives a story the sm wrote with architectural context already embedded.

**Maestro's key advantage over AioX**: Ruflo/Claude Code hook integration depth.
AioX's Claude Code integration is one target among six; Maestro's entire design is
optimized for Claude Code's specific capabilities.

---

## Technical Patterns

### Pattern 1: Story-as-Context-Carrier

Story files in AioX serve as the primary context synchronization mechanism between agents.
The sm agent writes a story so complete that the dev agent needs no additional context.
Stories contain:
- Acceptance criteria in checklist form
- Architecture context (why this design, not just what)
- Code patterns and examples specific to the project
- Known anti-patterns to avoid for this story
- References to related stories

This eliminates the biggest failure mode in multi-agent dev: the implementation agent
lacking context that the planning agent had.

### Pattern 2: Voice DNA / Thinking DNA

AioX Squads (the community extension) introduces "mind cloning": agents carry the
documented thinking frameworks of real experts (Gene Kim, Donald Reinertsen, etc.).
This is not roleplay — it means the agent's decision heuristics are derived from
documented frameworks attributed to that expert.

### Pattern 3: Autonomy Level Classification

Squads declare their autonomy level (0–3):
- 0: all steps require human approval
- 1: deterministic operations auto-execute; LLM reasoning needs approval
- 2: data collection auto-executes; analysis needs approval
- 3: fully autonomous within defined constraints

This gives teams explicit control over how much an agent does without prompting.

### Pattern 4: Template Embedded Intelligence

AIOX templates are self-contained — they embed both the desired document output format
AND the LLM instructions needed to generate it (`[[LLM: instructions]]` blocks).
No separate task file is needed for document creation in many cases.

---

## Anti-Patterns Observed

1. **Portuguese-first documentation**: Primary README is in Portuguese. English version exists
   but the community engagement is predominantly PT-BR. May limit English-speaking adoption.

2. **Framework complexity vs. AIOX's own goal**: AIOX claims "10-minute first-value" but the
   README has 14+ sections before the Quick Start. The Codex CLI integration requires multiple
   `npm run sync:*` and `npm run validate:*` commands.

3. **Hook parity as workaround documentation**: the honest multi-IDE comparison is a strength,
   but it also means users are regularly routed to "run this script to compensate" paths that
   require understanding the underlying problem.

4. **No background workers**: unlike Ruflo's 11 scheduled workers, AioX has no autonomous
   background processes. All automation is triggered by user commands or hook events.

---

## Sources

- https://github.com/SynkraAI/aiox-core
- https://github.com/SynkraAI/aiox-core/blob/main/README.md (Portuguese primary)
- https://github.com/SynkraAI/aiox-core/blob/main/README.en.md
- https://github.com/SynkraAI/aiox-core/blob/main/docs/core-architecture.md
- https://github.com/SynkraAI/aiox-core/blob/main/docs/ide-integration.md
- https://github.com/SynkraAI/aiox-core/blob/main/squads/claude-code-mastery/config.yaml
