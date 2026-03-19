# Changelog

All notable changes to Maestro are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — Wave 5: Ultimate Development Tool (Ruflo + AioX-Inspired)
- Consensus mechanisms skill — weighted voting, quorum checks, conflict resolution for multi-agent decisions
- Anti-drift verification skill — post-task goal alignment at story, milestone, and vision levels
- Knowledge graph skill — PageRank-based codebase analysis for smarter context composition
- Claims system skill — human-agent override protocol with learning from corrections
- Token optimization enhancements — per-story cost tracking, cost-per-LOC, cache-friendly context ordering
- Enhanced health dashboard — box-drawing, color coding, sparklines, responsive terminal UI
- StatusLine integration — real-time Maestro progress in Claude Code status bar
- Opus progress display — live milestone/story/phase tracking with ETA and cost
- Error UX improvements — actionable error messages across all 11 hook scripts
- Enhanced auto-init — detect 8 project types (Node, Python, Rust, Go, Ruby, Java, PHP, Swift)
- Interactive help improvements — contextual help, examples, search, quick reference card
- Command UX audit — consistent flags, aliases, usage examples across 39 commands
- Quick-start expansion — 12 templates covering web, CLI, mobile, data, ML project types
- Agent Teams native support — TeammateIdle + TaskCompleted hook handlers
- Cowork adaptive output — environment detection, collaborative formatting
- Dispatch integration — mobile-friendly status, remote commands, webhook JSON protocol
- Enhanced MCP server — 5 expanded tools (status, stories, metrics, control, health)
- 6 new background workers — security scan, perf regression, API drift, coverage, docs staleness, complexity
- Worker scheduling improvements — context-triggered workers, priority queue, worker health tracking
- Daemon hardening — retry with exponential backoff, health monitoring, crash recovery, log rotation
- Cross-session state persistence — atomic writes, corruption detection, backup/restore
- Enhanced learning loop — 5th SHARE phase, cross-project knowledge transfer, confidence scoring
- Adaptive model routing — historical performance tracking per task type, auto-adjustment
- Runtime skill evolution — automatic refinement from QA feedback patterns with versioning
- Agent observability dashboard + intelligent error recovery
- Spec-first enforcement + pipeline visualizer
- Story v2 format (Gherkin AC, execution modes)
- Prompt injection defense hook
- IDE fan-out sync + squad registry
- AGENTS.md cross-tool discovery
- Async telemetry (JSONL format)
- Skill budget controls (effort/maxTurns)
- Context injection (Context7 pattern)
- HTTP hooks + MCP elicitation + plugin data persistence

### Changed
- Skills: 109 → 138 (29 new skills)
- Commands: 25 → 43 (18 new commands)
- Hook scripts: 11 → 19 (8 new hooks)
- Hook events: 8 → 16 (8 new events)
- Templates: 12 → 13
- Self-test: 12/12 passing
- Mirror: perfectly synced

## [1.4.0] — 2026-03-18

### Added — OpenClaw-Inspired Intelligence
- SOUL.md persistent orchestrator identity (decision principles, communication style, autonomy level)
- Runtime skill authoring — autonomous gap detection and skill generation from repeated patterns
- Durable memory with 3-tier decay model (facts/lessons/episodes, confidence scoring, auto-promotion)
- Skill dependency gating — declarative `requires` frontmatter (tools, bins, env, mcp, os, plugins)
- 4-tier skill precedence (workspace > runtime > global > bundled)
- `/btw` side-question command — ask questions during sessions without disrupting orchestration
- Token budget enforcement — pre-dispatch cost calculation with 90% threshold warnings
- Publish-time security scanner — 433-line static + behavioral analysis (ClawHavoc defense)
- Skill hot-reloading watcher — detects SKILL.md changes between sessions
- Multi-language support (i18n) — EN, PT-BR, ES for skill descriptions and output
- Multi-key rotation on 429 — round-robin API key rotation with sticky-on-success

### Added — Ruflo-Inspired Autonomy
- Context autopilot — 4-level threshold (80/90/95%/PostCompact), transparent recovery
- CI/headless mode — MAESTRO_CI=true, JSON lines output, exit codes, GitHub Actions examples
- ADR auto-generation — detects architectural decisions at milestone boundaries
- Truth verification — verifies every claim in agent status reports before QA
- Stream chaining — agent-to-agent output piping, eliminates file intermediaries
- Agent team coordination — lead/worker/reviewer roles, TeammateIdle/TaskCompleted hooks
- Multi-LLM failover — exponential backoff, tier escalation, 429 Retry-After awareness
- 4-phase learning loop — RETRIEVE→JUDGE→DISTILL→CONSOLIDATE between milestones
- Pair programming — `/maestro pair` for AI-human collaborative coding with test-first
- 6 background autonomous workers — health, dependency audit, convention drift, memory decay, cleanup, cost
- 6 swarm topologies — hierarchical, mesh, ring, star, pipeline, adaptive
- 3-tier cost routing — free (bash), budget (haiku), premium (sonnet/opus)

### Added — Infrastructure & Quality
- 4 new squads (7 total): speed-dev, solo-dev, quality-gate, research-team
- 7 profile config files (default, speed, quality, cost-saver, frontend, backend, content)
- Plugin validator script (scripts/validate-plugin.sh) — 8-category structural checks
- Plugin self-test script (scripts/self-test.sh) — 12 comprehensive tests, all passing
- README auto-generator skill
- MCP graceful degradation for kanban and brain providers
- Skill loader with gate evaluation protocol

### Fixed
- Root .claude-plugin/plugin.json now has full metadata (was minimal)
- Init command no longer creates [TODO] placeholders (actionable fallbacks instead)
- Full mirror sync — 106 skills in both root and plugins/maestro/

## [1.3.0] — 2026-03-18

### Added
- Squads system — composable, shareable agent team packages (full-stack-dev, content-creator, devops-sre)
- Squad management command (`/maestro squad list|activate|deactivate|create|info`)
- Squad marketplace structure (CONTRIBUTING, SECURITY, VALIDATION, schema reference)
- Technical preferences profile (`~/.claude/maestro-preferences.md`) with show/set/edit/reset
- Enhanced story template — fully self-contained with inline context (zero upstream references)
- Story context validator — 8-rule pre-dispatch completeness check (V1-V8)
- Hook parity table — feature matrix across Claude Code, Gemini CLI, Codex CLI, Cursor
- Gemini CLI adapter with tool mapping and GEMINI.md integration
- Codex CLI compatibility guide with degradation paths
- Universal output format — 4-environment detection (terminal/desktop/remote/SDK)
- Zero-config auto-init — `/maestro "build X"` works without explicit init
- Onboarding wizard — 4-question interactive first-run configuration
- Terminal dashboard — box-drawing progress display with cost breakdown and ETA
- MCP server definition (`.mcp.json`) with 5 tools for Claude Desktop integration
- Agent SDK integration guide — TypeScript + Python examples (913 lines)
- Claude Desktop / Cowork compatibility skill with environment detection
- Skill validation framework — 14 security rules addressing CVE-2026-25253 patterns
- Skill pack format — import/export bundles with manifest.json and versioning
- Community contribution templates (CONTRIBUTING.md, GitHub issue/PR templates)
- Plugin health badges in README (version, skills, commands, agents, squads, hooks)

### Changed
- Version bumped to 1.3.0
- Plugin metadata completed (author URL, homepage, repository, categories, 20 keywords)
- README badges updated to reflect current inventory (87 skills, 25 commands, 3 squads)
- Explain mode enhanced with "why" explanations per phase and auto-disable after 3 features
- Full mirror sync — all 87 skills, 25 commands, 10 templates now in plugins/maestro/

### Fixed
- Hardcoded path in statusline.sh comment (now uses ${CLAUDE_PLUGIN_ROOT})
- plugins/maestro mirror was missing 12 skills, 2 commands, 2 templates, squads, .mcp.json, CHANGELOG
- hooks.json in plugins/maestro missing delegation-hook PreToolUse matchers
- Version inconsistency between root (1.2.0) and plugins/maestro (1.1.0)

## [1.2.0] — 2026-03-17

### Added
- BMAD-inspired hyper-detailed story template with contextualized stories
- Deep plan mode with context usage percentage in status display
- 24/7 daemon mode — external loop driver for unbreakable Magnum Opus sessions
- Product-framing skill — CEO-style 4-mode request reframing with `--framing` flag
- Profile command for managing specialist configurations
- Pre-implementation dialogue for requirement clarification
- Agent SDK hooks reference documentation
- HTTP hooks specification
- Rich status display with box-drawing consistency
- ASCII art banners for all commands and Magnum Opus mode
- Context window checker — usage monitor inspired by ClaudeClaw's convolife
- Remote control skill — Telegram, Discord, and HTTP bot integration
- Plugin data persistence using `${CLAUDE_PLUGIN_DATA}` durable storage
- Config profile switching for project-specific configurations
- Comprehensive FEATURES.md documenting all 75 skills, 20+ commands, 14 scripts
- Hooks integration reference and spec command
- Speculative execution, cost dashboard, and spec-driven workflow
- Enhanced init onboarding — zero-config detection with guided first build
- Project health dashboard — terminal-based health overview
- Agent SDK integration skill for programmatic Maestro control
- Notify, service installer, and session lock scripts
- Self-correction loop — permanent learning from corrections and QA feedback
- Event-driven trigger system inspired by Cursor Automations
- Smart model router — 10-dimension task scoring for optimal model selection
- Branch guard hook, security scripts, health check, audio alerts, worktree merge
- Security drift detection, checkpoints, steering files, semantic diffs
- Context intelligence — cross-session persistence and file relevance scoring
- Doom-loop prevention, skill registry, graceful context recovery, audit trail, compaction handling
- PR triggers, PagerDuty integration, tree-sitter support, deploy/monitoring events
- Squad system, confidence memory, cost routing, web export, meta-rules (OpenClaw parity)

### Changed
- Renamed `/maestro opus` to `/maestro magnum-opus` to avoid Claude Opus model confusion
- Magnum Opus always asks mode, full-auto infinite loop support
- Version bumped to 1.2.0

### Fixed
- Removed jq dependency from statusline.sh and all hooks (pure bash/sed/grep)
- Eliminated python3 dependencies from all hooks
- Resolved all 7 QA audit findings (router, variables, model versions)
- Restored ASCII banners lost in worktree merges
- Removed duplicate Output Contract section in benchmark skill
- Doc accuracy — updated skill count to 75, added retro/profile to README

## [1.1.0] — 2026-03-16

### Added
- Delegation enforcement hook (PreToolUse) — prevents orchestrator from editing source files directly
- Session start hook (SessionStart) — auto-injects Maestro state at session start
- Parallel story dispatch for independent stories in dev-loop
- Signal-based model scoring in delegation (6-signal scoring matrix)
- Progressive trust tracking with trust.yaml metrics
- Quantitative self-improvement with 10 concrete adjustment rules between milestones
- CLAUDE.md rule parsing and file content extraction in context engine
- Relevance scoring decision tree for context composition
- Project lessons injection from retrospective to implementer agents
- Context caching between stories within a milestone
- Kanban integration providers: GitHub Issues, Jira, Linear, Asana
- Second brain providers: Obsidian, Notion
- Interactive menus for model, config, and mode selection via AskUserQuestion
- `/maestro plan` command — deep planning with 7-phase workflow
- Webhooks, enhanced proactive agent, skill factory, self-improvement retrospective
- OpenClaw-inspired features: notifications, visuals, awareness, voice, ecosystem
- Standardized all user interactions to AskUserQuestion menus
- CI watch, workspaces, dispatch compatibility, auto-docs
- CLI power commands: cost estimate, deps, rollback, workflow export

### Changed
- Deep interview with adaptive flow control, expertise-level detection, conversation pacing
- Milestone evaluator with concrete bash verification commands and evidence types
- Implementer agent checks project lessons before reporting DONE
- Delegation skill expanded with full dispatch protocol (102 → 307 lines)
- Simplified command names (`/maestro:init` instead of `/maestro:maestro-init`)
- Opus loop made truly autonomous via Stop hook (Ralph Loop pattern)

### Fixed
- YAML parser in all hooks — handles colons in values correctly
- opus-loop-hook unguarded stdin read and sed commands
- Hardcoded "full_auto" in opus-loop system message (now uses actual mode)
- Version inconsistency in state template (1.0.0 → 1.1.0)
- mcp-detect uses actual ToolSearch tool with .mcp.json fallback
- multi-review documents optional feature-dev plugin dependency
- notification-hook.sh upgraded to robust YAML parser
- Compliance with Anthropic plugin/skills specification
- Anti-pattern guard: "execute, don't plan" rule enforced

## [1.0.0] — 2026-03-15

### Added
- Three-layer orchestration architecture (Vision/Strategy → Tactics/Architecture → Execution)
- Magnum Opus mode for autonomous product building from vision to shipping
- 6 agent definitions: implementer (sonnet), qa-reviewer (opus), fixer (sonnet), researcher (sonnet), strategist (opus), proactive (haiku)
- Dev-loop with 7-phase cycle: validate, delegate, implement, self-heal, QA review, git-craft, checkpoint
- Context Engine with T0-T4 tiered context management (70-85% token reduction)
- 40+ skills across execution, research, strategy, monitoring, and content
- 20+ slash commands including /maestro, /maestro opus, /maestro plan, /maestro init
- Deep interview — 10-dimension adaptive vision exploration
- Mega research sprint — 8 parallel research agents
- Roadmap generator with milestone-driven execution
- Stop hook for dev-loop and Opus session continuity
- Opus loop hook for full-auto and until-pause modes
- Notification hook for desktop alerts on checkpoint/pause
- 11 specialist profiles for skill-factory
- Status line with phase, progress bar, cost display
- Cost forecasting and token ledger
- Content pipeline for blog, case study, email, social
- Workflow export/import as YAML
- Multi-workspace support
- Decompose skill with dependency graph generation
- Output contracts and content validator for knowledge work
- Marketing automation with A/B testing framework
- Scenario planning with sensitivity analysis

[Unreleased]: https://github.com/rjaco/maestro-orchestrator/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/rjaco/maestro-orchestrator/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/rjaco/maestro-orchestrator/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/rjaco/maestro-orchestrator/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/rjaco/maestro-orchestrator/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/rjaco/maestro-orchestrator/releases/tag/v1.0.0
