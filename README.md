<p align="center">
  <img src="maestro.png" alt="Maestro Logo" width="200" />
</p>

<h1 align="center">Maestro</h1>

<p align="center">
  <b>The ultimate autonomous development tool for Claude Code — plugin + companion daemon with voice, personality, and parallel execution.</b>
</p>

![Skills](https://img.shields.io/badge/skills-138-blue)
![Commands](https://img.shields.io/badge/commands-43-green)
![Hooks](https://img.shields.io/badge/hooks-12-orange)
![Tests](https://img.shields.io/badge/tests-85%20passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## What is Maestro?

Maestro operates in two complementary modes. In **Plugin Mode**, it runs inside Claude Code and enhances every aspect of your development workflow through 138 skills — from autonomous feature building and multi-agent orchestration to voice interfaces, SPARC methodology, production validation, and a persistent second brain. Install once, get a fully autonomous development orchestrator that builds features, runs QA, crafts commits, tracks costs, and learns from every session.

In **Companion Mode**, Maestro runs above Claude Code as a persistent background daemon. It survives terminal restarts, listens for commands from your phone via Telegram, speaks back to you via voice synthesis, spawns parallel Claude Code workers for concurrent development, and manages your entire development lifecycle from anywhere in the world. Both modes share the same `.maestro/` state, SOUL personality engine, and instance registry — so switching between them is seamless.

---

## Quick Start

```bash
# As a Claude Code plugin
claude plugin install maestro

# Initialize for your project
/maestro init

# Build a feature
/maestro "Add user authentication with email/password"

# Build an entire product
/maestro opus "Personal finance dashboard with budget tracking"

# As a companion (talk to Maestro from your phone)
cd companion && npm run setup
```

---

## Key Features

### 1. Magnum Opus — Build Entire Products Autonomously

`/maestro opus` runs a full product build from a single vision statement. It conducts a 10-dimension adaptive interview, launches 8 parallel research agents (competitors, tech stack, architecture, market), produces a milestone-driven roadmap with cost estimates, and executes a full build loop with auto-fix cycles and live chat.

```bash
/maestro opus "B2B SaaS analytics dashboard with Stripe billing"
```

### 2. Plan Intelligence — Smarter Planning, Three Modes

`/maestro plan` goes far beyond native planning. Three modes adapt to your situation:

| Mode | When to Use |
|------|-------------|
| `quick` | Rapid decomposition, low token cost |
| `standard` | Full dependency graph with estimates |
| `deep` | Architecture-first with codebase exploration |

```bash
/maestro plan "Migrate from REST to GraphQL" --mode deep
```

### 3. Multi-Agent Orchestration — Parallel by Default

Maestro dispatches specialized subagents in parallel using git worktrees for true isolation. Each story runs in its own worktree, so multiple features can build concurrently without conflicts. A consensus architecture with quality gates ensures every output meets your standards before merge.

```
Story 1 → worktree-a6c0ef6c → implement → QA → merge
Story 2 → worktree-b7d1fg7d → implement → QA → merge  (concurrent)
Story 3 → worktree-c8e2gh8e → implement → QA → merge  (concurrent)
```

### 4. Communication Channels — Remote Control from Anywhere

Connect Maestro to your communication stack:

- **Telegram Bot**: Send commands, receive progress updates from your phone
- **Slack / Discord Webhooks**: Team-wide build notifications
- **Email**: Milestone completion summaries
- **Voice**: Groq Whisper for input, ElevenLabs for spoken replies

```bash
/maestro notify setup telegram
/maestro notify setup slack --webhook https://hooks.slack.com/...
```

### 5. Voice Mode — Talk to Maestro

Maestro can listen and speak. Using Groq Whisper for transcription and ElevenLabs for voice synthesis, you can give commands verbally and receive spoken status updates. Ideal for hands-free development sessions.

```bash
/maestro voice start
# "Hey Maestro, what's the status of the auth feature?"
# Maestro replies in your chosen voice profile.
```

### 6. SOUL Personality — Persistent Identity

Maestro has a persistent identity engine with four communication profiles. It remembers your preferences, adapts its style, and maintains continuity across sessions.

| Profile | Description |
|---------|-------------|
| `casual` | Friendly, uses contractions, celebrates wins |
| `formal` | Professional, precise, structured output |
| `mentor` | Teaches as it builds, explains decisions |
| `peer` | Collaborative, thinks out loud, asks questions |

```bash
/maestro config set soul.profile mentor
```

### 7. Smart Daemon — Runs 24/7

The companion daemon starts on boot, auto-restarts on failure, detects stalls, and manages a pool of parallel Claude Code workers. It maintains an instance registry so you always know what's running where.

```bash
# Start the daemon
./scripts/opus-daemon.sh start

# Monitor all workers
/maestro observe
```

### 8. Production Validator — No Mocks in Production

Maestro's production validator runs before every ship operation and blocks any code containing:
- Mock/stub implementations masquerading as real code
- Debug flags left enabled
- Hardcoded secrets or localhost URLs
- TODOs marked as critical path

```bash
# Validates automatically before /maestro ship
/maestro ship --validate-strict
```

### 9. Scout / Explorer — Recon Before Modification

Before modifying unfamiliar territory, dispatch a read-only scout agent that maps the codebase, identifies patterns, surfaces risks, and produces a navigation guide — all without touching a single file.

```bash
/maestro "Refactor the payment module" --scout-first
```

### 10. SPARC Methodology — Structured Development Lifecycle

Every build follows the 5-phase SPARC lifecycle: Specification, Pseudocode, Architecture, Refinement, Completion. Each phase gates the next, ensuring nothing ships without passing all prior quality checks.

```
SPECIFY → PSEUDOCODE → ARCHITECT → REFINE → COMPLETE
```

---

## Architecture

```
Plugin Mode:  Claude Code → /maestro → 138 skills + 12 hooks (inside Claude Code)
Companion:    Phone/Telegram → daemon → spawns Claude Code workers
              Voice input → Groq Whisper → Maestro → ElevenLabs → Voice output

Both share:   .maestro/ state, SOUL personality, instance registry, token ledger
```

### 7-Phase Dev Loop

Every story runs through:

```
VALIDATE → DELEGATE → IMPLEMENT → SELF-HEAL → QA → GIT-CRAFT → CHECKPOINT
```

1. **Validate** — Check dependencies and prerequisites
2. **Delegate** — Build right-sized context, select model
3. **Implement** — TDD-driven story implementation in isolated worktree
4. **Self-Heal** — Auto-fix linting/test failures (up to 3 rounds)
5. **QA Review** — Skeptical QA agent reviews code (read-only, separate context)
6. **Git Craft** — Documentation-quality commit with full context
7. **Checkpoint** — Mode-dependent user review gate

### Execution Modes

| Mode | Behavior |
|------|----------|
| `--yolo` | Auto-approve everything, maximum speed |
| `--checkpoint` | Pause after each story for review (default) |
| `--careful` | Pause after each phase for granular control |

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `/maestro "task"` | Build a feature autonomously |
| `/maestro opus "vision"` | Build an entire product (Magnum Opus) |
| `/maestro init` | Initialize for this project |
| `/maestro status` | View progress, resume, pause, abort |
| `/maestro plan "task"` | Deep planning with codebase exploration |
| `/maestro model` | View/change model assignments |
| `/maestro help [topic]` | Contextual help and FAQ |
| `/maestro doctor` | Health check and diagnostics |
| `/maestro config` | View/edit configuration |
| `/maestro board` | Kanban board view with external sync |
| `/maestro brain` | Second brain — persist decisions and knowledge |
| `/maestro rollback` | Revert story/commit with kanban sync |
| `/maestro history` | Past sessions and cost analysis |
| `/maestro notify` | Push notifications (Slack, Discord, Telegram) |
| `/maestro viz` | Visual dashboards and Mermaid diagrams |
| `/maestro demo` | Interactive demo — learn how Maestro works |
| `/maestro quick-start` | Pre-built task templates |
| `/maestro cost-estimate` | Forecast cost before building |
| `/maestro deps` | Dependency graph for stories |
| `/maestro observe` | Real-time agent observability dashboard |
| `/maestro watch` | Watch mode — auto-rebuild on file change |
| `/maestro sync-ide` | Sync Maestro state to IDE extensions |
| `/maestro voice start` | Enable voice input/output |
| `/maestro ship` | Ship with production validation |
| `/maestro spec` | Generate spec-first story from description |

---

## Comparison

| Feature | Maestro | OpenClaw | Ruflo | Native CC |
|---------|---------|----------|-------|-----------|
| Autonomous feature build | Yes | Partial | No | No |
| Full product build (Opus) | Yes | No | No | No |
| Parallel multi-agent | Yes | No | No | No |
| Voice interface | Yes | No | No | No |
| Telegram remote control | Yes | No | No | No |
| Persistent daemon | Yes | No | No | No |
| Production validator | Yes | No | No | No |
| SOUL personality | Yes | No | No | No |
| SPARC methodology | Yes | No | No | No |
| Kanban sync | Yes | No | Partial | No |
| Second brain | Yes | No | No | No |
| Progressive trust | Yes | No | No | No |
| Cost forecasting | Yes | No | No | No |
| Self-healing (auto-fix) | Yes | No | No | No |
| QA agent (separate) | Yes | No | No | No |
| Scout/recon agent | Yes | No | No | No |
| Token ledger | Yes | No | No | No |
| 138 skills | Yes | No | No | No |

---

## Installation

### Plugin Mode (Recommended)

```bash
# Install from Claude Code plugin marketplace
claude plugin install maestro

# Or install locally
git clone https://github.com/your-org/maestro
claude plugin install ./maestro

# Initialize for your project
/maestro init
```

### Companion Mode (Full Power)

```bash
git clone https://github.com/your-org/maestro
cd maestro/companion

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env: add TELEGRAM_BOT_TOKEN, ELEVENLABS_API_KEY, GROQ_API_KEY

# Setup and start daemon
npm run setup
./scripts/opus-daemon.sh start

# Check daemon status
./scripts/statusline.sh
```

### Configuration

```bash
# Set your preferred model
/maestro model set sonnet

# Configure Telegram bot
/maestro notify setup telegram

# Set personality
/maestro config set soul.profile casual

# Connect kanban
/maestro config set integrations.kanban.provider github

# View all config
/maestro config
```

---

## File Structure

```
.maestro/
  dna.md              Project DNA (tech stack, patterns, conventions)
  config.yaml         Configuration (models, integrations, soul)
  trust.yaml          Progressive trust metrics
  state.md            Persistent project state
  state.local.md      Session state (gitignored)
  stories/            Story spec files (.md per story)
  logs/               Session logs
  research/           Research agent output
  memory/
    semantic.md       Long-term facts and decisions
    episodic.md       Session context (auto-decays)
```

---

## Integrations

### Project Management
| Provider | Setup |
|----------|-------|
| GitHub Issues | `gh` CLI (no extra setup needed) |
| Asana | Asana MCP Server |
| Jira | Atlassian MCP Server |
| Linear | Linear MCP Server |

### Knowledge Base
| Provider | Setup |
|----------|-------|
| Obsidian | Enable Local REST API in Obsidian settings |
| Notion | Notion MCP Server |

### Communication
| Channel | Setup |
|---------|-------|
| Telegram | `TELEGRAM_BOT_TOKEN` in `.env` |
| Slack | Webhook URL via `/maestro notify setup slack` |
| Discord | Webhook URL via `/maestro notify setup discord` |
| Voice | `GROQ_API_KEY` + `ELEVENLABS_API_KEY` in `.env` |

---

## Progressive Trust

Maestro tracks reliability and unlocks more autonomy over time:

| Level | Requirement | Unlocks |
|-------|-------------|---------|
| Novice | < 5 stories | Checkpoint mode required |
| Apprentice | 5-15 stories, > 60% QA first-pass | Yolo available |
| Journeyman | 15-30 stories, > 75% QA rate | Extended parallel workers |
| Expert | 30+ stories, > 85% QA rate | Yolo as default |

---

## Contributing

Maestro is built as a collection of markdown skills and commands — no build step required. To add a new skill:

1. Create `skills/your-skill/SKILL.md` with your skill implementation
2. Mirror to `plugins/maestro/skills/your-skill/SKILL.md`
3. Reference from the relevant command if needed

To add a new command:

1. Create `commands/your-command.md` with frontmatter and implementation
2. Mirror to `plugins/maestro/commands/your-command.md`
3. Add the route to `commands/maestro.md` routing table

Run `/maestro doctor` to validate your changes.

---

## License

MIT
