# Maestro

**Full-Stack Autonomous Development Orchestrator for Claude Code**

Build features with `/maestro`. Build entire products with `/maestro opus`.

---

## What is Maestro?

Maestro is a Claude Code plugin that orchestrates autonomous software development across three layers: **Vision and Strategy** (product research, competitive analysis, market positioning), **Tactics and Architecture** (decomposition, dependency graphs, tech stack decisions), and **Execution** (implement, self-heal, QA review, git craft). Each layer delegates to purpose-built agents that receive exactly the context they need — no more, no less.

Maestro tracks token costs, learns from every session, and progressively earns your trust through demonstrated reliability. When it hits a wall, it pauses and asks — it does not guess.

**Key differentiator:** The first Claude Code plugin that handles Vision, Strategy, Architecture, AND Execution — then learns from every session.

---

## Quick Start

```bash
claude plugin install maestro

# Initialize for your project (auto-discovers tech stack, patterns, architecture)
/maestro init

# Build a feature
/maestro "Add user authentication with email/password"

# Build an entire product
/maestro opus "Personal finance dashboard with budget tracking"
```

---

## Commands

| Command | Description |
|---------|-------------|
| `/maestro "task"` | Build a feature — auto-decomposes, implements, QA reviews, commits |
| `/maestro opus "vision"` | Magnum Opus — build entire products autonomously with live conversation |
| `/maestro init` | Initialize Maestro for your project (auto-discovers tech stack) |
| `/maestro status` | View progress, resume, pause, or abort the current run |

When you run `/maestro "task"` without a subcommand, Maestro auto-classifies the request and routes it to the right layer. A one-liner fix goes straight to execution. A vague product idea triggers the full interview-research-roadmap pipeline.

---

## Magnum Opus (`/maestro opus`)

The autonomous product builder. This is what a $200/hour product consultant does — but for a few dollars in tokens.

### How It Works

**1. Deep Interview** — Maestro asks as many questions as needed to understand your project across 10 dimensions: core purpose, target audience, scope, competitive landscape, business model, technical context, design and UX, integrations, success criteria, and constraints. The interview adapts: detailed answers get fewer follow-ups; vague answers get deeper probing; "I don't know" gets concrete options to choose from.

**2. Mega Research Sprint** — 8 parallel research agents fan out to investigate competitors (with screenshots), evaluate tech stacks, design architecture, plan SEO and content strategy, analyze monetization options, map integrations, build user personas, and draft a launch strategy. Output: a synthesized research brief that informs every decision downstream.

**3. Roadmap Generation** — From the vision and research, Maestro generates a milestone-driven roadmap with dependency graphs, acceptance criteria, and token budget estimates per milestone.

**4. Autonomous Execution Loop** — For each milestone: decompose into stories, run the dev loop (implement, self-heal, QA, commit), evaluate against acceptance criteria, run an Opus quality gate on the combined diff, checkpoint, and continue. Between milestones, Maestro re-reads the vision (North Star anchoring) to prevent goal drift.

**5. Live Conversation Channel** — Talk to Maestro while it builds. Add context. Redirect priorities. Ask questions. Pivot the entire approach. Pause the workers or let them keep going while you steer.

### Sub-Modes

```
/maestro opus "Build a SaaS dashboard"
  [--full-auto]           # No stops between milestones
  [--milestone-pause]     # Pause between milestones (default)
  [--budget $N]           # Token budget cap — pauses when reached
  [--hours N]             # Time cap — pauses after N hours
  [--until-pause]         # Runs until you say /maestro pause
  [--skip-research]       # Skip research (use existing .maestro/research/)
  [--start-from M3]       # Resume from a specific milestone
```

---

## Three-Layer Architecture

```
                    /maestro "task"
                         |
                   [Auto-Classifier]
                         |
          +--------------+--------------+
          |              |              |
          v              v              v
  +---------------+ +----------------+ +----------------+
  |   LAYER 1     | |    LAYER 2     | |    LAYER 3     |
  |   Vision &    | |   Tactics &    | |   Execution    |
  |   Strategy    | |  Architecture  | |                |
  |               | |                | |                |
  | - Research    | | - Decompose    | | - Dev Loop     |
  | - Competitors | | - Dependencies | | - Self-Heal    |
  | - Market      | | - Forecast     | | - QA Review    |
  | - Strategy    | | - Skill Create | | - Git Craft    |
  | - Vision      | | - Architecture | | - Preview      |
  |               | |                | | - Ship         |
  +-------+-------+ +-------+--------+ +-------+--------+
          |                  |                  |
          v                  v                  v
    .maestro/           .maestro/           Code, tests,
    vision.md           stories/            commits, PRs
    research/           architecture.md
```

Layer 1 produces the **why**. Layer 2 produces the **what**. Layer 3 produces the **how**.

---

## The Dev Loop (7 Phases)

Every feature Maestro builds goes through the same disciplined loop:

| Phase | What Happens |
|-------|-------------|
| **Validate** | Confirm the story is well-defined and the codebase is in a clean state |
| **Delegate** | Select the right agent and inject only the context it needs |
| **Implement** | Write code, following project conventions discovered during init |
| **Self-Heal** | If tests or type checks fail, auto-fix up to 3 times before escalating |
| **QA Review** | Independent agent reviews the diff for bugs, style violations, security |
| **Git Craft** | Atomic, well-messaged commits — not one giant "WIP" commit |
| **Checkpoint** | Update state, token ledger, and learning memory |

If QA rejects 5 times or self-heal fails 3 times, Maestro pauses and asks for human guidance. It never pushes broken code hoping you will not notice.

---

## Context Engine

Each agent gets exactly the right context — not too much, not too little. This is how Maestro achieves 70-85% token reduction compared to naive approaches that dump the entire codebase into every prompt.

| Tier | Agent Type | Context Budget | What Gets Injected |
|------|-----------|---------------|-------------------|
| T0 | Orchestrator | 15-25K tokens | Project state, roadmap, active milestone |
| T1 | Strategic | 10-15K tokens | Vision, research brief, architecture |
| T2 | Architect | 8-12K tokens | Relevant source files, type definitions, patterns |
| T3 | Implementer | 4-8K tokens | Story spec, target files, test expectations |
| T4 | Fix Agent | 1-3K tokens | Error message, failing file, fix instructions |

Context is loaded atomically and progressively — skills and project knowledge are injected on-demand, not all at once.

---

## Self-Learning

Maestro gets better at building YOUR project over time.

**Friction Detection** — Six signal types are captured from every session:

- `COMMAND_FAILURE` — a tool call or shell command failed
- `USER_CORRECTION` — you told Maestro it was wrong
- `SKILL_SUPPLEMENT` — a missing capability was needed
- `VERSION_ISSUE` — dependency or API version mismatch
- `REPETITION` — the same fix was applied more than once
- `TONE_ESCALATION` — frustration signals in user messages

**Improvement Proposals** — Detected friction is classified, and Maestro generates improvement proposals with confidence scores (0.60-0.95). High-confidence proposals are auto-applied. Lower-confidence ones are presented for approval.

**Meta-Rules** — Rules that teach Maestro how to write better rules. This is the layer that makes self-improvement compound rather than plateau.

**Progressive Trust** — Four trust levels based on demonstrated reliability:

| Level | Autonomy | Earned By |
|-------|----------|-----------|
| Novice | Asks before every major action | Default for new projects |
| Apprentice | Executes stories autonomously, pauses at milestones | 5+ successful stories |
| Journeyman | Full milestone autonomy with quality gates | 20+ stories, low rejection rate |
| Expert | Full-auto with budget-only guardrails | Sustained high quality across sessions |

**Persistent Memory** — Agents maintain project-specific memory across sessions. The implementer that built your auth system yesterday remembers your patterns today.

---

## Cost Tracking

Token cost anxiety is real. Maestro makes it transparent.

**Before execution:**
```
Forecast: "Add authentication" — 4 stories, ~$3.20
  Story 1: DB schema + migrations    Sonnet  ~$0.60
  Story 2: Auth API routes           Sonnet  ~$0.80
  Story 3: Login/signup UI           Sonnet  ~$0.95
  Story 4: Session middleware         Sonnet  ~$0.85
Proceed? [Y/n]
```

**After execution:**
```
Token Ledger — "Add authentication"
  Actual: $2.81 (forecast: $3.20, saved 12%)
  Breakdown: Implement $1.90 | QA $0.52 | Self-heal $0.22 | Git $0.17
```

Disable with `--no-cost-tracking` or `--no-forecast` if you prefer not to see it.

---

## Execution Modes

| Mode | Flag | Behavior | Best For |
|------|------|----------|----------|
| **Yolo** | `--yolo` | Full auto. No confirmations. | High-trust projects, overnight runs |
| **Checkpoint** | (default) | Pauses after each story for review | Most development work |
| **Careful** | `--careful` | Pauses after every phase within each story | Learning Maestro, critical systems |

---

## Project DNA (`/maestro init`)

When you run `/maestro init`, Maestro scans your project and builds a comprehensive profile:

- **Tech stack** — frameworks, languages, package managers, databases
- **Patterns** — component conventions, file organization, naming standards
- **Architecture** — data flow, API structure, rendering strategy
- **Testing** — framework, coverage expectations, test locations
- **Style** — linting rules, formatting preferences, commit message conventions

This profile is stored in `.maestro/project-dna.md` and injected into every agent so they write code that looks like YOUR code, not generic boilerplate.

---

## Compatibility

Maestro is designed to complement, not compete with, the Claude Code ecosystem.

| Plugin | Relationship | How Maestro Uses It |
|--------|-------------|-------------------|
| **superpowers** | Extends | Uses subagent patterns and worktree conventions. Maestro adds strategy, research, and token tracking layers on top |
| **ralph-loop** | Coexists | Different state files. Both can be installed. Use Ralph for non-Maestro loops |
| **skill-creator** | Uses | Skill Factory delegates to skill-creator for generating project specialists |
| **feature-dev** | Dispatches | Uses code-explorer for architecture phase, code-architect for design |
| **pr-review-toolkit** | Dispatches | Uses review-pr in ship phase, code-reviewer in QA |

Maestro follows the Agent Skills open standard and the superpowers implementer protocol. It requires Claude Code CLI or Claude Code Desktop.

---

## Development Phases

| Phase | Status | What It Includes |
|-------|--------|-----------------|
| **Phase 1: Foundation** | In development | Core dev loop, init, decompose, QA, git craft, token ledger, hooks |
| **Phase 2: Strategy Layer** | Planned | Research agents, competitive analysis, architecture design, skill factory |
| **Phase 3: Magnum Opus** | Planned | Autonomous product builder, deep interview, mega research, milestone loop |
| **Phase 4: Self-Learning** | Planned | Friction detection, improvement proposals, meta-rules, progressive trust |
| **Phase 5: Agent Teams** | Planned | Parallel agents with shared task lists, inter-agent messaging, worktree isolation |
| **Phase 6: Watch Mode** | Planned | Continuous monitoring, scheduled tasks, event-driven story creation |

---

## File Structure

Maestro stores all state and artifacts in a `.maestro/` directory at your project root:

```
.maestro/
  state.md              # Current execution state (active stories, progress)
  project-dna.md        # Auto-discovered project profile
  vision.md             # Product vision (from /maestro opus interview)
  roadmap.md            # Milestone roadmap with dependency graph
  architecture.md       # Architecture decisions and diagrams
  token-ledger.md       # Cumulative token spend tracking
  research/             # Research sprint outputs (competitors, SEO, etc.)
  stories/              # Story specs and completion status
  logs/                 # Execution logs per milestone
  learning/             # Friction signals and improvement proposals
```

---

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Check the development phases above to see what is actively being built. Phase 1 contributions are the highest priority. If you want to tackle something in a later phase, open an issue first to discuss the approach.

---

## License

[MIT](LICENSE)

---

## Acknowledgments

Maestro builds on ideas, patterns, and lessons from across the Claude Code community:

- **[superpowers](https://github.com/nicobailon/superpowers)** — subagent orchestration patterns and worktree conventions
- **[ralph-loop](https://github.com/nicobailon/ralph-loop)** — stop-hook continuation loop that keeps agents running
- **[claude-coach](https://github.com/lennartpollvogt/claude-coach)** — friction detection and 6-signal classification
- **[claude-swarm](https://github.com/claudeswarm/claude-swarm)** — dependency graph decomposition and Opus quality gates
- **[self-evolving-agent](https://github.com/mettamatt/self-evolving-agent)** — North Star anchoring, atomic loading, and PDCA loops
- **[claude-meta](https://github.com/hiromichinomata/claude-meta)** — meta-rules that teach agents how to improve
- **[Aider](https://github.com/paul-gauthier/aider)** — tree-sitter repo mapping and relevance-ranked context

And the broader Claude Code community, whose plugins, experiments, and discussions shaped every design decision in Maestro.
