# Changelog

All notable changes to Maestro are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Plugin structure professionalization (Wave 4 — Opus session)
- Squads system for composable agent teams
- Tech preferences profile for persistent developer identity
- Multi-IDE compatibility layer documentation

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

[Unreleased]: https://github.com/anthropics/maestro-orchestrator/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/anthropics/maestro-orchestrator/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/anthropics/maestro-orchestrator/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/anthropics/maestro-orchestrator/releases/tag/v1.0.0
