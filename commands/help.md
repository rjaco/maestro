---
name: help
description: "Contextual help and topic guide — browse commands, modes, cost, trust, integrations, and architecture"
argument-hint: "[topic]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Maestro Help

## Usage

```
/maestro help [topic]
```

## Topics

| Topic | Description |
|-------|-------------|
| `commands` | All commands with examples |
| `modes` | yolo vs checkpoint vs careful |
| `opus` | Magnum Opus explained |
| `cost` | Token tracking and budgets |
| `trust` | Progressive trust levels |
| `integrations` | Asana, Jira, Obsidian, Notion |
| `troubleshooting` | Common issues and fixes |
| `architecture` | How Maestro works internally |

## Examples

```
/maestro help
/maestro help modes
/maestro help opus
/maestro help integrations
/maestro help troubleshooting
```

## See Also

- `/maestro doctor` — Installation health check
- `/maestro init` — Set up Maestro for this project

Provides contextual help using an embedded knowledge base. When called with no arguments, shows the topic list. When called with a topic, provides detailed guidance.

## No Arguments — Show Topic List

```
+---------------------------------------------+
| Maestro Help                                |
+---------------------------------------------+

  Quick Reference:
    /maestro "desc"       Build a feature
    /maestro plan "desc"  Plan before building
    /maestro opus "desc"  Build an entire product
    /maestro status       Check progress
    /maestro board        View kanban board
    /maestro doctor       Health check
    /maestro help [topic] Detailed help

  Topics:
    /maestro help commands       All commands with examples
    /maestro help modes          yolo vs checkpoint vs careful
    /maestro help opus           Magnum Opus explained
    /maestro help cost           Token tracking and budgets
    /maestro help trust          Progressive trust levels
    /maestro help integrations   Asana, Jira, Obsidian, Notion
    /maestro help troubleshooting Common issues and fixes
    /maestro help architecture   How Maestro works internally

  Quick start:
    /maestro init                Set up Maestro for this project
    /maestro "your feature"      Build a feature
    /maestro doctor              Check installation health
```

## Knowledge Base

### Topic: commands

```
+---------------------------------------------+
| Topic: Commands                             |
+---------------------------------------------+

  Commands:
    /maestro "task"         Build a feature autonomously
    /maestro opus "vision"  Build an entire product (Magnum Opus)
    /maestro init           Initialize for this project
    /maestro status         View progress, resume, pause, abort
    /maestro model          View/change model assignments
    /maestro help [topic]   This help system
    /maestro doctor         Health check and diagnostics
    /maestro config         View/edit configuration
    /maestro board          Kanban board view (if configured)
    /maestro brain          Second brain operations (if configured)
    /maestro history        Past sessions and cost analysis

  Examples:
    /maestro "Add dark mode toggle"
    /maestro "Build pricing page" --yolo
    /maestro "Refactor API layer" --careful --model opus
    /maestro opus "SaaS analytics dashboard"
```

### Topic: modes

```
+---------------------------------------------+
| Topic: Execution Modes                      |
+---------------------------------------------+

  Maestro has 3 execution modes:

  YOLO (autonomous)
    Stories execute without pausing.
    Best for: trusted codebase, simple features.
    Use: /maestro "feature" --yolo

  CHECKPOINT (default)
    Pause between stories for your review.
    Best for: most development work.
    Use: /maestro "feature"

  CAREFUL (maximum oversight)
    Pause at every phase within every story.
    Best for: critical systems, learning Maestro.
    Use: /maestro "feature" --careful
```

### Topic: opus

```
+---------------------------------------------+
| Topic: Magnum Opus                          |
+---------------------------------------------+

  Build entire products end-to-end.

  /maestro opus "Build a personal finance dashboard"

  How it works:
    1. Deep Interview — Maestro asks questions across 10
       dimensions to understand your vision fully.
    2. Research Sprint — 8 parallel research agents investigate
       competitors, tech stacks, architecture patterns.
    3. Roadmap — Generates milestones with dependency graphs,
       acceptance criteria, and cost estimates.
    4. Build Loop — For each milestone: decompose into stories,
       execute dev-loop, evaluate, auto-fix, checkpoint.
    5. Live Chat — Talk to Maestro while it builds. Redirect
       priorities, add context, ask questions.

  Modes:
    --full-auto          No stops between milestones
    --milestone-pause    Pause between milestones (default)
    --budget $N          Token budget cap
    --hours N            Time cap
    --skip-research      Use existing research
    --start-from M3      Resume from milestone 3
```

### Topic: cost

```
+---------------------------------------------+
| Topic: Token Cost Tracking                  |
+---------------------------------------------+

  Maestro tracks token usage per story, per feature, and
  across your entire project history.

  How it works:
    - Each agent dispatch logs tokens used
    - Stories sum up their agent dispatches
    - Features sum up their stories
    - The token ledger (.maestro/token-ledger.md) keeps history

  Forecast:
    Before starting, Maestro estimates cost based on:
    - Number of stories (from decomposition)
    - Story complexity (simple/medium/complex)
    - Model mix (Sonnet vs Opus percentage)
    - Historical averages from your project

  Model costs (per million tokens):
    Haiku    $0.80 input / $4.00 output
    Sonnet   $3.00 input / $15.00 output
    Opus     $15.00 input / $75.00 output

  Commands:
    /maestro model              See current model assignments
    /maestro model set X Y      Change a model assignment
    /maestro history cost       See total spend across sessions
    /maestro "task" --no-forecast  Skip the cost estimate
```

### Topic: trust

```
+---------------------------------------------+
| Topic: Progressive Trust                    |
+---------------------------------------------+

  Maestro tracks reliability on each project and adjusts
  its behavior accordingly.

  Levels:
    Novice       < 5 stories completed
    Apprentice   5-15 stories, > 60% QA first-pass rate
    Journeyman   15-30 stories, > 75% QA rate
    Expert       30+ stories, > 85% QA rate

  What trust affects:
    - Default mode suggestion (Expert projects suggest yolo)
    - Model routing (high-trust projects use more Sonnet)
    - Checkpoint frequency (Expert can skip some checkpoints)

  Trust is stored in .maestro/trust.yaml and updated after
  every story completion.
```

### Topic: integrations

```
+---------------------------------------------+
| Topic: External Integrations                |
+---------------------------------------------+

  Maestro can connect to project management and knowledge
  base tools via MCP servers.

  Project Management (Kanban):
    Asana     Install Asana MCP server, then:
              /maestro config set integrations.kanban.provider asana

    Jira      Install Atlassian MCP server, then:
              /maestro config set integrations.kanban.provider jira

    Linear    Install Linear MCP server, then:
              /maestro config set integrations.kanban.provider linear

    GitHub    Uses gh CLI (no extra setup if gh is installed):
              /maestro config set integrations.kanban.provider github

  Knowledge Base (Second Brain):
    Obsidian  Enable Obsidian CLI (Settings > General > CLI), then:
              /maestro brain connect

    Notion    Install Notion MCP server, then:
              /maestro brain connect

  Check what is available:
    /maestro doctor             Shows detected integrations
```

### Topic: troubleshooting

```
+---------------------------------------------+
| Topic: Common Issues                        |
+---------------------------------------------+

  "Maestro is not initialized"
    Run: /maestro init

  "Active session detected" but nothing is running
    Run: /maestro status abort

  "MCP server not detected"
    Check your MCP server configuration in Claude Code settings.
    MCP servers must be running for Maestro to detect them.

  Stories stuck in IN_PROGRESS
    Run: /maestro status
    Then choose "Resume" or "Abort" from the menu

  Config file is corrupted
    Run: /maestro config reset

  Kanban sync failing
    Run: /maestro doctor
    Check the integration status section for connectivity.

  Trust level seems wrong
    Check .maestro/trust.yaml manually.
    Trust is calculated from QA first-pass rate across all
    completed stories on this project.

  Need more help?
    Report issues: github.com/anthropics/claude-code/issues
```

### Topic: architecture

```
+---------------------------------------------+
| Topic: How Maestro Works                    |
+---------------------------------------------+

  Three-Layer Orchestration:

    Layer 1 — Vision & Strategy
      Research competitors, analyze markets, define strategy.
      Skills: research, strategy
      Agents: researcher, strategist

    Layer 2 — Tactics & Architecture
      Decompose features, design architecture, estimate costs.
      Skills: decompose, architecture, forecast
      Agents: (orchestrator handles this directly)

    Layer 3 — Execution
      Implement stories, run QA, craft commits, ship.
      Skills: dev-loop, git-craft, ship, preview
      Agents: implementer, qa-reviewer, fixer

  The Classifier auto-routes requests to the right layer.

  Dev-Loop (7 phases per story):
    1. VALIDATE    Check prerequisites
    2. DELEGATE    Build context, select model
    3. IMPLEMENT   Dispatch implementer agent
    4. SELF-HEAL   Run checks, auto-fix (up to 3x)
    5. QA REVIEW   Dispatch QA reviewer agent
    6. GIT CRAFT   Create documentation-quality commit
    7. CHECKPOINT  Mode-dependent user interaction

  Context Engine:
    Composes right-sized context per agent (70-85% token
    reduction vs. loading everything). 5 tiers from T0
    (full orchestrator context) to T4 (fix agent, minimal).

  Trust System:
    Tracks QA pass rate, self-heal success, total stories.
    Four levels: Novice > Apprentice > Journeyman > Expert.
```

## Native Claude Code Integrations

These built-in Claude Code features work great with Maestro:

### /effort — Control model effort level
```
/effort low     — Fast responses, lower cost (good for status checks)
/effort medium  — Balanced (default for most tasks)
/effort high    — Maximum reasoning power (good for architecture, debugging)
```
Maestro agents use effort levels automatically based on their role.

### /loop — Recurring tasks
```
/loop 5m /maestro status   — Check status every 5 minutes
/loop 30m /maestro heartbeat — Monitor heartbeat every 30 minutes
```

### /remote-control — Control from phone
```
/remote-control   — Get a URL to control this session from any device
```
Pair with Maestro's Telegram remote listener for full mobile control.

### Agent Teams
Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to enable native agent teams.
Maestro's TeammateIdle and TaskCompleted hooks integrate automatically.

## Behavior

- If the user asks a question not covered by a topic, answer it using your understanding of the Maestro plugin (read skill files if needed).
- Always end with a relevant suggestion for what to do next.
- Keep answers concise. The user is looking for quick guidance, not a lecture.
