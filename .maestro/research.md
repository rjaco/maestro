# Maestro Competitive Research — Index

**Last Updated:** 2026-03-18
**Researcher:** Claude Sonnet 4.6

## Research Files Index

| File | Subject | Coverage |
|------|---------|----------|
| `research/wave8-intel.md` | **Wave 8 planning** | Claude Code v2.1.x gaps, OpenClaw vs Maestro post-Wave7, parallel spawning patterns, multi-repo coordination, functional hook testing, prioritized feature list |
| `research/ruflo.md` | Ruflo v3.5 full profile | Architecture, 60+ agents, MCP tools, SPARC, workers, consensus, memory, stream chaining, SWE-bench |
| `research/ruflo-gaps.md` | Ruflo features Maestro lacks | 20 patterns with gap analysis and priority ranking |
| `research/ruflo-sparc-workers-knowledge-graph.md` | Ruflo deep-dives | SPARC phases, scout agents, production validators, TDD, consensus protocols, Agent Booster, knowledge graph, claims, anti-drift, 12 workers reconciliation |
| `research/aiox-core.md` | AioX Core v4.2 | Squad management, hook parity matrix, multi-IDE strategy, agent roster, story-as-context-carrier pattern |
| `research/aiox-squads.md` | AioX Community Squads | Tier architecture, 12 squads catalog, routing patterns, dispatch DAG, veto conditions, community model |
| `research/aiox-dashboard.md` | AioX Dashboard | Web UI architecture, SSE observability, cockpit/monitor/cost views |
| `research/claude-agent-sdk.md` | Claude Agent SDK | SDK internals, subagent patterns, tool use |
| `research/claude-code-plugin-ecosystem-march-2026.md` | Plugin ecosystem | Marketplace, plugin formats, discovery |
| `research/claude-platform-features-march-2026.md` | Claude platform | Model capabilities, context windows, tool updates |
| `research/openclaw-deep-dive.md` | OpenClaw | Alternative orchestration approach |

---

## Competitor Matrix (High-Level)

| Feature | AioX Core | AioX Squads | Ruflo | Maestro (current) |
|---|---|---|---|---|
| Squad/team packaging | Yes (YAML manifest, tier routing) | Yes (community catalog, drop-in) | Yes (42+ skills, hive-mind) | Partial (skills only) |
| IDE parity | 6 IDEs (Claude = reference) | Same as AioX Core | MCP clients (Claude, Cursor, etc.) | Claude Code only |
| Planning agents | Yes (analyst → pm → architect) | Via squads | No first-class planning chain | No |
| Hyperdetailed stories | Yes (sm agent embeds full context) | Via squads | No | Partial |
| Background workers | No | No | 11 scheduled workers | No |
| Self-learning routing | No | No | Q-learning router + EWC++ | No |
| WASM Agent Booster | No | No | Yes (6 mechanical transforms) | No |
| Consensus protocols | No | No | Raft/BFT/Gossip/CRDT | No |
| Knowledge graph | No | No | MemoryGraph (PageRank + communities) | No |
| Community marketplace | GitHub PR model | GitHub PR model | IPFS-based plugin marketplace | Plugin marketplace |
| Hook system | Full (Claude Code), partial others | Same | 17 hooks + 11 workers | Yes |
| SPARC methodology | No | Via squad-creator | Yes (5 phases, 16 commands) | No |
| Production validator | No | No | Yes (mock-detection gate) | No |
| Scout/explorer agent | No | Partial (deep-research) | Yes (formal recon-only role) | No |

---

# Previous Research (Original Content Below)

**Sources:** SynkraAI/aiox-core (GitHub), SynkraAI/aiox-dashboard (GitHub), web research

---

## Competitor Matrix

| Feature | AIOX Core/Dashboard | Maestro (current) |
|---|---|---|
| Squads system | 31 named squads, YAML registry, tier-based routing | No squads concept |
| IDE parity | claude-code, cursor, codex, gemini, vscode, github-copilot, antigravity (7 IDEs) | Claude Code only |
| Preference persistence | 5-layer config (L1 framework → L5 user) at `~/.aiox/user-config.yaml` | Single `.maestro/config.yaml` |
| Story format | Structured markdown v2.0 with Gherkin AC, CodeRabbit section, agent assignment matrix | Ad-hoc task descriptions |
| Multi-language | EN + PT + ES + ZH docs; fallback file arrays in config | EN only |
| Dashboard | Web UI (Next.js): cockpit, live monitor, cost tracking, pipeline visualizer, KPI cards, agent status | Terminal only |
| Hook system | UserPromptSubmit + code-intel context injection (XML) + session TTL cleanup | Minimal |
| Constitutional gates | 5 numbered gates (G1–G4+) blocking/advisory at epic/story/dev/context points | None |
| Cost tracking | Per-provider, per-squad, 7-day trend line chart | None |
| Agent monitoring | Real-time status cards, activity timeline, perf stats (success rate, avg latency) | None |
| Execution modes | yolo / interactive / preflight per story | Single mode |
| Worktree support | `autoClaude.worktree` — auto-create on story start, max 10, stale cleanup | None |

---

## 1. AIOX Squads Implementation

### Source
`legacy/.aios-core/SQUAD-REGISTRY.yaml` — 31 squads, 270+ agents, 200+ tasks

### Data model

Each squad in the registry has this shape:

```yaml
full-stack-dev:
  domain: software-engineering
  type: specialist           # system | infrastructure | specialist | pipeline | advisory | domain | expert
  entry_agent: dev-chief
  activation: "@full-stack-dev"
  aliases: ["@dev", "@codigo"]
  slash_prefix: dev
  expertise: [clean-code, architecture, testing, patterns, microservices]
  keywords: [codigo, desenvolvimento, arquitetura, testes]
  agents: 11
```

Top-level groupings: infrastructure, development, content, marketing, research, operations, advisory.

### Routing rules

Two routing indexes live at the bottom of the registry:

- `routing.by_domain` — maps keyword (e.g. `trafego`) to an ordered list of squad names
- `routing.by_task` — maps verb (e.g. `criar`, `escalar`, `validar`) to squad list

The global orchestrator agent (`orquestrador-global`) uses intent classification against these two indexes to route a user request to the right squad. Entry is always through a single `entry_agent` per squad.

### How it differs from Maestro

Maestro has no squads concept. AIOX squads are persistent named collections of agents with a registry, routing table, typed domain/type classification, and a CLI activation handle (`@squad-name`). The squad is the unit of discovery, routing, and reuse. Maestro dispatches agent skills but has no named, persistent agent group abstraction with its own slash prefix.

### Squad template structure

A new squad scaffolds as a directory with:

```
squad.yaml           # manifest: name, version, aiox.type=squad, components lists
agents/*.yaml
tasks/*.yaml
workflows/*.yaml
templates/*.md
tests/*.test.js
```

The `squad.yaml` `components` field lists glob patterns for each artifact type. This lets the orchestrator enumerate a squad's full capability surface without reading every file.

---

## 2. Hook Parity Across IDEs

### Source
`.aiox-core/core-config.yaml` (`ideSync` section) + `.aiox-core/core/synapse/runtime/hook-runtime.js`

### Supported IDEs

```yaml
ideSync:
  source: .aiox-core/development/agents
  targets:
    claude-code:   format: full-markdown-yaml   path: .claude/commands/AIOX/agents
    codex:         format: full-markdown-yaml   path: .codex/agents
    gemini:        format: full-markdown-yaml   path: .gemini/rules/AIOX/agents
    github-copilot: format: github-copilot      path: .github/agents
    cursor:        format: condensed-rules      path: .cursor/rules/agents
    antigravity:   format: cursor-style         path: .antigravity/rules/agents
```

Also in `ide.selected` (non-sync list): `vscode`, `zed`, `claude-desktop`.

### Hook runtime

The Synapse hook fires on `UserPromptSubmit`. It:
1. Resolves or creates a session file under `.synapse/sessions/`
2. On the very first prompt of a session (`prompt_count === 0`), fires stale session cleanup (7-day TTL, configurable via `synapse.session.staleTTLHours`)
3. Returns `hookSpecificOutput.hookEventName = "UserPromptSubmit"` + `additionalContext` (XML)

The `additionalContext` is populated by `hook-runtime.js` (code-intel layer), which injects:

```xml
<code-intel-context>
  <target-file>src/foo.ts</target-file>
  <existing-entity>
    <path>...</path>
    <purpose>...</purpose>
  </existing-entity>
  <referenced-by count="3">
    <ref file="..." context="..." />
  </referenced-by>
  <dependencies count="5">
    <dep name="..." layer="..." />
  </dependencies>
</code-intel-context>
```

This is injected into every prompt where a file is being edited, giving the agent automatic dependency and reference awareness without manual context loading.

### IDE sync validation (doctor check)

`doctor/checks/ide-sync.js` compares `.aiox-core/development/agents/*.md` (source of truth) against `.claude/commands/AIOX/agents/*.md` (synced). Returns PASS / WARN / FAIL with a `fixCommand: "npx aiox-core install --force"`.

### Format per IDE

- `full-markdown-yaml` — Full agent definition with YAML frontmatter (Claude Code, Codex, Gemini)
- `condensed-rules` — Stripped-down rules format (Cursor)
- `cursor-style` — Cursor format variant (Antigravity)
- `github-copilot` — GitHub Copilot agent format

**Implication for Maestro:** Maestro only writes `.claude/` files. AIOX maintains one canonical agent source in `.aiox-core/development/agents/` and fans out to 6 IDE-specific paths with format translation. A doctor check validates sync state. Maestro should adopt: (1) canonical source + fan-out pattern, (2) sync validation in health check.

---

## 3. Developer Preference Persistence

### Source
`core-config.yaml`, `core/config/schemas/user-config.schema.json`, `core/config/templates/user-config.yaml`

### Configuration layer hierarchy

AIOX has 5 explicit config layers, numbered L1–L5, ordered by override priority (L5 wins):

| Layer | Location | Scope | Contents |
|---|---|---|---|
| L1 | `.aiox-core/core-config.yaml` | Framework defaults | All defaults shipped with the framework |
| L2 | `.aiox-core/project-config.yaml` | Team-shared per-project | PRD paths, GitHub integration, IDE list |
| L3 | (inferred) environment vars | Runtime | Env interpolation via `${VAR}` in config values |
| L4 | (inferred) project local override | Per-developer, not committed | `.aiox-core/local-config.yaml` |
| L5 | `~/.aiox/user-config.yaml` | Cross-project, per-user | Profile mode, default model, default language, educational mode |

### L5 user-config fields (the portable developer identity)

```yaml
user_profile: "bob" | "advanced"   # bob = simplified single-agent view; advanced = full access
default_model: "claude-sonnet"
default_language: "pt-BR"
coderabbit_integration: true
educational_mode: false
```

The `user_profile: bob` mode is notable: in "bob" mode, the UI and CLI surface only a single orchestrator interface. The 270+ underlying agents are hidden. This is their simplified onboarding UX.

### Preference surfacing

`core-config.yaml` also carries:
- `agentIdentity.greeting.preference: auto` — context/session detection for greeting behavior
- `projectStatus.cacheTimeSeconds: 60` — TTL for status cache
- `lazyLoading.heavySections: [pvMindContext, squads, registry]` — defers loading expensive sections
- `decisionLogging.format: adr` — persists agent decisions as Architecture Decision Records in `.ai/`

---

## 4. Contextualized Stories — Story Format

### Source
`.aiox-core/docs/standards/STORY-TEMPLATE-V2-SPECIFICATION.md`, `legacy/.aios-core/development/workflows/story-development-cycle.yaml`

### Story v2.0 markdown structure

```markdown
# Story X.X: [Title]

**Epic:** ...   **Story ID:** X.X   **Sprint:** N   **Priority:** emoji   **Points:** N
**Effort:** N   **Status:** emoji    **Type:** emoji

## Cross-Story Decisions
| Decision | Source | Impact on This Story |

## User Story
Como [persona], Quero [capability], Para [value].

## Objective
2-3 sentence description.

## Tasks
### Phase 1: Name (Estimated Time)
- [ ] 1.1 Task
  - sub-detail

## Acceptance Criteria
```gherkin
GIVEN / WHEN / THEN / AND
```

## CodeRabbit Integration
### Story Type Analysis
| Attribute | Value | Rationale |  (Type, Complexity, Test Requirements, Review Focus)

### Agent Assignment
| Role | Agent | Responsibility |

### Self-Healing Config
```yaml
reviews:
  auto_review: { enabled: true, drafts: false }
  path_instructions: [{ path: "...", instructions: "..." }]
```

## Dev Agent Record
(execution log written by @dev during implementation)

## QA Results
(structured test results written by @qa)
```

### Story lifecycle automation

The `story-development-cycle.yaml` workflow defines 4 phases with named agents:

1. `create_story` — @sm agent, uses `create-next-story` or `brownfield-create-story` task
2. `validate_story` — @po agent, 10-point checklist; failure loops back to @sm
3. `implement_story` — @dev agent; status moves to "In Review" on completion
4. `qa_review` — @qa agent, quality gate (lint, typecheck, test, build, CodeRabbit, OWASP basics); failure loops back to @dev

Each step has typed `outputs` (file names, report names, status values) and explicit `on_failure` routing. The workflow exposes `handoff_prompts` — template strings with `{{variables}}` injected at each transition.

**Three execution modes per story:**
- `yolo` — 0-1 prompts, autonomous
- `interactive` — 5-10 prompts, default, educational checkpoints
- `preflight` — 10-15 prompts, full upfront analysis before any code

### Constitutional gates

5 numbered gates guard the workflow, each tied to a Constitution article:

| Gate | Agent | Type | Article |
|---|---|---|---|
| G1 | @po/@sm | Advisory | Epic creation — checks existing epics |
| G2 | @sm | Advisory | Story creation — checks existing tasks/templates |
| G3 | @po | Blocking | Story validation — enforces 10-check AC |
| G4 | @dev | Blocking | Dev context — enforces story-driven development |
| (G5+) | @qa | Blocking | Quality gate before merge |

Gates are implemented as `VerificationGate` subclasses with circuit breaker, timeout, and `blocking: boolean` flag.

---

## 5. Multi-Language Support

### Source
`docs/` directory tree, `SHARD-TRANSLATION-GUIDE.md`, `core-config.yaml`

### Languages present

Confirmed language directories in `docs/`:
- `docs/en/` — English
- `docs/pt/` — Portuguese (Brazilian)
- `docs/es/` — Spanish
- `docs/zh/` — Chinese (Simplified, inferred from file tree)

Each language directory mirrors the same subdirectory structure: `agents/`, `aiox-agent-flows/`, `aiox-workflows/`, `api/`, `architecture/`, `community/`, `framework/`, `guides/`, `installation/`, `platforms/`, `specifications/`.

### Fallback mechanism

`core-config.yaml` has two arrays:

```yaml
devLoadAlwaysFiles:
  - docs/framework/coding-standards.md   # English primary
  - docs/framework/tech-stack.md

devLoadAlwaysFilesFallback:
  - docs/pt/framework/coding-standards.md
  - docs/pt/framework/tech-stack.md
  - docs/es/framework/coding-standards.md
  - docs/es/framework/tech-stack.md
```

The agent tries primary paths first; falls back to language-specific paths in order.

### Shard translation

When sharding a Portuguese document into per-section files, a built-in 60+ term dictionary translates Portuguese section headings to English filenames automatically (e.g., `visão do produto` → `product-vision.md`). This ensures all tooling that references English filenames continues to work regardless of the author's writing language.

### User-facing language

`user-config.yaml` has `default_language: "pt-BR"` — agents respond in the user's preferred language even when internal docs are in English.

---

## 6. AIOX Dashboard — Visualization Patterns

### Source
`src/components/dashboard/`, `src/components/monitor/`, `src/components/bob/`, `src/components/status-bar/`

### Layout

The dashboard has a tabbed cockpit layout: Overview, Agents, Costs, MCP, System.

There is also a separate `/monitor` page (`LiveMonitor`) and `/squads` page.

A fixed 28px status bar at the bottom of the screen shows persistent state: connection, API rate, Claude status, active agent name, notification count.

### Chart types implemented (custom SVG, no chart library)

All charts are custom SVG components without a third-party chart library. Colors resolved from CSS custom properties at runtime.

**LineChart** (`Charts.tsx`):
- Animated polyline + filled area polygon
- Interactive hover: invisible 12px hit area circles, glow ring on hover, tooltip
- Grid lines via flex divs, not SVG
- Animated path draw on mount (`pathLength: 0 → 1` via Framer Motion)
- Used for: cost trends (7-day), performance over time

**BarChart** (`Charts.tsx`):
- Also custom SVG
- Used for: cost by squad

### KPI / metric cards

**CockpitKpiCard** (cockpit design system):
- Label + value + change text + trend indicator (up/down/neutral)
- Used in grid: `repeat(auto-fit, minmax(180px, 1fr))`

**MetricCard** (MetricsPanel):
- Icon + label + large tabular-num value + optional ProgressBar
- 4-column grid (2 cols on mobile)
- Variants: `error` (> 80%), `warning` (> 60%), `default`
- Metrics tracked: active executions, errors/min, latency (ms), throughput (req/min)

**LiveMetricCard** — real-time updating card with polling

### Progress bars

`ProgressBar` component:
- Sizes: `sm` (h-1), `md` (h-2), `lg` (h-3)
- Variants: default, success, warning, error, info
- `glow: boolean` — adds CSS box-shadow using a `--progress-*-glow` token
- Animated via Framer Motion `width: 0 → N%` with spring easing `[0.16, 1, 0.3, 1]`
- ARIA: `role="progressbar"`, `aria-valuenow/min/max`, `aria-label`

### Status indicators

**StatusDot** — small colored circle; states: `success`, `working`, `waiting`, `idle`, `error`; `pulse: boolean` for animated ping ring; `glow: boolean`

**StatusBar** (fixed footer):
- Left: Wifi icon + Connected/Disconnected, API rate `N/100`, Claude Ready/Busy
- Right: Bob Active/Idle, active agent badge (`@agent-name` in `bg-blue-500/15`), notification bell with unread count

### Pipeline / execution visualization

**PipelineVisualizer** (`bob/PipelineVisualizer.tsx`):
- Vertical stepper: each phase is a circle + connecting line + label
- Circle states: pending (outlined dot), in_progress (spinning Loader2 icon, blue ring), completed (CheckCircle2 green), failed (AlertTriangle red)
- Connector line changes from `bg-white/10` to `bg-green-500/40` when phase completes
- Overall ProgressBar shown at bottom when pipeline is active

### Agent monitor

**AgentMonitorCard** — per-agent card showing: name, status badge, phase text, progress bar, story ID, model (opus/sonnet/haiku), last activity time, success rate, avg response time

**AgentsMonitor** — full page with:
- Filter tabs: All / Working / Idle / Error
- Polling interval: 5000ms
- Fallback: populates demo data from AIOS registry after 2s if API is unavailable
- **AgentActivityTimeline** — chronological event list
- **AgentPerformanceStats** — aggregate stats panel

### Event/activity feed

**EventList** — event types: `tool_call`, `message`, `error`, `system`; each entry shows agent, description, duration, success/fail icon; errors highlighted in red

**LiveMonitor** also shows a **CurrentToolIndicator** — appears when an agent is actively running a tool; shows tool name + animated ellipsis (`.` → `..` → `...`) + elapsed time in ms/s format

### Cost tracking

**CostsTab**:
- 3 KPI cards: Today / This Week / This Month
- Cost by Provider: Claude vs. OpenAI, each row shows cost + token count
- Cost trend: 7-day LineChart with day labels
- Cost by Squad: BarChart sorted by cost descending

### Ticker strip

**CockpitTickerStrip** — horizontal scrolling marquee showing: agents online, execution count, success rate %, MCP tools count, avg latency. Speed: 25px/s.

### Alerts

**AlertBanner** — variants: `error` (red), `warning` (yellow); includes icon + title + body text; dismissible

---

## Technical Patterns

### Pattern 1 — Canonical source + IDE fan-out

One agent definition file → multiple IDE-specific output paths with format translation. A doctor check validates drift. This is more reliable than keeping per-IDE copies in sync manually.

### Pattern 2 — Demo fallback data

When the API is unreachable, all dashboard components fall back to static demo data derived from the actual agent registry. This prevents blank states and allows the UI to be useful offline. Components seed themselves after a 2s timeout if no real data arrives.

### Pattern 3 — CSS custom property resolution at runtime

Chart colors are read from `getComputedStyle(document.documentElement)` at render time, not hardcoded. This means charts automatically adapt to theme changes without prop drilling.

### Pattern 4 — Layered config merge with env interpolation

Config values use `${ENV_VAR}` syntax. A dedicated `env-interpolator.js` resolves these at load time. This lets the same config work in different environments without forking files.

### Pattern 5 — Fire-and-forget maintenance on first prompt

Session cleanup (stale TTL enforcement) runs fire-and-forget on `prompt_count === 0`. Never blocks the main hook response. Pattern is: `try { doMaintenance(); } catch (_) { /* never block */ }`.

### Pattern 6 — Constitutional enforcement via numbered gates

A `constitution.md` defines non-negotiable principles (CLI First, Agent Authority, Story-Driven Development, No Invention, Quality First). Numbered gates (G1–G5) enforce these at key decision points. Gates are either advisory (warn only) or blocking (halt execution). Blocking gates use a circuit breaker to avoid cascading failures.

### Pattern 7 — Execution mode selection per invocation

Stories can be run in yolo / interactive / preflight mode at invocation time. The mode is not a global setting — it's a per-invocation parameter with a sensible default (`interactive`). This gives power users autonomy without forcing everyone into the same UX.

---

## Anti-Patterns

### Anti-pattern 1 — UI before CLI (explicitly banned by Constitution Article I)

The AIOX Constitution explicitly states: "Toda funcionalidade nova DEVE funcionar 100% via CLI antes de qualquer UI." The gate system enforces a warning when a UI component is created before its CLI counterpart exists. Maestro should adopt this hierarchy explicitly.

### Anti-pattern 2 — Hardcoded per-IDE agent paths

AIOX observed that keeping separate agent definitions per IDE led to drift. Their solution is a single source + fan-out + drift detection. The anti-pattern to avoid is maintaining .claude/ and .cursor/ definitions as separate files edited independently.

### Anti-pattern 3 — Blocking on maintenance operations

The stale session cleanup and other housekeeping operations are always fire-and-forget. Letting maintenance tasks block user-facing operations is an anti-pattern they explicitly guard against in the hook runtime with try/catch that never re-throws.

---

## SEO / Discovery Landscape (for open-source discoverability)

AIOX Core GitHub topics: `agents`, `ai`, `ai-agents`, `automation`, `claude`, `cli`, `development`, `framework`, `fullstack`, `nodejs`, `orchestration`, `typescript`. The repo description is: "Synkra AIOS: AI-Orchestrated System for Full Stack Development - Core Framework v4.0."

Maestro's discoverability gaps vs. AIOX: no GitHub topics set on the repo, no explicit framework version in description.

---

## Broader Research Findings

### Claude Code plugin best practices (2026)

Sources: Composio awesome-claude-plugins, code.claude.com/docs/plugins, Firecrawl blog

- Minimize provided context: clear context after completing user stories, use `/compact` frequently
- Subagents for complex multi-step tasks; single agents for simple tasks
- Tool annotations matter: `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint` should be set on every tool
- `/loop` command for recurring monitoring tasks
- Commit at least once per hour during long autonomous runs
- Wildcard `/permissions` syntax to manage tool authorization safely
- `UserPromptSubmit` hook is the primary injection point for context enrichment (confirmed by AIOX implementation)

### Agent orchestration patterns (2026)

Sources: Anthropic Agentic Coding Trends Report, Azure Architecture Center, AI Agents Plus blog

**Hierarchical orchestration** is the dominant production pattern: a top-level orchestrator with no tools of its own decomposes goals and routes to specialist agents. Gartner reported a 1,445% surge in multi-agent system inquiries from Q1 2024 to Q2 2025.

Five canonical patterns:
1. Hierarchical supervisor → workers (most reliable for enterprise)
2. Peer-to-peer collaboration (best for creative/iterative tasks)
3. Event-driven pub/sub (best for real-time parallel workflows)
4. Sequential pipeline (best for linear, deterministic workflows)
5. Consensus/voting (best for high-stakes decisions requiring validation)

**Standardized inter-agent message format:**
```json
{
  "from": "research-agent",
  "to": "analysis-agent",
  "timestamp": "ISO8601",
  "type": "data-ready",
  "payload": { ... }
}
```

**Shared state structure:**
```json
{
  "task_id": "abc123",
  "status": "in_progress",
  "assigned_agents": ["research", "writing"],
  "results": { "research": { "completed": true }, "writing": { "completed": false } },
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

**Autonomy spectrum:** The 2026 pattern is not full autonomy — it is "human on the loop" where humans review outcomes but don't approve each step. Full "human in the loop" is used only for high-stakes irreversible actions.

**MCP as coordination layer:** Model Context Protocol is becoming the standard for how agents expose tools to each other. An agent invoking another agent via MCP tool call is the recommended Anthropic SDK pattern.

---

## Concrete Features for Maestro — Prioritized

The following are specific, implementable features derived from this research. Each has enough specification detail to begin implementation.

### Feature 1 — Squad Registry (`SQUAD-REGISTRY.yaml`)

Implement a `SQUAD-REGISTRY.yaml` at `.maestro/squads/registry.yaml`. Each entry:

```yaml
my-squad:
  domain: software-engineering
  type: specialist
  entry_agent: dev-chief
  activation: "@my-squad"
  aliases: ["@dev"]
  slash_prefix: dev
  expertise: [clean-code, architecture, testing]
  keywords: [code, develop, architecture]
  agents: N
```

Add `routing.by_domain` and `routing.by_task` indexes. The Maestro orchestrator reads this registry to route requests rather than hardcoding agent dispatch logic.

### Feature 2 — IDE Fan-Out Sync

Add `ideSync` config block to Maestro's config:

```yaml
ideSync:
  enabled: true
  source: .maestro/agents
  targets:
    claude-code: { enabled: true, path: .claude/commands/agents, format: full-markdown-yaml }
    cursor:      { enabled: true, path: .cursor/rules/agents,   format: condensed-rules }
    gemini:      { enabled: true, path: .gemini/rules/agents,   format: full-markdown-yaml }
```

Add a `maestro doctor --check ide-sync` that validates source vs. synced counts and reports drift with a fix command.

### Feature 3 — Five-Layer Config with `~/.maestro/user-config.yaml`

Move user preferences out of the project config into `~/.maestro/user-config.yaml` (L5, highest priority):

```yaml
user_profile: "standard" | "power"
default_model: "claude-sonnet"
default_language: "en"
educational_mode: false
```

The project `.maestro/config.yaml` becomes L2 (team-shared). This enables preferences that travel with the developer across projects.

### Feature 4 — Story Format v2 with Constitutional Gates

Adopt the AIOX story template structure: status emoji, priority emoji, type emoji, user story (As/Want/So), phased task checklist, Gherkin acceptance criteria, agent assignment table, QA results section.

Add gate validation before `*develop`: block if no valid story file is referenced. Gate is a JS/TS module with `blocking: boolean` and circuit breaker.

Add `execution_mode` parameter: `*develop STORY-1.2 yolo | interactive | preflight` (default: `interactive`).

### Feature 5 — `UserPromptSubmit` Hook with Code-Intel Context

Implement a `UserPromptSubmit` hook that:
1. Resolves the file being edited from the prompt
2. Queries a code graph (or fallback: `grep` references) for that file
3. Injects XML context block:

```xml
<code-intel-context>
  <target-file>path/to/file.ts</target-file>
  <referenced-by count="N"> <ref file="..." /> </referenced-by>
  <dependencies count="N"> <dep name="..." /> </dependencies>
</code-intel-context>
```

4. Runs stale session cleanup fire-and-forget on first prompt of session

### Feature 6 — Multi-Language Doc Fallback

In `.maestro/config.yaml`:

```yaml
devLoadAlwaysFiles:
  - docs/framework/coding-standards.md
  - docs/framework/tech-stack.md
devLoadAlwaysFilesFallback:
  - docs/pt/framework/coding-standards.md
  - docs/es/framework/coding-standards.md
```

The dev agent tries primary paths; falls back in order. No language detection logic required — just try each path and use the first that exists.

### Feature 7 — Terminal Status Bar

Add a persistent status line at the bottom of Maestro terminal output (updated via ANSI cursor positioning):

```
[Connected] API: 12/100  Claude: Ready  @dev (working) Story-3.2 (65%)  Alerts: 0
```

Fields: connection status, API request count, active agent name, current story + progress %, unread alert count.

### Feature 8 — Pipeline Visualizer (terminal version)

When a multi-step workflow runs, render a vertical stepper in the terminal:

```
[ ] Phase 1: Create Story
[>] Phase 2: Validate Story ...   (running 12s)
[ ] Phase 3: Implement
[ ] Phase 4: QA Review
─────────────────────────────
Overall: 25% [====               ]
```

States: pending (empty box), in_progress (> with elapsed), completed (check), failed (x). Update in-place using ANSI escape codes.

### Feature 9 — Cost Tracking

Track and display token costs per story and per session:

```
Session cost: $0.14  |  Story-3.2: $0.09  |  Today: $1.24
```

Store per-session cost in `.maestro/logs/costs/YYYY-MM-DD.jsonl`. Show a 7-day trend at end of day using a simple sparkline (Unicode block characters).

### Feature 10 — Demo Fallback Data Pattern

For any Maestro component that reads live state (agent status, story progress, costs), implement a 2-second fallback: if no real data arrives within 2s, populate from a static demo dataset derived from `.maestro/squads/registry.yaml`. Prevents blank states during initialization or when the API is unreachable.

---

*Research complete. All findings traced to source URLs or file paths in SynkraAI/aiox-core and SynkraAI/aiox-dashboard.*

---

# OpenClaw Deep-Dive Research

**Date:** 2026-03-18
**Researcher:** Claude Sonnet 4.6
**Primary source:** https://github.com/openclaw/openclaw (323k stars as of research date)
**Supporting sources:** docs.openclaw.ai, clawhub.ai, web research

---

## What Is OpenClaw

OpenClaw is a personal AI assistant daemon (Node.js 22+, MIT license) created by Peter Steinberger in November 2025. It reached 323k GitHub stars by March 2026.

Tagline: "Your own personal AI assistant. Any OS. Any Platform. The lobster way."

The core architecture: a persistent **Gateway** process runs as a system daemon (launchd/systemd) and acts as a routing control plane. It multiplexes 22+ messaging channels (WhatsApp, Telegram, Slack, Discord, Google Chat, Signal, iMessage, BlueBubbles, IRC, Microsoft Teams, Matrix, Feishu, LINE, Mattermost, Nextcloud Talk, Nostr, Synology Chat, Tlon, Twitch, Zalo, WebChat) through a single local WebSocket server at `ws://127.0.0.1:18789`.

The Gateway is not the assistant — it is the control plane. The assistant lives in workspace files and session state the Gateway manages.

---

## Competitor Matrix (OpenClaw vs Maestro)

| Dimension | OpenClaw | Maestro (current) |
|---|---|---|
| Runtime model | Persistent Gateway daemon (launchd/systemd), always-on | Per-session CLI invocation, no daemon |
| Messaging channels | 22+ (WhatsApp, Telegram, Slack, Discord, Signal, iMessage, etc.) | None — terminal only |
| Personality system | SOUL.md + USER.md + AGENTS.md injected every session | CLAUDE.md / dna.md only |
| Memory | MEMORY.md (long-term) + daily memory/YYYY-MM-DD.md (short-term) + optional LanceDB vector index | None built-in |
| Skill injection | XML compact list injected into system prompt; 3-tier precedence (workspace > managed > bundled) | Skills as markdown slash commands |
| Marketplace | ClawHub (13,729+ community skills, `npx clawhub install`) | In-repo plugin marketplace (`.claude-plugin/`) |
| Multi-agent | Multiple agents per Gateway, each with isolated workspace + sessions | No multi-agent routing |
| Sub-agent spawning | `sessions_spawn` tool → spawns Claude Code / Pi / Codex / OpenCode / Gemini sessions | No spawning primitive |
| Cron / autonomy | Built-in cron scheduler, heartbeat wakeup, HEARTBEAT.md, BOOT.md | Background daemon script only |
| Session persistence | JSONL transcripts, resume by session ID, daily reset policy | Ephemeral per Claude Code session |
| Pre-compaction flush | Silent agentic turn before context compaction to write MEMORY.md | No equivalent |
| Sandbox | Docker-based per-session isolation (configurable per session type) | Git worktrees for isolation |
| Voice | macOS/iOS wake words (Swabble), Android continuous voice, ElevenLabs TTS | None |
| Canvas | Live A2UI HTML canvas served from Gateway (port 18793) | None |
| Model failover | Multi-provider rotation with cooldown, auth profile per agent | Single-model |

---

## 1. What OpenClaw Is and How It Works

### Architecture

```
Messaging channels (22+)
         |
         v
  +------------------+
  |     Gateway      |  ← Node.js daemon, ws://127.0.0.1:18789
  |  (control plane) |  ← WebSocket server, launchd/systemd managed
  +------------------+
         |
         +-- Pi agent runtime (embedded, RPC mode)
         +-- CLI (openclaw ...)
         +-- WebChat UI
         +-- macOS app / iOS node / Android node
         +-- Canvas server (port 18793)
```

The Gateway is a persistent process that manages:
- Session state (stored as JSONL at `~/.openclaw/agents/<agentId>/sessions/`)
- Channel connections (each channel maintains a WebSocket/bot connection to its platform)
- Channel-to-session routing (`channel_id → session_key` mapping in local DB)
- Tool execution (browser control, cron scheduler, node commands)
- Skills loading and injection
- Memory persistence and flushing

The embedded Pi agent runtime (`src/agents/piembeddedrunner.ts`) executes the AI interaction loop:
1. Resolves which session handles the inbound message
2. Assembles context from session history, memory files, workspace files, and skills
3. Streams model response while intercepting tool calls
4. Executes tools (potentially sandboxed in Docker) and persists state

**Source:** `src/acp/control-plane/manager.core.ts`, README.md, docs.openclaw.ai/gateway

### How It Runs "Above" Claude Code

OpenClaw does not run "above" Claude Code in the traditional sense — OpenClaw *is* the orchestrator, and Claude Code (under the ACP protocol via `acpx`) is one of several **backends** it can spawn. The relationship is:

```
OpenClaw Gateway
    |
    +-- ACP runtime (src/acp/) → spawns → claude-agent-acp (Claude Code headless)
    +-- ACP runtime → spawns → codex-acp (Codex headless)
    +-- ACP runtime → spawns → pi-acp (Pi/Tau headless)
    +-- ACP runtime → spawns → opencode-acp, gemini-acp, kimi-acp
```

The `acpx` adapter (`extensions/acpx/`) provides a unified CLI for driving any ACP-compatible coding agent. Spawn modes:
- `run` (oneshot): creates a session, runs task, closes
- `session` (persistent): session stays alive after task; follow-ups continue in the same thread

**Source:** `extensions/acpx/skills/acp-router/SKILL.md`, `src/agents/acp-spawn.ts`

---

## 2. Autonomous Personality System (SOUL.md)

### Workspace File Map

Every agent has a workspace directory (`~/.openclaw/workspace` by default). The workspace contains markdown files injected into the system prompt at the start of each session:

| File | Purpose | Load scope |
|---|---|---|
| `AGENTS.md` | Operating instructions, behavioral rules, priorities | Every session |
| `SOUL.md` | Persona, tone, personality, boundaries | Every session |
| `USER.md` | Who the user is, how to address them | Every session |
| `IDENTITY.md` | Agent name, vibe, emoji | Every session |
| `TOOLS.md` | Local tool conventions (not tool availability) | Every session |
| `HEARTBEAT.md` | Short checklist for periodic wakeup runs | Heartbeat sessions |
| `BOOT.md` | Startup checklist on gateway restart | Gateway boot only |
| `MEMORY.md` | Curated long-term facts and preferences | Private/direct sessions only |
| `memory/YYYY-MM-DD.md` | Daily running notes | Today + yesterday |

The Gateway truncates files that exceed `bootstrapMaxChars` (default: 20,000 chars) and enforces `bootstrapTotalMaxChars` (default: 150,000) across all injected files.

**Source:** `docs/concepts/agent-workspace.md`

### SOUL.md Framework (aaronjmars/soul.md)

The broader SOUL.md ecosystem (independent repo, used with OpenClaw) captures user personality by ingesting social/writing data exports and producing:
- `SOUL.md` — identity, worldview, core opinions
- `STYLE.md` — communication patterns, voice, writing conventions
- `SKILL.md` — operating modes (tweets, essays, conversations)
- `MEMORY.md` — session continuity

The key pattern: the agent reads its own identity files at the start of every session so it "knows who it is" regardless of which channel or device initiated the conversation.

**Source:** https://github.com/aaronjmars/soul.md

---

## 3. Communication Channels

### Architecture

Each channel runs as an independent adapter (bot connection / webhook / polling loop) inside the Gateway process. Channel adapters are in `src/telegram`, `src/discord`, `src/slack`, `src/signal`, `src/imessage`, `src/web` (WhatsApp), with extensions under `extensions/msteams`, `extensions/matrix`, `extensions/zalo`, etc.

The session routing model:
- Each unique `(channel, conversation_id)` pair maps to a `session_key`
- Direct messages collapse to `agent:<agentId>:main` (single session across channels, for continuity)
- Group chats isolate: `agent:<agentId>:<channel>:group:<id>`
- Telegram topics add `:topic:<threadId>`
- Multi-account inboxes can scope `per-account-channel-peer`

A single Gateway can handle 22+ platforms simultaneously because it maintains a `channel_id → session_id` in-memory + disk mapping. Each channel maps to exactly one active session; sessions resume with `--resume <sessionId>`.

### Security Defaults

New senders get a pairing code challenge — the bot does not process their message until approved:
```
dmPolicy="pairing"   (default for Telegram, WhatsApp, Signal, iMessage, Discord, Google Chat, Slack)
dmPolicy="open"      (opt-in; requires "*" in allowFrom list)
```

**Source:** README.md, `src/routing/`

---

## 4. Spawning and Managing Claude Code Instances

### The ACP Protocol

OpenClaw uses the **ACP (Agent Control Protocol)** as the standard interface for spawning and controlling external coding agent processes. The `acpx` CLI tool wraps multiple ACP-compatible agents behind a unified interface.

Default adapter commands:
```
pi      → npx pi-acp
claude  → npx -y @zed-industries/claude-agent-acp
codex   → npx @zed-industries/codex-acp
opencode→ npx -y opencode-ai acp
gemini  → gemini
kimi    → kimi acp
```

### Spawn Flow

From `src/agents/acp-spawn.ts`, the spawning function `SpawnAcpParams` accepts:

```typescript
type SpawnAcpParams = {
  task: string;
  label?: string;
  agentId?: string;
  resumeSessionId?: string;
  cwd?: string;
  mode?: "run" | "session";   // oneshot vs persistent
  thread?: boolean;            // bind to a channel thread
  sandbox?: "inherit" | "require";
  streamTo?: "parent";
}
```

The spawn creates a new ACP session via `AcpSessionManager` (singleton), which:
1. Creates a session entry in the session store
2. Obtains a runtime handle from `RuntimeCache`
3. Queues the turn via `SessionActorQueue` (per-session serialized queue)
4. Streams the turn result back through the Gateway

### Session Actor Queue

Each session has its own `KeyedAsyncQueue` entry — turns for the same session are serialized, but turns for different sessions run concurrently. This is the mechanism for running multiple Claude Code instances simultaneously without interference.

**Source:** `src/acp/control-plane/session-actor-queue.ts`, `src/agents/acp-spawn.ts`

### Thread Binding

When `thread: true`, the spawn creates a new channel thread and binds the ACP session to it. All follow-up messages in that thread route to the same ACP session. This enables a Slack/Discord thread that is a live terminal into a Claude Code session.

### Sandbox Policy

Sandboxed sessions (Docker containers) cannot spawn ACP sessions because ACP runs on the host. This is enforced in `resolveAcpSpawnRuntimePolicyError`.

---

## 5. Skill Injection Mechanism

### Format

Skills are directories containing a `SKILL.md` with YAML frontmatter:

```yaml
---
name: my-skill
description: What this skill does
user-invocable: true          # expose as slash command (default true)
disable-model-invocation: false
command-dispatch: tool        # bypass model, invoke tool directly
requires:
  bins: [jq, git]             # must be on PATH
  env: [SOME_API_KEY]
  config: [channels.slack.enabled]
os: [darwin, linux]
always: false                 # true bypasses all gates
---
```

### Loading Precedence (3 tiers)

1. Workspace skills (`<workspace>/skills/`) — highest priority
2. Managed/local skills (`~/.openclaw/skills/`)
3. Bundled skills (shipped with OpenClaw core)

Plugins can also ship skills. Extra directories via `skills.load.extraDirs`.

### Prompt Injection

When eligible, OpenClaw builds a compact XML list of available skills and injects it into the system prompt at session start:

```
~195 chars base overhead + ~97 chars per skill + name/description/location lengths
```

The injection happens at session start: environment variables are applied, the XML block is built, the system prompt is assembled, then environment is restored. This prevents cross-run pollution.

### Gating

Skills are filtered at load time based on `requires.*` conditions. If a binary is not on PATH or an env var is not set, the skill is silently excluded from the injected list.

**Source:** `docs/tools/skills.md`, `docs/tools/creating-skills.md`

### ClawHub Marketplace

ClawHub (`clawhub.ai`) is the public skills registry. Install via:
```bash
npx clawhub@latest install <skill-slug>
clawhub update --all
```

13,729+ community skills as of February 2026. No gatekeeping — publish any npm-style versioned bundle. Security scan by Snyk found ~7.1% of skills contained credential exposure flaws (The Register, Feb 2026).

---

## 6. Durable Memory System

### Two-Layer Architecture

**Long-term (`MEMORY.md`):**
- Curated, durable facts and preferences
- Only loaded in private/direct sessions (not group contexts)
- The agent writes here when user says "remember this"
- Survives indefinitely across all future sessions

**Short-term (`memory/YYYY-MM-DD.md`):**
- Append-only daily log
- Gateway loads today's and yesterday's files at session start
- Intended for transient context and running notes

### Pre-Compaction Memory Flush

As sessions approach token limits, the Gateway triggers a **silent agentic turn** (`NO_REPLY` mode — invisible to user) instructing the model to preserve durable memories to MEMORY.md before context compaction occurs. This is the key mechanism ensuring memory survives context window resets.

### Memory Tools (memory-core extension)

Two tools registered via `extensions/memory-core/index.ts`:

```typescript
memory_search   // semantic recall across ~400-token chunks
memory_get      // targeted file reads with graceful degradation
```

The `memory-search` tool can use a vector index (LanceDB, optional via `extensions/memory-lancedb`) for semantic queries when wording differs from stored content.

### LanceDB Extension

`extensions/memory-lancedb/` provides vector-backed semantic search over the memory files. Uses hybrid search: vector similarity + BM25 keyword relevance. Embedding provider selection: local → OpenAI → Gemini (auto-selected based on availability).

**Source:** `docs/concepts/memory.md`, `extensions/memory-core/index.ts`, `extensions/memory-lancedb/`

---

## 7. Community Marketplace

ClawHub (`clawhub.ai`) is the canonical skills marketplace:
- 13,729+ skills as of February 2026
- npm-style versioning and rollback
- `npx clawhub@latest install <skill-slug>` one-command install
- No editorial gatekeeping — community signal drives visibility
- VoltAgent/awesome-openclaw-skills catalogs 5,400+ curated skills with categories

The VISION.md explicitly states: "New skills should be published to ClawHub first (`clawhub.ai`), not added to core by default. Core skill additions should be rare and require a strong product or security reason."

The official docs point to `docs/tools/skills.md` for creating skills and the OpenClaw Skills Registry for community listing.

**Source:** VISION.md, clawhub.ai, VoltAgent/awesome-openclaw-skills

---

## 8. Running Indefinitely — Architecture Patterns

### Daemon Supervision

The Gateway registers as an OS service at install time:
```bash
openclaw onboard --install-daemon
openclaw gateway install   # registers launchd (macOS) or systemd (Linux)
```

The daemon auto-restarts on crash. Cron jobs survive restarts (persisted at `~/.openclaw/cron/`).

### Session Resume

Sessions are not lost when the process restarts. On startup:
1. `reconcilePendingSessionIdentities()` scans all ACP sessions with pending state
2. For each pending session, it restores the `RuntimeCache` entry by contacting the backend
3. Sessions resume with `--resume <sessionId>` passed to the ACP backend

This is implemented in `AcpSessionManager.reconcilePendingSessionIdentities()` in `src/acp/control-plane/manager.core.ts`.

### Idle Runtime Eviction

The `RuntimeCache` (`src/acp/control-plane/runtime-cache.ts`) tracks `lastTouchedAt` per session. `collectIdleCandidates(maxIdleMs)` returns sessions that have been idle longer than the threshold. The manager evicts these and increments `evictedRuntimeCount` for observability.

This prevents unbounded resource accumulation when many sessions are open but inactive.

### Heartbeat Wakeup

Agents can act without user prompts via the heartbeat system:
- `HEARTBEAT.md` defines a short checklist run on schedule
- Cron jobs with `kind: "every"` or `kind: "cron"` (5-field cron expression) create isolated sessions
- Exponential backoff on job failure: 30s → 1m → 5m → 15m → 60m, reset after success

### Model Failover

Multiple API keys per provider, across providers:
```
OPENAI_API_KEYS=sk-1,sk-2
ANTHROPIC_API_KEYS=sk-ant-1,sk-ant-2
```

Auth profiles rotate with cooldown + auto-expiry. The system picks the next healthy profile when one fails. This enables 24/7 operation even when individual API keys hit rate limits or expire.

**Source:** `src/acp/control-plane/runtime-cache.ts`, `src/acp/control-plane/manager.core.ts`, `docs/automation/cron-jobs`

---

## 9. Multiple Instances Running Simultaneously

### Session Actor Queue

The core primitive for concurrent execution is `SessionActorQueue` in `src/acp/control-plane/session-actor-queue.ts`:

```typescript
// Per-session serialized, cross-session concurrent
await sessionActorQueue.run(actorKey, async () => {
  // turns for same session are serialized
  // turns for different sessions run in parallel
});
```

Built on `KeyedAsyncQueue` from the plugin SDK. Each session key gets its own queue tail. Simultaneous messages to different sessions (different channels, different ACP backends) execute concurrently. Simultaneous messages to the same session are queued and executed in order.

### Multi-Agent Configuration

Multiple agents with isolated workspaces run in a single Gateway process:

```json5
{
  agents: {
    list: [
      { id: "home", default: true, workspace: "~/.openclaw/workspace-home" },
      { id: "work", workspace: "~/.openclaw/workspace-work" },
    ],
  },
  bindings: [
    { agentId: "home", match: { channel: "whatsapp", accountId: "personal" } },
    { agentId: "work", match: { channel: "slack", accountId: "work-slack" } },
  ]
}
```

Each agent has:
- Its own workspace (SOUL.md, MEMORY.md, skills/, etc.)
- Its own session store (`~/.openclaw/agents/<agentId>/sessions/`)
- Its own auth profiles
- Its own model/tool configuration

They share the Gateway process but are otherwise fully isolated.

### Subagents vs ACP Sessions

Two spawning runtimes exist:
- **subagent**: Runs inside the Gateway's Node.js process (sandboxable)
- **acp**: Spawns an external process (Claude Code, Codex, etc.) — cannot be sandboxed, runs on host

The `sessions_spawn` tool exposes both modes to the agent. An agent can dynamically spawn child agents to parallelize work.

### Inter-Agent Messaging

Disabled by default. When enabled via `tools.agentToAgent.allow`, agents can:
- `sessions_list` — discover other active agents
- `sessions_send` — send messages to another agent's session
- `sessions_history` — read another session's transcript

**Source:** `src/agents/acp-spawn.ts`, `docs/concepts/multi-agent`, `src/acp/control-plane/session-actor-queue.ts`

---

## Technical Patterns Worth Noting

### 1. Workspace as Identity + Memory + Configuration

The entire agent persona, memory, and behavioral rules live in plain markdown files in a single directory. This directory is git-backable, portable, and human-readable. No database required for the persona layer.

Pattern: `AGENTS.md + SOUL.md + USER.md + MEMORY.md + memory/YYYY-MM-DD.md` = complete agent state.

### 2. Silent NO_REPLY Turns for System Operations

The pre-compaction memory flush uses `NO_REPLY` mode — the system injects an agentic turn the user never sees, purely for internal state maintenance. This pattern enables the system to maintain invariants (like memory durability) without user awareness.

### 3. Compact XML Skill Injection

Rather than including full skill documentation in the system prompt, OpenClaw injects a compact XML index (~97 chars per skill). The model requests the full skill text only when it decides to use it. This keeps token cost predictable.

### 4. Per-Session Actor Queues

Using a keyed async queue (one queue tail per session key) elegantly solves the concurrent-but-serialized-within-session problem. No locking primitives needed — the queue provides ordering guarantees.

### 5. 3-Tier Skill Precedence

`workspace > managed > bundled` means users can override any bundled skill by placing a same-named skill in their workspace. Community-managed skills install to `~/.openclaw/skills/`. Workspace skills are the highest fidelity layer and version-controlled with the workspace.

### 6. Thread as ACP Session Surface

Binding an ACP session to a Slack/Discord thread creates a persistent coding agent conversation accessible from any messaging client. The channel thread IS the session terminal. This is a powerful UX pattern: no separate tool, no terminal needed.

---

## Anti-Patterns Observed

### 1. Skills Marketplace Security

The Register (Feb 2026) reported Snyk found ~7.1% of ClawHub skills (283 of ~4,000 scanned) contained credential exposure flaws. The community marketplace model without mandatory security review creates supply-chain risk.

**Implication for Maestro:** Any skill marketplace should require sandboxed execution or automated credential-leak scanning before install.

### 2. Workspace Files as Soft Sandbox

The agent-workspace docs state: "the workspace is the default cwd, not a hard sandbox. Tools resolve relative paths against the workspace, but absolute paths can still reach elsewhere on the host unless sandboxing is enabled." Users must explicitly opt into Docker sandboxing.

**Implication for Maestro:** Be explicit about what isolation worktrees provide vs. what they don't.

### 3. SOUL.md Token Cost at Scale

Injecting AGENTS.md + SOUL.md + USER.md + MEMORY.md + daily memory + skills XML at every session start has a fixed token cost per turn. For agents with large memory files, this can become expensive. The `bootstrapMaxChars` / `bootstrapTotalMaxChars` limits (default 20k/150k chars) are the mitigation, but they truncate rather than summarize.

### 4. Agent-to-Agent Disabled by Default

While the architecture supports multi-agent communication, it is explicitly disabled by default and requires manual allowlisting. This limits emergent multi-agent workflows but is a deliberate security tradeoff.

---

## SEO / Documentation Landscape

- Primary docs: `docs.openclaw.ai` (Mintlify-hosted)
- Architecture reference: `clawdocs.org` (community)
- Skills catalog: `clawhub.ai`, `VoltAgent/awesome-openclaw-skills` (5,400+ categorized)
- DeepWiki: `deepwiki.com/openclaw/openclaw`
- Community: Discord `discord.gg/clawd`
- zh-CN docs auto-generated via `scripts/docs-i18n` pipeline

---

*OpenClaw research complete. Primary sources: github.com/openclaw/openclaw, docs.openclaw.ai, clawhub.ai, clawdocs.org, ppaolo.substack.com/p/openclaw-system-architecture-overview.*
