# Claude Code Plugin Ecosystem Research — March 2026

Researcher: Claude Sonnet 4.6
Date: 2026-03-18
Scope: Claude Code v2.1.x features, plugin ecosystem, community signals, agent SDK hooks, agentic coding patterns

---

## 1. Competitor Matrix: Top 10 Most-Installed Plugins

| Plugin | Installs | Category | Core Value |
|---|---|---|---|
| Frontend Design | 96,400 | UI/UX | Replaces generic AI UI with opinionated design judgment (typography, color, layout) |
| Context7 | 71,800 | Context Management | Injects live library docs into context, eliminating hallucinations on evolving APIs |
| Ralph Loop | 57,000 | Autonomous Workflow | Multi-hour autonomous sessions with context resets between tasks; targets migrations/test coverage |
| Code Review | 50,000 | Code Quality | Multi-agent parallel PR review; assigns confidence scores to findings |
| Firecrawl | N/A | Web Data | Transforms websites to LLM-ready data; handles JS rendering and anti-bot |
| Playwright | 28,100 | Testing | Natural-language browser control; enables testing without writing test scripts |
| Security Guidance | 25,500+ | Security | Scans edits for vulnerabilities (command injection, XSS); blocks dangerous changes pre-merge |
| Chrome DevTools MCP | 20,000+ | Debugging | Full DevTools access: network inspection, console errors, DOM |
| Figma MCP | 18,100 | Design-to-Code | Reads Figma files directly; eliminates design-to-code handoff |
| Linear | 9,500 | Project Management | Pulls tickets and updates status without leaving the coding environment |

Source: [Firecrawl Blog — Top 10 Claude Code Plugins 2026](https://www.firecrawl.dev/blog/best-claude-code-plugins)

---

## 2. Competitor Profiles

### Feature-Dev (highest install count overall)
- **Install count**: 89,000+ (highest single plugin per claudemarketplaces.com aggregate)
- **Tech**: Skill with 7-phase workflow
- **Phases**: requirements gathering, codebase exploration, architecture design, implementation, testing, review, documentation
- **Strength**: End-to-end structured delivery for new features; enforces architectural thinking before implementation
- **Differentiator**: The closest direct analog to Maestro's scope — structured multi-phase feature delivery

### Context7
- **URL**: https://context7.com
- **Install count**: 71,800
- **Tech**: MCP server + doc scraper
- **Strength**: Solves the #1 hallucination vector (stale API knowledge) by injecting current docs at query time
- **Weakness**: Dependent on documentation availability; gaps in niche or private libraries
- **Differentiator**: Pulls docs at the moment of use, not at training time

### Ralph Loop
- **URL**: Community plugin (ralph-wiggum)
- **Install count**: 57,000
- **Tech**: Skill + /loop command wrapper
- **Strength**: Enables overnight/weekend autonomous runs across large codebases
- **Weakness**: No quality gate by default; can drift without human steering
- **Differentiator**: Targets truly unattended multi-hour sessions; no other plugin does this

### Shipyard
- **URL**: https://shipyard.build
- **Tech**: Plugin bundle (agents + hooks + IaC validation)
- **Strength**: Enterprise lifecycle management with infrastructure validation gates
- **Differentiator**: Multi-agent orchestration with compliance focus; closest to Maestro's scope in enterprise positioning

### Auto-Claude / Claude Squad
- **URL**: Community (GitHub)
- **Tech**: Multi-agent framework with kanban UI / terminal app with isolated workspaces
- **Differentiator**: Direct competitors to Maestro's orchestration layer; more lightweight, less opinionated

---

## 3. New v2.1.x Features for Plugin Development

Sources: [Claude Code Changelog](https://code.claude.com/docs/en/changelog) | [v2.1.77 Release Notes](https://claude-world.com/articles/claude-code-2177-release/) | [Agent SDK Hooks](https://platform.claude.com/docs/en/agent-sdk/hooks)

### 3.1 Complete Hook Event Table (as of March 2026)

| Hook | Python SDK | TypeScript SDK | Trigger | Can Block? |
|---|---|---|---|---|
| `PreToolUse` | Yes | Yes | Before any tool call | Yes |
| `PostToolUse` | Yes | Yes | After tool returns result | No |
| `PostToolUseFailure` | Yes | Yes | Tool execution failure | No |
| `UserPromptSubmit` | Yes | Yes | User submits prompt | No |
| `Stop` | Yes | Yes | Agent execution stops | No |
| `SubagentStart` | Yes | Yes | Subagent initializes | No |
| `SubagentStop` | Yes | Yes | Subagent completes | No |
| `PreCompact` | Yes | Yes | Before context compaction | No |
| `PostCompact` | Yes | Yes | After compaction completes | No |
| `PermissionRequest` | Yes | Yes | Permission dialog would show | Yes |
| `Notification` | Yes | Yes | Agent status messages | No |
| `StopFailure` | Yes | Yes | Turn ends due to API error | No |
| `InstructionsLoaded` | Yes | Yes | CLAUDE.md or rules/*.md loaded | No |
| `Elicitation` / `ElicitationResult` | Yes | Yes | MCP elicitation request | No |
| `SessionStart` | No | Yes | Session initializes | No |
| `SessionEnd` | No | Yes | Session terminates | No |
| `Setup` | No | Yes | --init or --maintenance flags | No |
| `TeammateIdle` | No | Yes | Teammate about to go idle | Yes (exit code 2) |
| `TaskCompleted` | No | Yes | Task being marked complete | Yes (exit code 2) |
| `ConfigChange` | No | Yes | Config files change in session | Yes |
| `WorktreeCreate` | No | Yes | Worktree isolation creates worktree | No |
| `WorktreeRemove` | No | Yes | Worktree isolation removes worktree | No |

New in v2.1.x (not present in v2.0): `WorktreeCreate`, `WorktreeRemove`, `ConfigChange`, `TeammateIdle`, `TaskCompleted`, `Setup`, `PostCompact`, `StopFailure`, `InstructionsLoaded`, `Elicitation`

### 3.2 Hook Mechanics

Callback output fields:
- `continue` — whether agent keeps running after this hook
- `systemMessage` — injects context into the conversation the model sees
- `hookSpecificOutput.permissionDecision` — "allow", "deny", or "ask"
- `hookSpecificOutput.permissionDecisionReason` — shown to user
- `hookSpecificOutput.updatedInput` — modified tool input (requires permissionDecision: "allow")
- `hookSpecificOutput.additionalContext` — appended to PostToolUse result

Async hooks: return `{async: true, asyncTimeout: 30000}` to not block the agent (use for logging/metrics only).

Multiple hook ordering: deny > ask > allow. If any hook denies, operation is blocked regardless of other hooks.

### 3.3 HTTP Hooks (New)

Plugins can register hooks as HTTP endpoints instead of shell commands:

```json
{
  "type": "http",
  "method": "POST",
  "url": "https://example.com/hook"
}
```

Enables cloud-hosted hook handlers and CI service integration.

### 3.4 Skill Frontmatter Enhancements

New fields for skill YAML frontmatter:

| Field | Purpose |
|---|---|
| `effort` | Set model effort level for this skill |
| `maxTurns` | Limit turns when skill invokes subagents |
| `disallowedTools` | Block specific tools during skill execution |
| `argument-hint` | Help text shown for skill arguments |
| `paths:` | Conditional execution based on file path |
| `background: true` | Always run as background task |
| `isolation: "worktree"` | Run in isolated git worktree |
| `memory` | Persistent memory (scope: user, project, local) |
| `tools` | Restrict subagent spawning via Task(agent_type) syntax |

### 3.5 Persistent Plugin Data

- `${CLAUDE_PLUGIN_DATA}` — persistent state directory surviving plugin updates
- `${CLAUDE_PLUGIN_ROOT}` — plugin's own root directory
- `${CLAUDE_SESSION_ID}` — current session ID
- `${CLAUDE_SKILL_DIR}` — skill's own directory
- `/plugin uninstall` now prompts before deleting plugin data

### 3.6 Plugin Source Types

- `git-subdir` — point to a subdirectory within a git repo (enables monorepo plugins)
- `pathPattern` — regex matching for file/directory sources

### 3.7 MCP Elicitation

MCP servers can now display interactive forms or open URLs during task execution to request structured input mid-run. This enables dynamic plugin configuration without pre-configuration requirements.

### 3.8 Agent Teams (Experimental, v2.1.32+)

Enable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json or environment.

Architecture:
- **Team lead**: main session that creates the team, assigns tasks, synthesizes results
- **Teammates**: independent Claude Code instances with own context windows
- **Task list**: shared, file-locked, with automatic dependency resolution
- **Mailbox**: direct inter-agent messaging system

Team config stored at: `~/.claude/teams/{team-name}/config.json`
Tasks stored at: `~/.claude/tasks/{team-name}/`

Subagents vs Agent Teams:

| | Subagents | Agent Teams |
|---|---|---|
| Communication | Results back to parent only | Teammates message each other directly |
| Coordination | Parent manages all work | Shared task list, self-coordination |
| Best for | Focused tasks, result-only | Complex work needing discussion/collaboration |
| Token cost | Lower | Higher (each teammate = separate Claude instance) |

Quality gates via hooks:
- `TeammateIdle`: exit code 2 sends feedback and keeps teammate working
- `TaskCompleted`: exit code 2 prevents marking done and injects feedback

### 3.9 Worktree Isolation

- `--worktree (-w)` flag creates isolated git worktrees per session
- Subagents support `isolation: worktree` frontmatter
- `WorktreeCreate` / `WorktreeRemove` hooks fire for lifecycle management
- Project configs and auto-memory now shared across git worktrees of same repo
- `--tmux` flag launches Claude in its own tmux session alongside worktree

### 3.10 Token and Context Changes

- Opus 4.6 default max output: 64,000 tokens
- Opus 4.6 and Sonnet 4.6 upper bound: 128,000 tokens
- `/context` command now identifies which tools consume the most context
- MCP tool search auto-mode: deferred tool loading when descriptions exceed 10% context
- Tool results >50KB persisted to disk (down from 100KB threshold)
- Prompt cache invalidation improved (reducing input tokens up to 12x)

### 3.11 /loop Command

`/loop [interval] <prompt>` transforms Claude Code into a recurring monitoring agent:

Example: `/loop 5m check if the deploy finished`

Enables plugin-triggered polling patterns without external schedulers.

### 3.12 Breaking Changes for Plugin Compatibility

| Change | Impact |
|---|---|
| Agent tool `resume` parameter removed | Use `SendMessage({to: agentId})` instead |
| `/fork` renamed to `/branch` | `/fork` still works as alias |
| `CLAUDE_CODE_PLUGIN_SEED_DIR` uses platform path delimiter (`:` on Unix, `;` on Windows) | Multi-seed configs need update |
| Plugin commands/agents/hooks available immediately after install | No restart required |
| Nested skill discovery ignores gitignored directories | node_modules, venv no longer scanned |

---

## 4. Community Intelligence: What Power Users Want

Sources: [Claude Code Reddit Guide](https://www.aitooldiscovery.com/guides/claude-code-reddit) | [Dev.to Claude vs Codex](https://dev.to/_46ea277e677b888e0cd13/claude-code-vs-codex-2026-what-500-reddit-developers-really-think-31pb)

### Most-Demanded Features (frequency-ranked)

1. **Better context management** — `/context` command is praised but users want proactive capacity warnings before hitting limits
2. **Cross-tool agent ecosystem compatibility** — CLAUDE.md vs agents.md tension; community pushes for interoperability with other tools
3. **IDE-native integration** — Terminal context-switching is friction; Cursor inline experience is the benchmark
4. **First-class parallel agent UI** — Tmux multi-agent pipelines are popular but feel like hacks
5. **CI/CD autonomy** — "Compounding engineering" where Claude Code handles GitHub Actions autonomously is heavily desired

### Top Workflows Discussed

1. Tmux multi-agent pipelines: parallel instances in separate panes, one agent querying another for verification
2. CI/CD automation: hooks enforcing standards both locally and in CI, same rules both places
3. Extensive CLAUDE.md customization per monorepo

### Community Complaint Summary

- Weekly usage caps hit before end of working week at $200/month tier
- Quality regression perception on complex reasoning tasks
- No native multi-agent UI (worktree + tmux is current workaround)

---

## 5. What People Are Building with the Agent SDK

Sources: [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview) | [Running Agents in Production — Medium](https://medium.com/@hugolu87/how-to-run-claude-agents-in-production-using-the-claude-sdk-756f9d3c93d8) | [Apple Xcode + Claude Agent SDK](https://www.anthropic.com/news/apple-xcode-claude-agent-sdk)

| Category | What's Being Built |
|---|---|
| Code review agents | Read PRs from GitHub, analyze quality, scan for security, post review comments |
| Bug detection/fixing | Autonomous bug hunt, fix, test verify loops |
| Production orchestration | Modular orchestrator architectures (Orchestra pattern) with specialist agents |
| IDE integration | Xcode 26.3 native Agent SDK integration (subagents, background tasks, plugins in Xcode) |
| Parallel migration agents | Worktree-isolated agents handling large codebase migrations concurrently |
| Monitoring/polling agents | /loop-powered agents watching deployments, PRs, CI status |
| Multi-model critique | Agent-Peer-Review pattern: multiple models critique each other's code |

---

## 6. Agentic Coding Best Practices 2026

Sources: [Simon Willison](https://simonwillison.net/2026/Feb/23/agentic-engineering-patterns/) | [CodeScene](https://codescene.com/blog/agentic-ai-coding-best-practice-patterns-for-speed-with-quality) | [Anthropic Trends via Tessl](https://tessl.io/blog/8-trends-shaping-software-engineering-in-2026-according-to-anthropics-agentic-coding-report/) | [Medium](https://abdus-muwwakkil.medium.com/agentic-coding-best-practices-fc167be3f7d5)

### Pattern 1: Spec-First Architecture
Compress a large codebase into a specification before handing to agents. 2,000 words of spec produces cleaner output than 50,000 lines of raw code context.

### Pattern 2: Outcome Specification Over Method Specification
Specify WHAT the agent should achieve and the verification criteria, not HOW to code. Over-specifying method degrades output.

### Pattern 3: Task Decomposition Sweet Spot
- 1-3 files with tests: single prompt
- 5+ files or new pattern: plan first, execute in 2-3 chunks
- Avoid over-decomposition (15+ micro-prompts loses architectural coherence)

### Pattern 4: Red/Green TDD as Agent Control
Test-first development enables agents to produce more dependable code with minimal prompting. Tests serve as specification AND quality gate simultaneously.

### Pattern 5: Coverage as Regression Signal
Strict coverage gates on PRs make weakening of behavioral checks visible. Use coverage as regression detection, not vanity metric.

### Pattern 6: Multi-Agent Specialist Orchestration
Organizations moving from single agents to specialist groups under an orchestrator. Requires clear task breakdown, coordination protocols, and cross-session visibility.

### Pattern 7: Human Oversight Scaling
AI-automated code review enables human oversight to scale without linear headcount. Hooks enforce gates; humans review summaries, not raw diffs.

### Pattern 8: Security Embedding at the Hook Layer
Security scanning moving from post-hoc audit to inline PreToolUse hook. Deny dangerous writes at hook layer, not PR review layer.

### Pattern 9: Architecture Value > Code Volume
Near-zero cost of code generation shifts value to architectural judgment. Plugins enforcing architectural consistency become high-value.

### Pattern 10: Monitored Success Metrics
Key metrics for agentic workflows: time to feature, iteration speed, bug rate per session, security findings per session.

---

## 7. Technical Patterns Observed Across Competitors

1. **Parallel N-reviewer pattern**: multiple subagents each taking a different lens (security, performance, test coverage) on the same PR. Feature-dev, Code Review, and Shipyard all implement variations.

2. **MCP as the integration layer**: every high-install plugin uses MCP for external service access. MCP is the de facto plugin integration standard.

3. **Context injection at query time**: Context7's pattern of pulling live docs at use time is the dominant answer to API hallucination. Generalizable to any knowledge source.

4. **Worktree isolation as parallelism primitive**: worktrees replacing manual multiple-terminal approaches. Plugins that create worktrees per task and clean up via WorktreeRemove hook are the clean emerging pattern.

5. **Hooks as enforcement layer**: shift from "guidelines in CLAUDE.md" to "rules enforced in PreToolUse hooks." What was advice is becoming code.

6. **TeammateIdle + TaskCompleted as quality gates**: hooks at teammate lifecycle events are the emerging quality gate API for multi-agent workflows.

7. **Async hooks for observability**: logging and metrics use `async: true` returns to avoid blocking agents. Non-intrusive observability is the pattern.

8. **Plugin data persistence for stickiness**: `${CLAUDE_PLUGIN_DATA}` enables stateful plugins (memory, learned preferences). Stateful plugins show higher retention than stateless.

---

## 8. Anti-Patterns Observed

| Anti-Pattern | Why Problematic |
|---|---|
| Broad PreToolUse hooks with no matcher | Matches everything, adds latency, creates unintended blocks |
| UserPromptSubmit hooks that spawn subagents without loop guard | Creates infinite recursive loops |
| Over-decomposition (15+ micro-prompts per feature) | Agent loses architectural coherence across chunks |
| Letting agent teams run unattended for hours | Wasted tokens on wrong directions; hard to recover |
| CLAUDE.md-only rules enforcement | Model can ignore; not enforced; hooks are reliable |
| Modifying tool_input by mutating original object | SDK ignores mutations; must return new object in updatedInput |

---

## 9. SEO Landscape (Plugin Ecosystem Discovery)

- **URL patterns**: `/blog/best-claude-code-plugins`, `/docs/en/[feature]`, `/changelog`
- **Content format**: comparison tables (plugin / installs / feature / use case) dominate high-ranking pages
- **Content depth**: 1,500-3,000 words for plugin roundup posts
- **Heading structure**: H1 = list format ("Top 10..."), H2 = plugin name, H3 = feature breakdown
- **Community index**: awesome-claude-code GitHub repo (200+ entries) is the primary discovery hub
- **Rich snippets**: how-to and FAQ schema appearing on official Claude Code docs pages

---

## 10. Concrete Features Maestro Should Add Next

Ranked by signal strength from this research.

### Tier 1 — High Signal, High Feasibility

**1. TeammateIdle + TaskCompleted hook handlers**
Maestro squads map directly to agent teams. These hooks are the quality gate API for multi-agent orchestration. Maestro should register handlers that enforce quality criteria (tests passing, code review complete, security scan clean) before the lead accepts task completion.

**2. PostCompact hook for automatic state checkpoint**
When compaction fires, Maestro should automatically write current squad/plan state to `.maestro/state.md`. Currently relies on explicit writes; hooks make it automatic and reliable.

**3. Worktree isolation per skill/agent**
Add `isolation: "worktree"` to Maestro agent frontmatter for skills touching multiple files. Use WorktreeCreate/WorktreeRemove hooks to sync state to/from `.maestro/`. Eliminates file-conflict risk in parallel squad execution.

**4. HTTP hook endpoint**
Expose a Maestro HTTP hook handler so CI systems and external services can send hook events to Maestro without shell subprocess overhead. Enables cloud-native integration.

**5. /maestro-watch skill wrapping /loop**
Ship a Maestro skill that wraps /loop for common monitoring patterns: PR readiness, deploy status, test suite stability. One-command autonomous monitoring.

### Tier 2 — Medium Signal, Architectural Investment

**6. Context injection at skill invocation**
A Maestro skill that injects project architecture docs, constraint lists, and interface contracts at skill invocation time (not just at session start via CLAUDE.md). Generalizes the Context7 pattern to internal project knowledge.

**7. Agent team orchestration skill**
A Maestro skill that creates an agent team with defined roles (researcher, implementer, reviewer, security-scanner) and wires TeammateIdle/TaskCompleted hooks to enforce the Maestro quality rubric before task close.

**8. PreToolUse security gate (enforced, not advisory)**
Default hook that blocks writes to .env, secrets directories, and config files outside approved paths. Moves security from CLAUDE.md advice to enforced hook rule.

**9. Async observability hooks**
All Maestro hooks should emit async telemetry to `.maestro/logs/` using `async: true` returns. Enables post-session analysis without blocking agent execution.

**10. MCP elicitation for missing config**
Use MCP elicitation to prompt for missing Maestro config values mid-session rather than failing silently or using defaults.

### Tier 3 — Community-Driven, Lower Confidence

**11. agents.md cross-tool compatibility**
Community is pushing for a cross-tool standard. Maestro could emit agents.md alongside CLAUDE.md to participate in the emerging ecosystem.

**12. Persistent squad memory via ${CLAUDE_PLUGIN_DATA}**
Use persistent plugin data to store squad-level learned context (preferred patterns, flagged issues) across Maestro updates.

**13. Skill effort and maxTurns metadata**
Tag Maestro skills with `effort` and `maxTurns` frontmatter so heavy orchestration skills do not exhaust token budgets on simple runs.

---

## Sources

- [Claude Code Changelog](https://code.claude.com/docs/en/changelog)
- [Claude Code v2.1.77 Release Notes](https://claude-world.com/articles/claude-code-2177-release/)
- [Agent SDK Hooks Reference](https://platform.claude.com/docs/en/agent-sdk/hooks)
- [Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Top 10 Claude Code Plugins — Firecrawl](https://www.firecrawl.dev/blog/best-claude-code-plugins)
- [Top 10 Plugins — Composio](https://composio.dev/content/top-claude-code-plugins)
- [Claude Code Plugin Marketplace](https://claudemarketplaces.com/)
- [Awesome Claude Code — GitHub](https://github.com/hesreallyhim/awesome-claude-code)
- [Claude Code Reddit: Developer Usage 2026](https://www.aitooldiscovery.com/guides/claude-code-reddit)
- [Claude Code vs Codex 2026 — Dev.to](https://dev.to/_46ea277e677b888e0cd13/claude-code-vs-codex-2026-what-500-reddit-developers-really-think-31pb)
- [Claude Code Hooks: 12 Events + CI/CD Patterns — Pixelmojo](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns)
- [Agentic Engineering Patterns — Simon Willison](https://simonwillison.net/2026/Feb/23/agentic-engineering-patterns/)
- [Agentic AI Coding Best Practices — CodeScene](https://codescene.com/blog/agentic-ai-coding-best-practice-patterns-for-speed-with-quality)
- [Agentic Coding Best Practices 2026 — Medium](https://abdus-muwwakkil.medium.com/agentic-coding-best-practices-fc167be3f7d5)
- [8 Trends Shaping Software Engineering 2026 — Anthropic via Tessl](https://tessl.io/blog/8-trends-shaping-software-engineering-in-2026-according-to-anthropics-agentic-coding-report/)
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Running Claude Agents in Production — Medium](https://medium.com/@hugolu87/how-to-run-claude-agents-in-production-using-the-claude-sdk-756f9d3c93d8)
- [Apple Xcode + Claude Agent SDK](https://www.anthropic.com/news/apple-xcode-claude-agent-sdk)
- [Worktree Isolation Guide — Claudefa.st](https://claudefa.st/blog/guide/development/worktree-guide)
- [Shipyard Multi-Agent Orchestration](https://shipyard.build/blog/claude-code-multi-agent/)
- [Claude Code Hooks Multi-Agent Observability — GitHub](https://github.com/disler/claude-code-hooks-multi-agent-observability)
