# Claude Platform Features — March 2026
## Research for Maestro Plugin Integration

**Researched:** 2026-03-18
**Researcher:** Researcher Agent (claude-sonnet-4-6)
**Scope:** New Claude Code and Anthropic platform features that Maestro should integrate with natively.

---

## Executive Summary

Six major platform areas have launched or matured since Maestro was last updated. The most impactful for an autonomous orchestrator are: (1) **Agent Teams** — native multi-agent coordination that partially overlaps Maestro's manual swarm logic; (2) **Remote Control** — session bridging that Maestro's hooks should advertise; (3) a new **hook event surface** with 12+ new events including `TeammateIdle`, `TaskCompleted`, `WorktreeCreate/Remove`, `ConfigChange`, and `Elicitation`; (4) **background agents** with `isolation: worktree`; (5) **Agent SDK** reaching maturity with compaction, tool search, and in-process hooks; and (6) **Cowork** — a knowledge-work desktop surface that uses the same plugin architecture.

---

## 1. Claude Code Agent Teams (Native)

**Status:** Experimental, disabled by default. Shipped in v2.1.32 with Claude Opus 4.6.
**Enable:** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `settings.json` or environment.
**Minimum version:** Claude Code v2.1.32+

**Source:** https://code.claude.com/docs/en/agent-teams

### Architecture

| Component | Role |
|---|---|
| Team lead | Main Claude Code session; creates team, spawns teammates, coordinates work |
| Teammates | Separate Claude Code instances, each with 200K token context window |
| Task list | Shared list of work items; teammates self-claim or lead assigns |
| Mailbox | Messaging system for direct agent-to-agent communication |

State is stored locally:
- Team config: `~/.claude/teams/{team-name}/config.json`
- Task list: `~/.claude/tasks/{team-name}/`

The `config.json` `members` array contains each teammate's `name`, `agentId`, and `agentType`. Teammates can read this file to discover peers.

### Key Behaviors

- Teammates load the same project context as a regular session: `CLAUDE.md`, MCP servers, and skills
- Teammates do NOT inherit the lead's conversation history
- Teammates inherit the lead's permission mode (including `--dangerously-skip-permissions`)
- Task claiming uses file locking to prevent race conditions
- When a teammate completes a dependency, blocked tasks unblock automatically
- Idle notifications are delivered to the lead automatically (no polling)
- Team size guidance: 3-5 teammates per task set; 5-6 tasks per teammate

### Display Modes

- `in-process` (default): all teammates in one terminal; `Shift+Down` to cycle
- `tmux` / `iTerm2`: split panes, one per teammate
- Configured via `teammateMode` in `settings.json` or `--teammate-mode` flag

### Hook Events for Agent Teams

| Event | Trigger | Exit code 2 behavior |
|---|---|---|
| `TeammateIdle` | Teammate about to go idle | Send feedback, keep teammate working |
| `TaskCompleted` | Task being marked complete | Prevent completion, send feedback |

As of v2.1.47, `TeammateIdle` and `TaskCompleted` support `{"continue": false, "stopReason": "..."}` for graceful teammate shutdown.

### Limitations (Known, March 2026)

- No session resumption for in-process teammates (`/resume`, `/rewind` don't restore them)
- Task status can lag; manual nudges sometimes required
- One team per lead session
- No nested teams (teammates cannot spawn sub-teams)
- Lead is fixed for the team's lifetime
- Split-pane mode not supported in VS Code integrated terminal, Windows Terminal, or Ghostty

### Relationship to Maestro's Swarm

Maestro's existing swarm/delegation skills pre-date Agent Teams and implement coordination manually via prompt engineering. Agent Teams is now the platform-native approach. The key difference: in Maestro's model, subagents report only to the lead. In Agent Teams, teammates can message each other directly via the mailbox system. Agent Teams is strictly superior for collaborative exploration tasks; Maestro's subagent approach is still better for simple focused tasks.

---

## 2. Remote Control (Claude Dispatch)

**Status:** Generally available on all plans (Pro, Max, Team, Enterprise).
**Note:** Team/Enterprise require admin to enable toggle at `claude.ai/admin-settings/claude-code`.
**Minimum version:** Claude Code v2.1.51+
**API key auth NOT supported** — requires claude.ai OAuth.

**Source:** https://code.claude.com/docs/en/remote-control

### What It Is

Remote Control bridges a local Claude Code session running on your machine to:
- `claude.ai/code` (web)
- Claude iOS app
- Claude Android app

The session runs entirely locally. No filesystem data moves to the cloud. The web/mobile surfaces are a streaming window into the local process.

### Start Modes

| Mode | Command | Notes |
|---|---|---|
| Server (dedicated) | `claude remote-control` | Stays running, accepts concurrent connections |
| Interactive + remote | `claude --remote-control` or `claude --rc` | Full local session also available remotely |
| From existing session | `/remote-control` or `/rc` slash command | Carries over current conversation history |

### Server Mode Flags

| Flag | Description |
|---|---|
| `--name "My Project"` | Custom session title in claude.ai/code list |
| `--spawn <mode>` | `same-dir` (default) or `worktree` (each remote session gets isolated git worktree) |
| `--capacity <N>` | Max concurrent sessions (default 32) |
| `--verbose` | Detailed connection logs |
| `--sandbox` / `--no-sandbox` | Filesystem/network isolation |

The `--spawn worktree` mode is particularly relevant for Maestro: it gives each remote session its own git worktree automatically, enabling true parallelism without merge conflicts.

### Security Model

- Outbound HTTPS only; no inbound ports opened
- Short-lived credentials scoped to single purpose
- Traffic routed through Anthropic API over TLS
- Session registered via `ANTHROPIC_API_KEY`-equivalent OAuth token

### Reconnection Behavior

As of v2.1.76, reconnection after laptop wake completes in seconds (previously up to 10 minutes). Sessions survive network drops and auto-reconnect.

### VSCode Extension

As of v2.1.79, `/remote-control` works from the VSCode extension to bridge VSCode sessions to `claude.ai/code`.

---

## 3. Hook Events — Complete Inventory (March 2026)

**Source:** https://code.claude.com/docs/en/hooks-guide

All 21 hook events as of March 2026:

| Event | Matcher field | When it fires | Can block? |
|---|---|---|---|
| `SessionStart` | session source (`startup`, `resume`, `clear`, `compact`) | Session begins or resumes | No (stdout injected as context) |
| `UserPromptSubmit` | none | User submits prompt, before Claude processes | Yes (exit 2) |
| `PreToolUse` | tool name (regex) | Before a tool call | Yes (exit 2 or JSON `permissionDecision: "deny"`) |
| `PermissionRequest` | tool name (regex) | When permission dialog would appear | Yes (JSON `decision.behavior: "allow/deny"`) |
| `PostToolUse` | tool name (regex) | After tool call succeeds | Yes (JSON `decision: "block"`) |
| `PostToolUseFailure` | tool name (regex) | After tool call fails | No |
| `Notification` | notification type (`permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`) | When Claude sends a notification | No |
| `SubagentStart` | agent type | When a subagent is spawned | No |
| `SubagentStop` | agent type | When a subagent finishes | No |
| `Stop` | none | Claude finishes responding | Yes (prompt/agent hooks can force continuation) |
| `StopFailure` | error type (`rate_limit`, `authentication_failed`, `billing_error`, etc.) | Turn ends due to API error | No (output/exit ignored) |
| `TeammateIdle` | none | Agent Teams teammate about to go idle | Yes (exit 2 sends feedback) |
| `TaskCompleted` | none | Agent Teams task being marked complete | Yes (exit 2 prevents completion) |
| `InstructionsLoaded` | load reason (`session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact`) | CLAUDE.md or `.claude/rules/*.md` loaded | No |
| `ConfigChange` | config source (`user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills`) | Config file changes during session | Yes (exit 2 or `decision: "block"`) |
| `WorktreeCreate` | none | Worktree created via `--worktree` or `isolation: "worktree"` | Replaces default git behavior |
| `WorktreeRemove` | none | Worktree removed at session exit or subagent finish | No |
| `PreCompact` | `manual` or `auto` | Before context compaction | No |
| `PostCompact` | `manual` or `auto` | After compaction completes | No |
| `Elicitation` | MCP server name | MCP server requests user input | Yes (intercept and override) |
| `ElicitationResult` | MCP server name | User responds to MCP elicitation | Yes (modify before sending back to server) |
| `SessionEnd` | reason (`clear`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other`) | Session terminates | No |
| `Setup` | — | Via `--init`, `--init-only`, or `--maintenance` flags | — |

### Hook Types

| Type | Description |
|---|---|
| `command` | Shell command (stdin=JSON, stdout=decision, exit code controls behavior) |
| `http` | POST JSON to URL, receive JSON response. Headers support `$VAR` interpolation via `allowedEnvVars`. |
| `prompt` | Single LLM call (Haiku by default); returns `{"ok": true/false, "reason": "..."}` |
| `agent` | Multi-turn subagent with tool access; 60s timeout, 50 tool-use turns max |

### Async Hooks

Set `async: true` to run a hook in the background without blocking Claude's execution (released January 2026).

### Hook Input Fields New in 2026

As of v2.1.69:
- `agent_id` — present on subagent hook events
- `agent_type` — present on subagent and `--agent` events
- `worktree` — object with `name`, `path`, `branch` (present in status line hook commands)

As of v2.1.47:
- `last_assistant_message` — added to `Stop` and `SubagentStop` hook inputs

### Maestro's Current Hook Coverage vs Full Inventory

Maestro currently implements: `Stop`, `Notification`, `StopFailure`, `PostCompact`, plus branch guard via `PreToolUse`.

Not yet used by Maestro: `TeammateIdle`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `ConfigChange`, `InstructionsLoaded`, `Elicitation`, `ElicitationResult`, `UserPromptSubmit`, `SessionEnd`, `SubagentStart`, `SubagentStop`.

---

## 4. Claude Agent SDK (Formerly Claude Code SDK)

**Status:** Renamed from Claude Code SDK. GA for Python and TypeScript.
**Python:** `pip install claude-agent-sdk`
**TypeScript:** `npm install @anthropic-ai/claude-agent-sdk`
**GitHub:** https://github.com/anthropics/claude-agent-sdk-python and `-typescript`

**Source:** https://platform.claude.com/docs/en/agent-sdk/overview

### Core Pattern

```python
from claude_agent_sdk import query, ClaudeAgentOptions

async for message in query(
    prompt="...",
    options=ClaudeAgentOptions(allowed_tools=["Read", "Edit", "Bash"]),
):
    print(message)
```

The SDK exposes the same agent loop, tools, and context management as Claude Code CLI — it IS Claude Code, as a library.

### Built-in Tools

`Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `WebSearch`, `WebFetch`, `AskUserQuestion`

### In-Process Hooks (SDK-Specific)

SDK hooks are Python/TypeScript callback functions, not shell commands. They implement the same event surface as the CLI but as in-process callbacks passed to `ClaudeAgentOptions(hooks={...})`.

```python
async def log_file_change(input_data, tool_use_id, context):
    file_path = input_data.get("tool_input", {}).get("file_path", "unknown")
    ...
    return {}

options = ClaudeAgentOptions(
    hooks={"PostToolUse": [HookMatcher(matcher="Edit|Write", hooks=[log_file_change])]}
)
```

Available hook events in SDK: `PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, `SessionEnd`, `UserPromptSubmit`, and others.

### Subagents in SDK

Custom agents are defined with `AgentDefinition` and passed via `agents` dict. The main agent calls them via the `Agent` tool (must be in `allowedTools`).

```python
ClaudeAgentOptions(
    allowed_tools=["Read", "Glob", "Agent"],
    agents={
        "code-reviewer": AgentDefinition(
            description="...", prompt="...", tools=["Read", "Glob"]
        )
    }
)
```

### Sessions and Resume

Sessions are identified by `session_id` from the `init` system message (`message.subtype == "init"`). Pass `resume=session_id` to `ClaudeAgentOptions` to continue with full context.

### Filesystem-Based Configuration

Set `setting_sources=["project"]` to enable:
- `CLAUDE.md` project memory
- `.claude/skills/` Skills
- `.claude/commands/*.md` slash commands
- `plugins` option for programmatic plugin loading

### New in 2026: SDK Rate Limit Types

As of v2.1.50:
- `SDKRateLimitInfo` and `SDKRateLimitEvent` types expose rate limit status including utilization, reset times, and overage info
- `supportsEffort`, `supportedEffortLevels`, `supportsAdaptiveThinking` model info fields

### Compaction API (Platform Level)

As of February 5, 2026 — available on Opus 4.6 via the Messages API (`/v1/messages`). Provides server-side context summarization for effectively infinite conversations. Claude Code's `/compact` and auto-compact use this internally. Plugins using the Agent SDK should design for compaction-aware workflows.

**Source:** https://platform.claude.com/docs/en/release-notes/overview

### Tool Search (GA as of February 17, 2026)

The tool search tool allows Claude to dynamically discover and load tools on-demand from large catalogs. Claude Code's MCP Tool Search feature uses this to enable lazy loading, reducing context usage by up to 95%. No beta header required as of Feb 17.

---

## 5. Plugin System — New Capabilities (2026)

**Source:** https://code.claude.com/docs/en/plugins

### New Plugin Manifest Fields (v2.1.78)

Agent frontmatter in plugin-shipped agents now supports:
- `effort` — controls model effort level for this agent
- `maxTurns` — limits turns
- `disallowedTools` — agent-level tool restrictions

### Plugin Persistent State (v2.1.78)

New variable: `${CLAUDE_PLUGIN_DATA}` — persistent state directory for the plugin that survives plugin updates. `/plugin uninstall` prompts before deleting it. This enables plugins to store cross-session state without relying on project directories.

### Plugin Default Settings (v2.1.49)

Plugins can ship a `settings.json` at the plugin root. Currently only the `agent` key is supported — activates one of the plugin's custom agents as the main thread, changing Claude Code's default behavior when the plugin is enabled.

```json
{
  "agent": "maestro-orchestrator"
}
```

### Plugin Variables

| Variable | Version | Description |
|---|---|---|
| `${CLAUDE_PLUGIN_DATA}` | v2.1.78 | Plugin persistent state directory (survives updates) |
| `${CLAUDE_SKILL_DIR}` | v2.1.69 | Skill's own directory (for self-referencing in SKILL.md) |

### Plugin Source Types

- `git-subdir` (v2.1.69) — point to a subdirectory within a git repo

### MCP Deduplication (v2.1.71)

Plugin-provided MCP servers that duplicate a manually-configured server (same command/URL) are automatically skipped. Plugins no longer need to worry about conflicting with user's own MCP configurations.

### Hot Reload

`/reload-plugins` reloads all plugin components (commands, skills, agents, hooks, MCP servers, LSP servers) without restarting Claude Code. Available since v2.1.69.

### Cowork Compatibility

Cowork (Claude Desktop's agentic mode) uses the same plugin architecture as Claude Code. Plugins built for Claude Code are compatible with Cowork. The plugin system is the unification point between Claude Code (developer terminal) and Cowork (knowledge worker desktop).

**Source:** https://claude.com/product/cowork (official page), https://claude.com/plugins (official plugin directory)

---

## 6. Cowork — What It Is

**Status:** Research Preview. Available on Pro ($20/mo), Max ($100-$200/mo), Team ($30/user/mo), Enterprise.
**Platforms:** macOS (initial), Windows (February 10, 2026).

**Sources:**
- https://claude.com/blog/cowork-research-preview
- https://claude.com/product/cowork
- https://support.claude.com/en/articles/13345190-get-started-with-cowork

### What Cowork Is

Cowork is Claude Code's agentic engine exposed through Claude Desktop for knowledge work (documents, files, research) rather than coding. It is not a separate product — it runs the same sub-agent coordination architecture that powers Claude Code, accessible without opening a terminal.

Key capabilities:
- Direct local file access (read/write) without manual uploads
- Sub-agent coordination for parallel workstreams
- Scheduled tasks (on-demand or recurring cadence)
- Task-based workflows (describe outcome, step away, return to completed work)

### Plugin Compatibility

The plugin system is shared. Plugins installed in Claude Code are available in Cowork. No separate Cowork plugin format exists. The official plugin directory at `claude.com/plugins` lists plugins that work across both surfaces.

### Implications for Maestro

Maestro skills, agents, and hooks work in Cowork without modification. However, Maestro's current skills are developer-workflow-specific (git, CI, code review). Cowork users are knowledge workers, not developers. This opens a potential expansion path but is out of scope for the current research.

---

## 7. New Models and Platform APIs

**Source:** https://platform.claude.com/docs/en/release-notes/overview

### Current Model Lineup (March 2026)

| Model | Context | Key capability |
|---|---|---|
| Claude Opus 4.6 | 1M tokens (GA) | Best for complex agentic tasks, long-horizon work. Uses adaptive thinking by default. |
| Claude Sonnet 4.6 | 1M tokens (GA) | Balanced speed/intelligence, improved agentic search |
| Claude Haiku 4.5 | Standard | Fastest, cost-sensitive deployments |

**Retired:** Claude 3 Opus (Jan 2026), Sonnet 3.7 and Haiku 3.5 (Feb 2026), Claude 3 Haiku (deprecating April 19, 2026)

### 1M Context Window (GA March 13, 2026)

The 1M token context window is now GA for Opus 4.6 and Sonnet 4.6 with no beta header required. Standard pricing applies; long-context pricing only above 200K tokens. Media limit raised from 100 to 600 images/PDF pages per request.

Maestro's DNA currently routes planning to `opus` — this now means 1M context available by default on Max, Team, and Enterprise plans (enabled in Claude Code v2.1.75+).

### Effort System (GA)

The `effort` parameter is GA (no beta header). Levels: `low`, `medium` (default for Max/Team), `high`. Replaces `budget_tokens` for thinking depth control on Opus 4.6 and Sonnet 4.6. Agent frontmatter now supports `effort` field (v2.1.78).

### Fast Mode (Opus 4.6)

Up to 2.5x faster output token generation via `speed` parameter. Research preview; waitlist at `claude.com/fast-mode`. Up to 2x premium pricing.

### Automatic Caching (February 19, 2026)

Single `cache_control` field in request body automatically manages cache point advancement as conversations grow. Available on Claude API and Azure AI Foundry (preview). Reduces manual breakpoint management for long Maestro sessions.

### Compaction API (GA on Opus 4.6)

Server-side context summarization. Claude Code uses this for `/compact` and auto-compact. Relevant for Maestro's long-running opus-loop and dev-loop sessions.

### Models API Enhancement (March 18, 2026)

`GET /v1/models` now returns `max_input_tokens`, `max_tokens`, and a `capabilities` object per model. Plugins can query this to discover model capabilities at runtime.

---

## 8. New Slash Commands and Settings

**Source:** https://code.claude.com/docs/en/changelog

### New Commands Relevant to Maestro

| Command | Version | Description |
|---|---|---|
| `/loop <interval> <prompt>` | v2.1.71 | Run prompt or slash command on recurring interval |
| `/remote-control [name]` | v2.1.79 | Bridge current session to claude.ai/code |
| `/reload-plugins` | v2.1.69 | Activate pending plugin changes without restart |
| `/effort [low\|medium\|high\|auto]` | v2.1.76 | Set model effort level |
| `/branch` | v2.1.77 | Renamed from `/fork` (alias kept) |
| `/plan <description>` | v2.1.72 | Enter plan mode with immediate task description |
| `/debug` | v2.1.73 | Toggle debug logging mid-session |
| `/color` | v2.1.75 | Set prompt bar color for session (multi-user visibility) |

### New Settings Relevant to Maestro

| Setting | Version | Description |
|---|---|---|
| `teammateMode` | v2.1.32 | `"auto"`, `"in-process"`, or `"tmux"` |
| `autoMemoryDirectory` | v2.1.74 | Custom directory for auto-memory storage |
| `includeGitInstructions` | v2.1.69 | Remove built-in commit/PR workflow instructions |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | v2.1.32 | Enable Agent Teams feature |
| `CLAUDE_CODE_DISABLE_CRON` | v2.1.72 | Stop scheduled cron jobs mid-session |
| `CLAUDE_CODE_PLUGIN_SEED_DIR` | v2.1.79 | Now supports multiple directories (path delimiter) |

### Worktree Isolation for Subagents (v2.1.50)

Agent definitions support `isolation: "worktree"` to run in a temporary git worktree. The `--worktree` / `-w` CLI flag starts Claude in an isolated worktree. `WorktreeCreate` and `WorktreeRemove` hook events allow custom VCS setup/teardown.

Sparse checkout: `worktree.sparsePaths` setting (v2.1.76) enables git sparse-checkout for large monorepos.

### Background Agents (v2.1.49)

Agent definitions support `background: true` to always run as background tasks. Pressing ESC no longer kills background agents. Killing a background agent preserves partial results in conversation context (v2.1.76).

---

## 9. Breaking Changes Maestro Must Handle

**Source:** https://code.claude.com/docs/en/changelog

| Change | Version | Impact on Maestro |
|---|---|---|
| `/fork` renamed to `/branch` | v2.1.77 | Any command docs referencing `/fork` should be updated (alias works but misleading) |
| `agent` tool `resume` parameter removed | v2.1.77 | Use `SendMessage({to: agentId})` instead. Any Maestro agent code using `resume` in Agent tool is broken. |
| Custom command argument syntax | v2.1.19 | Changed from `$ARGUMENTS.0` to `$ARGUMENTS[0]` — bracket syntax. Maestro templates must use bracket syntax. |
| `--plugin-dir` single path per flag | v2.1.76 | Only one path per `--plugin-dir` instance; use repeated flags for multiple directories |
| Effort levels simplified | v2.1.71 | `max` effort level removed. Now low/medium/high only. Any Maestro config referencing `max` effort must update. |
| Managed settings Windows path | v2.1.75 | `C:\ProgramData\ClaudeCode\managed-settings.json` fallback removed |

---

## 10. Competitor Matrix — How Maestro Compares to Native Features

| Capability | Maestro (current) | Native Claude Code (March 2026) |
|---|---|---|
| Multi-agent orchestration | Manual via prompt engineering in skills | Agent Teams (native, experimental) |
| Parallel subagents | Delegation skill + worktrees | `isolation: "worktree"` in agent frontmatter + `--worktree` flag |
| Background tasks | Long-running sessions | `background: true` in agent frontmatter |
| Quality gates | Stop hook + QA reviewer agent | `TeammateIdle` + `TaskCompleted` hooks |
| Remote access | None | Remote Control (all plans) |
| Session scheduling | None | `/loop` command + cron tools |
| Plugin persistent state | Files in project dir | `${CLAUDE_PLUGIN_DATA}` (survives updates) |
| Config audit | Branch guard hook | `ConfigChange` hook (native) |
| Context re-injection | PostCompact hook (exists) | `SessionStart` with `compact` matcher (also exists) |
| MCP conflict avoidance | Manual | Auto-dedup in v2.1.71 |

---

## Actionable Findings for Maestro

The following findings are stated as facts observed from official documentation. Strategic decisions are out of scope for this report.

### Finding 1: Agent Teams hooks are not implemented in Maestro

Maestro's current `hooks/hooks.json` does not register `TeammateIdle` or `TaskCompleted`. These hooks are the official mechanism to enforce quality gates when running Agent Teams. Without them, teammates can go idle without QA validation.

### Finding 2: The Agent tool API changed

The `resume` parameter was removed from the Agent tool in v2.1.77. Any Maestro agent or skill that uses `agent(resume=...)` is broken on current Claude Code versions. The replacement is `SendMessage({to: agentId})`.

### Finding 3: Ten hook events exist that Maestro does not use

Events with clear orchestrator relevance that Maestro does not currently register: `WorktreeCreate`, `WorktreeRemove`, `ConfigChange`, `InstructionsLoaded`, `SubagentStart`, `SubagentStop`, `SessionEnd`, `Elicitation`, `ElicitationResult`, `UserPromptSubmit`.

### Finding 4: `${CLAUDE_PLUGIN_DATA}` enables cross-session plugin state

Maestro currently stores state in `.maestro/` inside the project. `${CLAUDE_PLUGIN_DATA}` is a plugin-scoped persistent directory that survives plugin updates and is managed by Claude Code. This is the correct location for plugin-level state (trust scores, token ledger, build logs) as opposed to project-level state.

### Finding 5: Plugin `settings.json` `agent` key can set Maestro as default agent

When `settings.json` at the plugin root contains `{"agent": "maestro-orchestrator"}`, Maestro's orchestrator agent becomes the default Claude Code behavior when the plugin is enabled. This is a zero-click activation path for users who install Maestro.

### Finding 6: `/loop` command provides scheduling without external cron

The `/loop 5m check deploy status` command runs a prompt on a recurring interval within a session. Maestro's scheduled workflows currently require external process managers. `/loop` provides this natively.

### Finding 7: Remote Control `--spawn worktree` is relevant to Maestro's parallel execution model

When Maestro runs multi-story parallel work via Remote Control server mode, `--spawn worktree` gives each connected session its own git worktree automatically. This eliminates merge conflicts in distributed Maestro workflows without manual worktree setup.

### Finding 8: `isolation: "worktree"` in agent frontmatter replaces manual worktree scripts

Maestro has worktree setup scripts. Agent definitions with `isolation: "worktree"` accomplish the same goal declaratively with automatic cleanup via the `WorktreeRemove` hook.

### Finding 9: Effort levels must be updated

Maestro's agent definitions may reference `max` effort level, which was removed in v2.1.71. Valid values are now `low`, `medium`, `high`. Opus 4.6's default for Max/Team plans is `medium`.

### Finding 10: 1M context is now the default for Opus 4.6 on paid plans

Maestro's opus-loop and research agents operate within a larger context budget than at design time. Long-running context compaction strategies may be less necessary for single-session tasks, but remain necessary for multi-session and Agent Teams scenarios.

---

## Sources

- [Agent Teams documentation](https://code.claude.com/docs/en/agent-teams)
- [Remote Control documentation](https://code.claude.com/docs/en/remote-control)
- [Hooks guide](https://code.claude.com/docs/en/hooks-guide)
- [Plugin creation guide](https://code.claude.com/docs/en/plugins)
- [Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Platform release notes](https://platform.claude.com/docs/en/release-notes/overview)
- [Cowork product page](https://claude.com/product/cowork)
- [Get started with Cowork](https://support.claude.com/en/articles/13345190-get-started-with-cowork)
- [Claude Code March 2026 updates (third-party summary)](https://pasqualepillitteri.it/en/news/381/claude-code-march-2026-updates)
- [Claude Code changelog (third-party)](https://claudefa.st/blog/guide/changelog)
- [Introducing Cowork blog post](https://claude.com/blog/cowork-research-preview)
- [Remote Control Simon Willison analysis](https://simonwillison.net/2026/Feb/25/claude-code-remote-control/)
- [Agent Teams Medium overview](https://medium.com/@richardhightower/claude-code-agent-teams-multiple-claudes-working-together-a75ff370eccb)
- [VentureBeat Remote Control launch coverage](https://venturebeat.com/orchestration/anthropic-just-released-a-mobile-version-of-claude-code-called-remote)
