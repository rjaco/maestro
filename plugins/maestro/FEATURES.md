# Maestro — Complete Feature Guide

> The most comprehensive Claude Code orchestration plugin. 138 skills, 43 commands, 7 squads, 6 agents, 11 specialist profiles, 19 hooks across 16 events.

---

## Quick Start

```bash
/maestro init                    # Auto-detect your project and set up Maestro
/maestro "Add user auth"         # Build a feature autonomously
/maestro magnum-opus "Build a SaaS app" # Full product build with milestones
/maestro status                  # Check progress
```

---

## Commands (42)

| Command | Usage | What It Does |
|---------|-------|-------------|
| `/maestro` | `/maestro "description"` | Build any feature — decompose, implement, review, commit |
| `/maestro magnum-opus` | `/maestro magnum-opus "vision" --full-auto` | Magnum Opus — build entire products with milestones |
| `/maestro opus` | `/maestro opus "vision"` | Alias for magnum-opus — same full product build workflow |
| `/maestro plan` | `/maestro plan "feature"` | Deep planning mode — brainstorm, explore, design, decompose |
| `/maestro init` | `/maestro init` | Zero-config project detection — auto-discover stack, CI, tests, MCP |
| `/maestro status` | `/maestro status` | View progress, current story, spend, phase |
| `/maestro board` | `/maestro board` | Text-based kanban board with story status |
| `/maestro viz` | `/maestro viz deps` | Mermaid diagrams — dependency graph, architecture, roadmap |
| `/maestro deps` | `/maestro deps` | Visualize story dependency graph |
| `/maestro spec` | `/maestro spec "feature"` | Create structured feature specs consumed by all agents |
| `/maestro model` | `/maestro model` | View/edit model assignments per task type |
| `/maestro config` | `/maestro config` | Interactive configuration editor |
| `/maestro doctor` | `/maestro doctor` | Health check and diagnostics |
| `/maestro demo` | `/maestro demo` | Interactive demo — shows all phases without real changes |
| `/maestro quick-start` | `/maestro quick-start` | Pre-built task templates — zero thinking required |
| `/maestro cost-estimate` | `/maestro cost-estimate` | Estimate token cost before building |
| `/maestro notify` | `/maestro notify "message"` | Send notifications to Slack/Discord/Telegram |
| `/maestro history` | `/maestro history --export html` | View session history, export as HTML/blog/JSON |
| `/maestro rollback` | `/maestro rollback` | Revert changes from a story or feature |
| `/maestro brain` | `/maestro brain` | Second brain — connect to Obsidian/Notion |
| `/maestro help` | `/maestro help` | Contextual help and guided walkthroughs |
| `/maestro sync-ide` | `/maestro sync-ide [--target <ide>] [--check]` | Generate IDE-specific files (.cursorrules, GEMINI.md, agents.md, copilot-instructions) |
| `/maestro watch` | `/maestro watch [start\|stop\|status\|logs]` | Continuous project health monitoring — tests, types, lint, security. Auto-creates fix stories |
| `/maestro observe` | `/maestro observe [live\|history\|agents\|costs]` | Agent observability dashboard — live dispatches, tokens, costs, QA iterations |
| `/maestro aware` | `/maestro aware [check\|status\|history]` | Heartbeat-style proactive monitoring — quality gates, dependencies, conventions |
| `/maestro retro` | `/maestro retro` | Self-improvement retrospective — meta-rules, rule scoring, lifecycle management |
| `/maestro security-scan` | `/maestro security-scan` | Security vulnerability scan — SHA-256 drift, OWASP checks, dependency audit |
| `/maestro squad` | `/maestro squad [list\|activate\|create]` | Team definition — activate one of 7 squad templates |
| `/maestro schedule` | `/maestro schedule [add\|list\|remove]` | Cron-based task scheduling using Claude Code CronCreate |
| `/maestro webhooks` | `/maestro webhooks` | Inbound event processing from GitHub, CI/CD, monitoring |
| `/maestro workers` | `/maestro workers` | Background worker management for parallel agent execution |
| `/maestro profile` | `/maestro profile [list\|set\|show]` | Specialist profile switching (backend, frontend, devops, security, etc.) |
| `/maestro pair` | `/maestro pair` | Pair programming mode — collaborative step-by-step implementation |
| `/maestro remote` | `/maestro remote` | Remote control via Telegram, Discord, or HTTP |
| `/maestro dashboard` | `/maestro dashboard` | Project health dashboard with watch panel, cost, and progress |
| `/maestro ci` | `/maestro ci` | Monitor GitHub Actions / GitLab CI pipeline status |
| `/maestro soul` | `/maestro soul` | View and edit Maestro's core values and behavior constraints |
| `/maestro content` | `/maestro content "topic"` | Content pipeline — blog posts, email campaigns, SEO optimization |
| `/maestro marketing` | `/maestro marketing` | Marketing automation — ad copy, A/B frameworks, campaign tracking |
| `/maestro preferences` | `/maestro preferences` | View and edit user preferences and workflow settings |

---

## Orchestration Skills (128)

### Core Orchestration

| Skill | Purpose |
|-------|---------|
| **dev-loop** | 7-phase execution cycle: validate → delegate → implement → self-heal → QA review → git craft → checkpoint |
| **opus-loop** | Magnum Opus multi-milestone autonomous loop with deep interview, mega research, and roadmap generation |
| **decompose** | Break features into 2-8 stories with dependency graph and acceptance criteria |
| **delegation** | Agent dispatch protocol — who executes, what model, what context. Auto-downgrade for cost savings |
| **classifier** | Auto-classify requests and route to correct layer (vision/tactics/execution/knowledge work) |
| **context-engine** | Right-sized context packages for each agent. Cross-session intelligence, file relevance scoring, 5-stage compaction |
| **model-router** | 10-dimension task scoring (0-30) for optimal model selection. 70% cost reduction potential |
| **architecture** | Design or update technical architecture — produces architecture.md with stack, data model, API, and infra decisions |

### Quality & Review

| Skill | Purpose |
|-------|---------|
| **multi-review** | 3-perspective parallel code review — correctness, security, performance |
| **gcr-loop** | Generator-Critic-Refiner 3-agent pipeline with externalized rubrics |
| **test-gen** | Auto-generate unit, integration, and component tests per story |
| **commit-score** | Rate each commit on tests, conventions, message quality |
| **git-craft** | Documentation-quality git commits that serve as implementation record |
| **qa-reviewer** | QA review with confidence-scored findings |
| **semantic-diff** | Architectural impact explanation at line/function/architecture levels |

### Intelligence & Learning

| Skill | Purpose |
|-------|---------|
| **memory** | Dual-sector memory with confidence scoring (0.0-1.0), salience decay, FTS search |
| **retrospective** | Self-improvement with meta-rules, rule quality scoring (0-12), 5-stage lifecycle |
| **self-correct** | Permanent learning from corrections — captures feedback, applies to all skills/CLAUDE.md |
| **feature-registry** | Immutable JSON requirement registry surviving context resets for multi-session continuity |
| **steering** | 4 persistent files (product.md, structure.md, tech.md, standards.md) as T1 context |
| **audit-log** | Structured decision log — 8 decision types with confidence and outcome tracking |
| **learning-loop** | Continuous token efficiency learning — reads high-iteration patterns, improves routing |
| **knowledge-graph** | Structured knowledge graph for cross-session project intelligence |
| **truth-verifier** | Verify factual claims and prevent hallucination in agent outputs |
| **anti-drift** | Detect and correct behavioral drift in long-running agent sessions |

### Safety & Resilience

| Skill | Purpose |
|-------|---------|
| **doom-loop** | Detect and break agent doom-loops — 4 patterns, 3-level progressive intervention |
| **checkpoint** | Named project-state snapshots with HANDOFF.md output for session transfer |
| **security-drift** | SHA-256 baseline integrity checking for critical files |
| **index-health** | Validation and self-healing for all 7 Maestro indexes |
| **speculative** | Reversible agent runs with forkSession + file checkpointing + rewindFiles() |
| **rules-doctor** | Lint CLAUDE.md and skill configs for dead rules, broken references, misconfigs |
| **error-recovery** | Structured recovery from agent failures — classify, retry, escalate, or abort |
| **model-failover** | Automatic model failover when primary model is unavailable or rate-limited |
| **story-validator** | Pre-flight validation of story files before delegation — catch malformed inputs early |

### Cost & Performance

| Skill | Purpose |
|-------|---------|
| **cost-dashboard** | Per-model cost breakdown, cache efficiency, budget management, optimization tips |
| **token-ledger** | Track token usage and costs per story, feature, and session |
| **forecast** | Estimate token cost before execution |
| **benchmark** | Performance benchmarking for Maestro operations |

### Project Management

| Skill | Purpose |
|-------|---------|
| **kanban** | Bidirectional sync with Asana, Jira, Linear, GitHub Issues |
| **squad** | Team definition with 7 templates (speed, quality, full, solo, content, devops, research) |
| **squad-registry** | Central registry for all squad definitions and active squad state |
| **spec** | Spec-driven workflow — structured specs as shared context artifacts |
| **spec-first** | Enforces spec-before-code gate — auto-generates and validates spec before any dev-loop |
| **ship** | Final verification, PR creation, quality gates |
| **living-docs** | Update .maestro state and roadmap after story/milestone completion |
| **build-log** | Session replay with 4 export formats (HTML, blog, summary, JSON) |
| **watch** | Base continuous monitoring via CronCreate for tests, types, performance |
| **maestro-watch** | Enhanced watch with auto-fix stories, Lighthouse, security audit, and dashboard integration |
| **adr** | Architecture Decision Records — create, list, and supersede ADRs |
| **readme-gen** | Auto-generate README and API docs after each story or milestone |

### Integrations & Automation

| Skill | Purpose |
|-------|---------|
| **webhooks** | Inbound event processing — GitHub, CI/CD, deploy, monitoring |
| **triggers** | Event-driven automation — GitHub PR, Slack, cron, file changes → Maestro actions |
| **ci-watch** | Monitor GitHub Actions / GitLab CI during and after builds |
| **notify** | Push notifications to Slack, Discord, Telegram, PagerDuty |
| **scheduler** | Cron-based task scheduling using Claude Code CronCreate |
| **awareness** | Heartbeat-style proactive monitoring for quality and dependencies |
| **http-hooks** | HTTP-based webhook receiver for inbound event processing |
| **team-hooks** | Hooks for team coordination events — teammate idle, task completed |
| **telemetry** | Structured telemetry emission for dispatch timing and agent status events |
| **background-workers** | Parallel worker pool management for concurrent agent execution |
| **stream-chain** | Chain agent outputs as streaming inputs to downstream agents |

### Knowledge Work

| Skill | Purpose |
|-------|---------|
| **content-pipeline** | Blog posts, case studies, email campaigns with SEO optimization |
| **content-calendar** | Monthly content planning with keyword clustering |
| **content-validator** | Readability, SEO signals, heading hierarchy, link health |
| **marketing-automation** | Ad copy variations, A/B test frameworks, campaign tracking |
| **scenario-planning** | What-if analyses, business model simulations |
| **strategy** | Marketing and growth strategy planning |
| **research** | Competitive intelligence using web search and Playwright |

### Developer Experience

| Skill | Purpose |
|-------|---------|
| **project-dna** | Auto-discover tech stack, patterns, conventions + tree-sitter repo mapping |
| **live-docs** | Inject current framework docs before implementation |
| **explain-mode** | Educational mode — explains each phase as it runs |
| **quick-start** | Pre-built task templates for common patterns |
| **voice** | Voice command mapping for Claude Code /voice mode |
| **preview** | Chrome preview of UI changes via Playwright screenshots |
| **auto-docs** | Auto-generate README, API docs, changelog after each story |
| **audio** | Audio alerts when Maestro needs attention — terminal bell, macOS sounds, Linux audio |
| **visualize** | Generate Mermaid diagrams and ASCII dashboards for dependencies, architecture, roadmaps, and progress |
| **pair-programming** | Collaborative pair mode — step-by-step implementation with explicit approval checkpoints |
| **onboarding** | First-run onboarding flow — guided setup for new users and projects |
| **dashboard** | Project health dashboard — phase, progress, costs, watch panel, active stories |
| **pipeline-viz** | Visualize CI/CD pipeline structure and status as Mermaid diagrams |
| **i18n** | Internationalization helpers — extract strings, generate locale files, validate translations |
| **auto-init** | Auto-initialize Maestro state and config from project conventions without prompting |

### Platform & SDK

| Skill | Purpose |
|-------|---------|
| **agent-sdk** | Programmatic Maestro control via @anthropic-ai/claude-agent-sdk |
| **ecosystem** | Cross-platform compatibility — Terminal, Desktop, Cowork, Agent SDK |
| **dispatch-compat** | Compatibility with Claude Code Dispatch and Remote Control |
| **hooks-integration** | Reference for all 10+ Claude Code hooks used by Maestro |
| **mcp-detect** | Detect available MCP servers and CLI tools |
| **workspace** | Isolate sessions by workspace for multi-project support |
| **workflow-export** | Export plans as declarative YAML workflow files |
| **remote-control** | Control Maestro from Telegram, Discord, or HTTP via Agent SDK |
| **plugin-data** | Durable cross-project storage via `${CLAUDE_PLUGIN_DATA}` environment variable |
| **config-profiles** | Project profile switching — swap entire config with one command (7 built-in profiles) |

### Meta & Self-Improvement

| Skill | Purpose |
|-------|---------|
| **skill-factory** | Auto-create project-specific101 skills from profile templates |
| **output-contracts** | Declare expected output formats and validate compliance |
| **output-format** | Consistent terminal output formatting standard |
| **health-score** | Project health score (0-100) from coverage, types, lint, deps, debt |
| **brain** | Second brain — connect to Obsidian or Notion for persistent knowledge |

---

## Shell Scripts (15)

| Script | Usage | What It Does |
|--------|-------|-------------|
| `hooks/branch-guard.sh` | Auto (PreToolUse) | Blocks commits/pushes to main — enforces development branch workflow |
| `hooks/opus-loop-hook.sh` | Auto (Stop) | Re-injects prompt for continuous Opus loop in full-auto mode |
| `hooks/stop-hook.sh` | Auto (Stop) | Prevents exit during active dev-loop sessions |
| `hooks/notification-hook.sh` | Auto (Notification) | Desktop notifications when user input needed |
| `scripts/notify.sh` | `./scripts/notify.sh "msg"` | Send Slack/Discord/Telegram notifications from shell |
| `scripts/health-dashboard.sh` | `./scripts/health-dashboard.sh` | Terminal health dashboard — git, quality, deps, system |
| `scripts/security-drift-check.sh` | `./scripts/security-drift-check.sh` | SHA-256 baseline check for critical files |
| `scripts/index-health-check.sh` | `./scripts/index-health-check.sh` | Validate Maestro indexes for staleness/integrity |
| `scripts/audio-alert.sh` | `./scripts/audio-alert.sh success` | Cross-platform audio alerts (macOS/Linux/WSL) |
| `scripts/service-installer.sh` | `./scripts/service-installer.sh install` | Install Maestro as background service (launchd/systemd) |
| `scripts/session-lock.sh` | `./scripts/session-lock.sh acquire` | PID-based session locking for concurrent prevention |
| `scripts/worktree-merge.sh` | `./scripts/worktree-merge.sh <path>` | Merge worktree → development branch + cleanup |
| `scripts/statusline.sh` | Auto (status line) | ANSI-colored status line showing phase, progress, cost |
| `scripts/setup-maestro.sh` | `./scripts/setup-maestro.sh` | Initial Maestro setup and configuration |
| `scripts/context-check.sh` | `./scripts/context-check.sh` | Context window usage monitor with ASCII progress bar |

---

## Agents (6)

| Agent | Model | Role |
|-------|-------|------|
| **implementer** | sonnet | Implements stories using TDD — the builder |
| **qa-reviewer** | sonnet | Reviews code for bugs, security, conventions |
| **fixer** | sonnet | Minimal fixes for specific errors during self-heal |
| **researcher** | sonnet | Web search and Playwright for competitive intel |
| **strategist** | sonnet | Strategy docs from research findings |
| **proactive** | sonnet | Background monitoring — health checks, briefings |

---

## Specialist Profiles (11)

| Profile | Expertise |
|---------|-----------|
| backend-engineer | APIs, databases, server-side logic |
| frontend-engineer | React, CSS, components, accessibility |
| designer | UI/UX, design systems, visual polish |
| devops | CI/CD, Docker, Kubernetes, infrastructure |
| security-reviewer | OWASP, auth, encryption, vulnerability scanning |
| data-engineer | Pipelines, ETL, data modeling |
| content-marketer | Blog, SEO, email campaigns |
| growth-marketer | Ads, funnels, analytics, A/B testing |
| copywriter | Ad copy, landing pages, messaging |
| project-manager | Task orchestration, scheduling, reporting |
| seo-specialist | Keywords, technical SEO, content optimization |

---

## Notification Providers (4)

| Provider | Config | Method |
|----------|--------|--------|
| Slack | `webhook_url` | Incoming webhook POST |
| Discord | `webhook_url` | Webhook POST with embeds |
| Telegram | `bot_token` + `chat_id` | Bot API sendMessage |
| PagerDuty | `routing_key` | Events API v2 with severity mapping |

---

## Kanban Integrations (4)

| Provider | Sync Type |
|----------|-----------|
| GitHub Issues | Bidirectional |
| Jira | Bidirectional |
| Linear | Bidirectional |
| Asana | Bidirectional |

---

## Webhook Event Sources

| Source | Events |
|--------|--------|
| GitHub | PR opened, push, issues, PR comments (`@maestro`26 commands) |
| CI/CD | Build passed/failed, deploy completed |
| Deploy | Vercel, Netlify, GitHub Actions, Railway |
| Monitoring | Sentry, Datadog, UptimeRobot, PagerDuty |

---

## Architecture

```
[User Command] → [Classifier] → [Layer Router]
                                     |
                   +-----------------+------------------+
                   |                 |                   |
             [Vision Layer]   [Tactics Layer]    [Execution Layer]
             research         decompose           dev-loop
             strategy         architecture        delegation
             opus-loop        forecast            git-craft
                                                  ship
                                                  preview
                                                  watch
```

### Branching Strategy

- `development` — all work happens here
- `main` — only updated via explicit launch/release
- Branch guard hook enforces this automatically

### Model Routing

| Task | Model | When |
|------|-------|------|
| Simple tasks | haiku | Score 0-8, boilerplate, config |
| Standard dev | sonnet | Score 9-16, features, tests |
| Complex work | opus | Score 17-30, architecture, security |

Auto-downgrade saves ~70% on token costs by routing simple tasks to cheaper models.

### Context Engine

5-stage progressive compaction:
1. **60%** — Selective truncation of verbose outputs
2. **70%** — Summarize completed stories
3. **80%** — Offload to memory files
4. **90%** — Prune to last 2 stories
5. **95%** — Full reset with HANDOFF.md state transfer

---

## What Makes Maestro Different

| vs Cursor | vs Codex | vs Windsurf |
|-----------|----------|-------------|
| Terminal-native, not IDE-locked | Local execution, not cloud-only | Skills are markdown, not proprietary |
| 101 skills > basic composer | Progressive trust > one-shot | Self-improving via retrospective |
| Kanban + Notion/Obsidian sync | No project management | No knowledge work support |
| 4 notification providers | No notifications | No notifications |
| Cost tracking + auto-downgrade | No cost control | No cost tracking |
| Spec-driven + feature registry | No spec system | No session handoff |
| Security drift detection | No security audit | No integrity checks |
| Remote control (Telegram/Discord) | No remote access | No remote access |
| Config profile switching | No profiles | No profiles |
| Plugin data persistence | Sandbox-only | No persistence |

---

## Recent Additions (M10)

| Feature | Description |
|---------|-------------|
| **remote-control** | Control Maestro from Telegram/Discord/HTTP via Agent SDK |
| **config-profiles** | Switch entire configuration with one command (7 built-in profiles) |
| **plugin-data** | Durable cross-project storage via `${CLAUDE_PLUGIN_DATA}` |
| **context-check.sh** | Context window usage monitor with ASCII progress bar |

---

*Last updated: 2026-03-18 | 101 skills, 26 commands, 11 scripts, 6 agents, 11 profiles*
