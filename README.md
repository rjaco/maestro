# Maestro

**Full-Stack Autonomous Development Orchestrator for Claude Code**

Build features with `/maestro`. Build entire products with `/maestro magnum-opus`. Track progress on your kanban board. Persist knowledge in your second brain.

---

## What is Maestro?

Maestro is a Claude Code plugin that orchestrates autonomous software development across three layers: **Vision and Strategy** (product research, competitive analysis, market positioning), **Tactics and Architecture** (decomposition, dependency graphs, tech stack decisions), and **Execution** (implement, self-heal, QA review, git craft). Each layer delegates to purpose-built agents that receive exactly the context they need.

Maestro tracks token costs, learns from every session, and progressively earns your trust through demonstrated reliability. It integrates with your existing tools — Asana, Jira, Linear, GitHub Issues for project management, and Obsidian or Notion as a persistent knowledge base.

---

## Quick Start

```bash
# Install the plugin
claude plugin install maestro

# Initialize for your project
/maestro init

# Build a feature
/maestro "Add user authentication with email/password"

# Build an entire product
/maestro magnum-opus "Personal finance dashboard with budget tracking"
```

---

## Commands

| Command | Description |
|---------|-------------|
| `/maestro "task"` | Build a feature autonomously |
| `/maestro magnum-opus "vision"` | Build an entire product (Magnum Opus) |
| `/maestro init` | Initialize for this project |
| `/maestro status` | View progress, resume, pause, abort |
| `/maestro model` | View/change model assignments |
| `/maestro help [topic]` | Contextual help and FAQ |
| `/maestro doctor` | Health check and diagnostics |
| `/maestro config` | View/edit configuration |
| `/maestro board` | Kanban board view |
| `/maestro brain` | Second brain operations |
| `/maestro history` | Past sessions and cost analysis |
| `/maestro plan "task"` | Deep planning with codebase exploration |
| `/maestro notify` | Push notifications (Slack, Discord, Telegram) |
| `/maestro viz` | Visual dashboards and Mermaid diagrams |
| `/maestro demo` | Interactive demo — learn how Maestro works |
| `/maestro quick-start` | Pick from pre-built task templates |
| `/maestro spec "desc"` | Create structured feature specifications |
| `/maestro deps` | Visualize story dependency graph |
| `/maestro cost-estimate` | Estimate token cost before building |
| `/maestro rollback` | Revert changes with git + kanban sync |

---

## Three-Layer Architecture

```
User Request
    |
    v
[Classifier] --> routes to the right layer
    |
    +---> Layer 1: Vision & Strategy
    |       research, strategy, opus-loop
    |
    +---> Layer 2: Tactics & Architecture
    |       decompose, architecture, forecast
    |
    +---> Layer 3: Execution
            dev-loop, git-craft, ship, preview
```

### Execution: 7-Phase Dev Loop

For each story in dependency order:

```
VALIDATE > DELEGATE > IMPLEMENT > SELF-HEAL > QA > GIT > CHECKPOINT
```

1. **Validate** — Check prerequisites and dependencies
2. **Delegate** — Build right-sized context, select model
3. **Implement** — Dispatch implementer agent (TDD)
4. **Self-Heal** — Run checks, auto-fix failures (up to 3x)
5. **QA Review** — Dispatch QA reviewer (read-only, separate agent)
6. **Git Craft** — Create documentation-quality commit
7. **Checkpoint** — User review (mode-dependent)

### Execution Modes

| Mode | Behavior |
|------|----------|
| `--yolo` | Auto-approve everything, maximum speed |
| `--checkpoint` | Pause after each story for review (default) |
| `--careful` | Pause after each phase for granular control |

---

## Magnum Opus

Build entire products with `/maestro magnum-opus "vision"`.

1. **Deep Interview** — 10-dimension adaptive vision interview
2. **Research Sprint** — 8 parallel research agents (competitors, tech, architecture)
3. **Roadmap** — Milestone-driven plan with cost estimates
4. **Build Loop** — Decompose, implement, evaluate, auto-fix per milestone
5. **Live Chat** — Talk to Maestro while it builds

---

## Integrations

### Kanban (Project Management)

Sync stories with your project management tool. Stories appear as cards, status updates flow bidirectionally.

```
/maestro config set integrations.kanban.provider github
/maestro board
```

| Provider | Setup |
|----------|-------|
| GitHub Issues | `gh` CLI (no extra setup) |
| Asana | Asana MCP Server |
| Jira | Atlassian MCP Server |
| Linear | Linear MCP Server |

### Second Brain (Knowledge Base)

Persist decisions, learnings, and session summaries across sessions.

```
/maestro brain connect
/maestro brain search "authentication"
/maestro brain tldr
```

| Provider | Setup |
|----------|-------|
| Obsidian | Enable CLI in Obsidian Settings |
| Notion | Notion MCP Server |

### Diagnostics

```
/maestro doctor
```

Checks: core files, config, trust metrics, git status, hooks, MCP servers, integrations.

---

## Progressive Trust

Maestro tracks reliability and adapts behavior:

| Level | Requirement |
|-------|-------------|
| Novice | < 5 stories |
| Apprentice | 5-15 stories, > 60% QA first-pass |
| Journeyman | 15-30 stories, > 75% QA rate |
| Expert | 30+ stories, > 85% QA rate |

Higher trust unlocks more autonomy (yolo mode becomes default for Expert).

---

## Cost Tracking

Maestro estimates costs before starting and tracks actual spend per story.

```
/maestro history cost
/maestro model
```

Model costs (per million tokens):
- Haiku: $0.80 / $4.00
- Sonnet: $3.00 / $15.00
- Opus: $15.00 / $75.00

---

## Session Memory

Dual-sector memory persists across sessions:
- **Semantic**: long-term facts, preferences, architecture decisions
- **Episodic**: session context with salience decay (auto-prunes after ~10 sessions)

Memory is injected into agent context for continuity.

---

## Agents

| Agent | Model | Role |
|-------|-------|------|
| Implementer | Sonnet | TDD story implementation |
| QA Reviewer | Opus | Skeptical code review (read-only) |
| Researcher | Sonnet | Competitive analysis, web research |
| Strategist | Opus | Marketing, growth, positioning |
| Fixer | Sonnet | Targeted error fixes (self-heal) |
| Proactive | Haiku | Background monitoring, health checks |

---

## File Structure

```
.maestro/
  dna.md              Project DNA (tech stack, patterns)
  config.yaml         Configuration
  trust.yaml          Trust metrics
  state.md            Persistent project state
  state.local.md      Session state (gitignored)
  stories/            Story spec files
  logs/               Session logs
  research/           Research output
  memory/
    semantic.md       Long-term facts
    episodic.md       Session context (decays)
```

---

## License

MIT
