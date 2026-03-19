# Maestro Wave 7 — Competitive Research

**Date:** 2026-03-18
**Researcher:** Claude Sonnet 4.6
**Scope:** What is MISSING or could be BETTER entering Wave 7

---

## Executive Summary

Wave 7 has three high-signal areas:

1. **Hook gap** — Claude Code added 10+ new hook events since Wave 6 that Maestro does not wire. These are zero-cost wins (shell scripts) that unlock observability, security auditing, and quality gates.
2. **Native agent teams integration** — Claude Code's own Agent Teams feature (released Feb 2026) overlaps with Maestro's hand-rolled multi-instance coordination but offers capabilities Maestro cannot easily replicate (direct teammate messaging, split-pane tmux, task dependency locking). Maestro should bridge to it rather than duplicate it.
3. **DX debt** — The developer community's loudest complaint is AI tools that feel unreliable on complex, multi-session tasks. Specific patterns (session cost transparency, `/effort` integration, context health warnings, AGENTS.md cross-tool compatibility) are all achievable in one wave.

---

## 1. Hook Coverage Gap

### What Claude Code has that Maestro does not wire

The current `hooks/hooks.json` only handles: `Stop`, `Notification`, `TeammateIdle`, `TaskCompleted`.

Claude Code now ships 22 distinct hook events. The following are unwired and represent concrete capability gaps:

| Hook Event | Added In | What Maestro Loses By Ignoring It | Implementation Type |
|---|---|---|---|
| `PreToolUse` | Core | No command blocking, no branch-guard for writes to protected files | Shell script |
| `PostToolUse` | Core | No automatic formatter, no audit log of file changes | Shell script |
| `PostToolUseFailure` | Core | Tool failures are silent — no retry logic, no alert | Shell script |
| `SessionStart` | Core | No context re-injection on resume or compact | Shell script |
| `SessionEnd` | Core | No cleanup of temp files, no session summary | Shell script |
| `UserPromptSubmit` | Core | No code-intel context injection at prompt time | Shell script |
| `StopFailure` | v2.1.78 | API errors (rate limit, billing) are silent — no retry, no notification | Shell script |
| `InstructionsLoaded` | v2.1.69 | Cannot audit which CLAUDE.md files are loaded, cannot block unsafe rule files | Shell script |
| `ConfigChange` | v2.1.49 | Config modifications during a session go unlogged and unblocked | Shell script |
| `WorktreeCreate` | v2.1.50 | Cannot customize worktree setup for non-git VCS or sparse checkouts | Shell script |
| `WorktreeRemove` | v2.1.50 | Cannot run cleanup hooks when worktrees are deleted | Shell script |
| `PreCompact` | v2.1.76 | Cannot flush critical state to disk before context compaction | Shell script |
| `PostCompact` | v2.1.76 | Cannot re-inject context after compaction (already in post-compact-hook.sh but not in hooks.json) | Shell script |
| `Elicitation` | v2.1.76 | Cannot auto-answer MCP elicitations for known config values | Shell script |
| `ElicitationResult` | v2.1.76 | Cannot log or audit MCP elicitation responses | Shell script |
| `PermissionRequest` | Core | Cannot auto-approve safe known operations, reducing permission fatigue | Shell script |

**The most impactful unwired hooks for Wave 7:**

1. `StopFailure` — Users lose work silently on API errors. A hook that logs the error, sends a notification, and backs up the session state is a one-hour script.
2. `PreToolUse` + `PostToolUse` — The branch-guard skill already wants pre-tool protection. Moving it to the correct hook event (currently wired incorrectly or not at all) makes it reliable.
3. `InstructionsLoaded` — A security gate to warn when `.claude/rules/*.md` files load rules from unknown sources. Relevant for teams using shared plugin repos.
4. `PreCompact` — Silent memory flush before context compaction. The OpenClaw pattern (NO_REPLY agentic turn flushing state to `.maestro/memory/`) prevents state loss at context boundary.
5. `PermissionRequest` — Auto-approve the specific set of Maestro-safe operations to reduce permission dialogs during long autonomous runs.

**Source:** https://code.claude.com/docs/en/hooks-guide, https://code.claude.com/docs/en/changelog

---

## 2. New Claude Code Features Maestro Has Stubs For But No Wire-Up

These skills exist in `/skills/` as SKILL.md files but have no corresponding hook, command, or script wiring them into the plugin:

| Skill Directory | What It Needs to Be Active | Gap |
|---|---|---|
| `skills/http-hooks/` | An HTTP endpoint script + hooks.json entry with `"type": "http"` | HTTP hooks type not used in hooks.json at all |
| `skills/mcp-elicitation/` | An `Elicitation` hook entry in hooks.json | Not wired in hooks.json |
| `skills/scheduler/` | CronCreate tool calls in a setup script | No `/maestro schedule` command exists |
| `skills/agent-teams/` | Integration with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env | No environment config shipped |
| `skills/agents-md/` | Called from `auto-init` and `agent-teams` skills | Not called from auto-init SKILL.md |

### New Claude Code features with no Maestro skill or hook at all

| Feature | Version | What Maestro Could Do With It |
|---|---|---|
| `/effort` command + `--effort` CLI flag | v2.1.71 | Route model effort level based on story complexity: `low` for haiku tasks, `high` for opus planning sessions. Expose as `/maestro effort <level>` |
| `/loop` slash command | v2.1.71 | Document as recommended pattern for recurring health check monitoring |
| `CLAUDE_PLUGIN_DATA` variable | v2.1.78 | Plugin persistent data dir — use for soul/memory files that survive plugin updates |
| `agent memory` frontmatter field | v2.1.49 | Agent definitions can declare `memory: project` to persist memory per-agent |
| `background: true` agent frontmatter | v2.1.49 | Background agents for daemon-style tasks |
| `isolation: "worktree"` agent frontmatter | v2.1.49 | Per-agent worktree isolation without manual `--worktree` flag |
| `worktree.sparsePaths` setting | v2.1.76 | Large-monorepo support: check out only skill-relevant directories |
| `additionalContext` in `PreToolUse` hooks | v2.1.9 | Context injection at pre-tool time, not just at session start |
| `last_assistant_message` in Stop hooks | v2.1.47 | Stop hook can read the final assistant message — enables smarter continuation logic |
| `InstructionsLoaded` hook | v2.1.69 | Log which CLAUDE.md variants are active per session; security audit |
| `agent_id` / `agent_type` in hook inputs | v2.1.69 | Hooks can distinguish which subagent fired the event — enables per-agent audit trails |
| `claude plugin validate` CLI | v2.1.77 | Add to Maestro's doctor check — validates skill/agent/command frontmatter |
| `/remote-control` command | v2.1.79 | Document as supported remote access pattern for Maestro sessions |
| `autoMemoryDirectory` setting | v2.1.74 | Route auto-memory to `.maestro/memory/auto/` to keep memory organized |

**Source:** https://code.claude.com/docs/en/changelog (v2.1.9 through v2.1.79)

---

## 3. Competitive Gaps vs. OpenClaw / Cursor / AioX

### What competitors do that Maestro cannot (and is achievable with markdown + shell)

#### From OpenClaw

| Gap | OpenClaw Pattern | Maestro Implementation Path |
|---|---|---|
| Pre-compaction state flush | Silent NO_REPLY agentic turn before compaction writes MEMORY.md | `PreCompact` hook that calls a shell script dumping critical `.maestro/` state to a snapshot | New hook script |
| Daily ephemeral memory | `memory/YYYY-MM-DD.md` loaded at session start alongside permanent MEMORY.md | `SessionStart` hook with `compact` matcher — injects today's daily memory file into context | New hook script |
| Bootstrap char budget | Truncates injected files to 20k chars each, 150k total | Add `maxBootstrapChars` limit check in session-start-hook.sh to warn when context is too large | Modify existing script |
| Cron with exponential backoff | Job failure triggers 30s→1m→5m→15m→60m backoff stored in `~/.openclaw/cron/` | Add backoff state to scheduler skill's cron config file | Modify skill |
| Idle runtime eviction | RuntimeCache evicts sessions idle > threshold, prevents resource leak | Add session TTL check to heartbeat script | Modify existing script |

#### From Cursor (pain points that Maestro can address)

| Cursor Problem | Developer Complaint | Maestro Opportunity |
|---|---|---|
| Silent code reversion | March 2026 bug: cursor silently undid changes | `PostToolUse` audit log that checksums files after each Edit/Write; `StopFailure` hook backs up session state | New hooks |
| Request limit opacity | Users hit limits with no warning until hard failure | Token ledger already exists — surface it more prominently in stop-hook output | Modify stop-hook.sh |
| Complex task looping | Long refactors loop without finishing | `Stop` hook with `prompt` type (Claude Haiku) that checks if all requested tasks are done — blocks stop if not | New prompt-type hook |
| Version lag | Cursor on VSCode 1.92, official at 1.95 | Not applicable — Maestro rides Claude Code's latest version directly | N/A |

#### From AioX Core (previously researched, still unimplemented)

| Gap | Priority | Implementation Path |
|---|---|---|
| `UserPromptSubmit` code-intel context injection | High | Session-start-hook already exists; add UserPromptSubmit hook that extracts file-under-edit and injects dependency graph via `grep`/ripgrep | New hook script |
| `claude plugin validate` in doctor | Medium | Call `claude plugin validate` from doctor.md and report frontmatter errors | Modify commands/doctor.md |
| IDE fan-out sync (canonical source → Cursor/Gemini) | Low | `/maestro sync-ide` command already exists but needs agent definitions as source | Existing command |

#### From AGENTS.md Standard

AGENTS.md reached 60,000+ repositories and Linux Foundation backing as of December 2025. The `agents-md` skill exists but is not wired to `/maestro init` or any trigger.

**Gap:** Every `/maestro init` should produce an `agents.md` at project root. Cursor, Windsurf, Copilot, and Codex all read it. Without it, Maestro agents are invisible to non-Claude editors.

**Implementation:** One-line call from auto-init's SKILL.md: invoke `agents-md` skill after writing `.maestro/state.md`. No new code.

**Source:** https://agents.md, https://github.com/anthropics/claude-code/issues/31005 (3,000+ upvotes for AGENTS.md support)

---

## 4. Developer Experience Improvements

### Findings from community pain points

The Stack Overflow 2025 Developer Survey and CodeRabbit's AI code generation report surface three consistent DX problems with AI coding tools:

1. **Opacity on what the AI changed** — 45% of respondents cite "AI solutions that are almost right but not quite" as their top frustration. Developers want to know exactly what changed and why.
2. **No feedback on context health** — Long sessions degrade silently. Developers don't know when the AI is working from a polluted context window.
3. **Looping without progress** — AI agents that keep working but make circular changes waste time and budget.

**Maestro-specific DX improvements with clear implementation paths:**

| Improvement | What to Build | Type |
|---|---|---|
| Session cost display in stop hook | Append `Session cost: $X.XX | Tokens: Nin/Nout` to stop-hook.sh output | Modify stop-hook.sh |
| Context health warning | `PostToolUse` hook checks token count and warns at 70%/90% thresholds | New hook script |
| Change summary on stop | `Stop` hook reads `last_assistant_message` field and appends a one-line summary of what changed this turn | Modify stop-hook.sh |
| `/effort auto` wiring | Document in agent frontmatter: `effort: low/medium/high` based on agent tier | Modify agent definitions |
| `/loop` for health monitoring | Document `/loop 30m /maestro status` as the recommended pattern for continuous project monitoring | Update status.md command |
| Session naming | Use `--name` CLI flag in delegation scripts to give spawned agents human-readable names | Modify delegation scripts |

### Patterns from modern CLI tools (gh, bun, pnpm)

| Tool | Pattern | Maestro Adoption |
|---|---|---|
| `gh` | Every command shows clear before/after state, no silent successes | Maestro hooks should always echo a one-line status to stderr on any action taken |
| `bun` | Install shows package count + time + size delta | `/maestro status` should show skill count + hook count + last-modified timestamp |
| `pnpm` | Workspace awareness — commands scope to the right package automatically | Maestro should detect monorepo layout and scope agent context to the relevant workspace subdirectory |
| `gh` | `gh pr create` prompts for missing fields rather than failing | Use MCP elicitation (already in skills/mcp-elicitation/) to prompt for missing config rather than failing silently |

**Source:** https://stackoverflow.blog/2025/12/29/developers-remain-willing-but-reluctant-to-use-ai, https://www.coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report

---

## 5. Testing and Quality

### Current state
- `dna.md` explicitly documents: `Testing: None detected`
- `Commands: Test: N/A`
- No automated validation of skill frontmatter, hook JSON, or command schemas

### What the community does (and Maestro should adopt)

| Approach | Source | Maestro Implementation |
|---|---|---|
| `claude plugin validate` | Added in v2.1.77 | Run in CI and in `doctor.md` to catch broken frontmatter before users see failures | Modify doctor.md |
| Schema-validated hooks.json | Claude Code validates hook JSON on load | Add `jq` schema check in a test script — fail if any hook references a script that doesn't exist or isn't executable | New script: scripts/validate-hooks.sh |
| Smoke test per skill | LangChain State of Agent Engineering 2025: 52% of orgs run offline eval sets | Add a `tests/` directory with one golden-output `.md` file per core skill; a test runner (bash) compares structure | New: tests/ directory |
| Regression detection on hook changes | 89% of production agent teams use observability; catching regressions before deployment is the top barrier | A pre-commit hook that runs `scripts/validate-hooks.sh` catches broken hook configs before they land in `main` | New hook in hooks/hooks.json |
| Agent-based stop hook verification | Claude Code `type: "agent"` hooks spawn a subagent to verify conditions | Replace the prompt-type stop hook with a proper `type: "agent"` hook that reads `.maestro/state.md` and verifies task completion | Modify stop-hook definition |

### Specific tests worth building

1. **hooks.json schema test** — Every entry in `hooks.json` references a script that exists and is executable. Catches the most common plugin breakage.
2. **Skill frontmatter lint** — Every `SKILL.md` has a valid `name`, `description`, and no broken `requires:` bins that aren't available on a standard machine.
3. **Command smoke test** — Every `/maestro <command>` resolves to a command file and that file's frontmatter is valid.
4. **Agent definition test** — Agent `.md` files have valid `model`, `memory`, and `tools` frontmatter per the Claude Code spec.

**Source:** https://www.langchain.com/state-of-agent-engineering, https://arxiv.org/html/2602.16666v1

---

## 6. Structural Improvements (Not in Previous Research)

### AGENTS.md as a living artifact

The AGENTS.md standard now has backing from OpenAI, Anthropic, Google, and the Linux Foundation. Over 60,000 repos use it. Maestro's `agents-md` skill generates it, but no trigger calls it.

**Concrete gap:** Running `grep -r "agents-md" /skills/auto-init/` returns nothing. The auto-init skill does not invoke agents-md. Every Maestro project should have an `agents.md` at root.

### Plugin persistent state

`CLAUDE_PLUGIN_DATA` (added v2.1.78) gives plugins a directory that survives updates. Maestro's SOUL system currently writes to the project's `.maestro/` directory — the user has to manually carry it between projects.

**Opportunity:** Move the SOUL state, memory files, and user preferences to `${CLAUDE_PLUGIN_DATA}/` (a global directory). This makes the developer's Maestro identity portable across projects, like OpenClaw's `~/.openclaw/workspace/`.

### Effort-aware model routing

The model-router skill routes by task type (opus/sonnet/haiku). Claude Code's `--effort` flag adds a second dimension: within the same model, effort can be `low`, `medium`, or `high`. The current router ignores this.

**Opportunity:** Update agent definitions to include `effort` frontmatter:
- Planning/architecture agents: `effort: high`
- Implementation agents: `effort: medium`
- Review/QA agents: `effort: medium`
- Simple tasks (status, config reads): `effort: low`

This reduces token cost on routine tasks without changing the model tier.

### Prompt-type quality gate

Claude Code supports `"type": "prompt"` hooks that use Haiku to evaluate conditions. This is cheaper and faster than agent hooks for simple yes/no quality gates.

**Opportunity:** Replace the current stop-hook's manual task-completion check with a `type: "prompt"` hook:

```json
{
  "Stop": [{
    "hooks": [{
      "type": "prompt",
      "prompt": "Read .maestro/state.md. Check if the requested task is marked complete. If it is not complete or the file shows status 'in-progress', respond {\"ok\": false, \"reason\": \"Task not yet complete: [what remains]\"}."
    }]
  }]
}
```

This is more reliable than the current shell-script approach because it uses LLM judgment instead of regex parsing of state files.

---

## Competitor Matrix (Updated for Wave 7)

| Feature | OpenClaw | AioX Core | Ruflo | Maestro Wave 6 | Maestro Gap |
|---|---|---|---|---|---|
| Hook coverage (of 22 events) | ~18 | ~12 | ~17 | 4 (Stop, Notification, TeammateIdle, TaskCompleted) | 18 unhanded events |
| Pre-compaction state flush | Yes (PreCompact + NO_REPLY) | No | No | No | Add PreCompact hook |
| AGENTS.md generation | Yes (workspace) | No | No | Skill exists, not wired | Wire to auto-init |
| Session cost display | Yes (StatusBar) | Yes (CostTab) | No | Token ledger exists, not in stop output | Modify stop-hook |
| Effort-level routing | N/A (not Claude Code) | No | No | No | Add `effort` to agent frontmatter |
| Prompt-type quality gate | No | No | No | No | Add to hooks.json |
| Plugin persistent state | Yes (~/.openclaw/) | Yes (~/.aiox/) | No | No (writes to project only) | Use CLAUDE_PLUGIN_DATA |
| `claude plugin validate` in CI | No | No | No | No | Add to doctor.md |
| Cron scheduling | Yes (full cron + backoff) | No | Yes (11 workers) | Skill exists, not setup | Wire setup command |
| AGENTS.md standard compliance | Partial | No | No | Skill exists, not wired | Wire to auto-init |
| Remote control | No | No | No | remote-listener skill | Document /remote-control |

---

## Technical Patterns Worth Adopting

### Pattern: Async hook for side-effects

Claude Code SDK supports `"async": true` hook output — the agent proceeds immediately while the hook does logging/notification in the background. Maestro's notification hook should use this pattern to avoid blocking the agent loop on webhook delivery.

```bash
# In notification-hook.sh, return async JSON then do work in background
echo '{"async": true, "asyncTimeout": 10000}'
# ... rest of notification logic runs without blocking
```

### Pattern: `additionalContext` in `PreToolUse`

When Claude is about to edit a file, a `PreToolUse` hook can inject the file's import graph and test coverage via `additionalContext`. This is the AioX code-intel pattern — zero changes to agent prompts, the context arrives automatically.

### Pattern: `last_assistant_message` in Stop hooks

The Stop hook input now includes `last_assistant_message`. The stop-hook can read this to detect if the agent said "I'm done" vs. "I got stuck". Different exit text → different notification messages.

### Pattern: `agent_id` in subagent hooks

When delegation spawns a subagent, all hook events from that subagent include `agent_id`. The audit-log skill can use this to attribute file changes to specific agents without parsing transcript.

---

## Anti-Patterns to Avoid

### Anti-pattern 1: Wiring all 22 hooks by default

More hooks = more shell script overhead per turn. Only wire hooks for events that have a concrete action. Dead hooks that `exit 0` immediately still add latency.

**Rule:** A hook entry should only be added when there is a script with a real action behind it.

### Anti-pattern 2: Blocking hooks for non-critical notifications

The notification-hook and stop-hook currently run synchronously. If the Telegram bot or Slack webhook is slow, they delay the agent's response. Use async hook output (`"async": true`) for all notification delivery.

### Anti-pattern 3: Duplicating Agent Teams with hand-rolled scripts

Wave 6 built multi-instance coordination (instance-registry, branch-manager, merge-coordinator). Claude Code's native Agent Teams feature (v2.1.32) now provides task lists, direct teammate messaging, and file-lock coordination natively. Building on top of Agent Teams is better than maintaining parallel infrastructure.

**Rule:** Maestro's `agent-teams` skill should wrap Claude Code's `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` rather than replace it.

### Anti-pattern 4: Silent failure on missing config

When a skill needs a config value and it's missing, failing silently or printing a cryptic error is the pattern Cursor is criticized for. Use MCP elicitation (already built in `mcp-elicitation` skill) as the fallback — prompt inline and save the answer.

---

## SEO / Discoverability (for open-source visibility)

- GitHub issues show AGENTS.md support at 3,000+ upvotes with zero Anthropic response — Maestro shipping first-class AGENTS.md generation is a differentiation point with the community.
- Claude Code GitHub topics context: Maestro should ensure `agents`, `ai-agents`, `claude-code`, `plugin`, `orchestration`, `automation` are in the repo topics.
- The `claudeclaw.md` file in the repo root (visible in git status) is a novel positioning document. Make sure it's accurate and links to the plugin marketplace entry.

---

## Prioritized Wave 7 Findings

### P0 — Zero-new-code wins (wire existing things correctly)

1. Wire `agents-md` skill into `auto-init` — every init produces `agents.md`
2. Add `PostCompact` hook entry in `hooks.json` (the script exists at `post-compact-hook.sh`, it just isn't registered)
3. Add `effort` frontmatter to agent definitions (planning=high, impl=medium, QA=medium, haiku tasks=low)

### P1 — New hook scripts (< 1 day each)

4. `StopFailure` hook — log error type, send notification, back up session state
5. `PreCompact` hook — flush `.maestro/state.md` snapshot before context compaction
6. `PermissionRequest` hook — auto-approve the known-safe Maestro tool set
7. `PreToolUse` hook (file protection) — block writes to `.maestro/config.yaml`, `.env`, `hooks.json` unless user explicitly requested it

### P2 — Quality and testing (1–2 days)

8. `scripts/validate-hooks.sh` — verify every hooks.json entry points to an executable script
9. `doctor.md` update — call `claude plugin validate` as a check step
10. `tests/` directory — one smoke test per core skill (5–10 skills to start)
11. Prompt-type Stop hook — replace shell-regex task completion check with `type: "prompt"` Haiku evaluation

### P3 — DX improvements (0.5–1 day each)

12. Session cost in stop-hook.sh output — append cost line from token ledger data
13. Context health warning in PostToolUse — warn at 70% and 90% context usage
14. Move SOUL/memory to `CLAUDE_PLUGIN_DATA` — portable identity across projects
15. Document `/effort`, `/loop`, `/remote-control` as Maestro-native patterns in help.md

### P4 — Research-only (already known from previous waves, confirm progress)

16. Cron setup command — `/maestro schedule setup` to register configured schedules via CronCreate
17. HTTP hooks endpoint — wire the http-hooks skill to a local endpoint script
18. MCP elicitation wiring — add `Elicitation` hook entry for config value prompting

---

## Sources

- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code Changelog](https://code.claude.com/docs/en/changelog)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Claude Agent SDK Hooks](https://platform.claude.com/docs/en/agent-sdk/hooks)
- [Claude Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [OpenClaw GitHub](https://github.com/alizarion/openclaw-claude-code-plugin)
- [ClaudeCodeLog Changelog on X](https://x.com/ClaudeCodeLog/status/2032631384523641209)
- [AGENTS.md Standard](https://agents.md)
- [AGENTS.md GitHub Issue #31005 (3000+ upvotes)](https://github.com/anthropics/claude-code/issues/31005)
- [Stack Overflow 2025 Developer Survey](https://stackoverflow.blog/2025/12/29/developers-remain-willing-but-reluctant-to-use-ai-the-2025-developer-survey-results-are-here/)
- [CodeRabbit AI Code Generation Report](https://www.coderabbit.ai/blog/state-of-ai-vs-human-code-generation-report)
- [LangChain State of Agent Engineering](https://www.langchain.com/state-of-agent-engineering)
- [Cursor Problems 2026](https://vibecoding.app/blog/cursor-problems-2026)
- [OpenClaw Cron Jobs Guide](https://docs.openclaw.ai/automation/cron-jobs)
- [Arxiv: Towards a Science of AI Agent Reliability](https://arxiv.org/html/2602.16666v1)
- [Building ClaudeClaw on Claude Code (Medium)](https://medium.com/@mcraddock/building-claudeclaw-an-openclaw-style-autonomous-agent-system-on-claude-code-fe0d7814ac2e)
- [OpenClaw vs Claude Code Comparison](https://claudefa.st/blog/tools/extensions/openclaw-vs-claude-code)
- [Claude Code GitHub Actions Docs](https://code.claude.com/docs/en/github-actions)
- [Agent Teams Full Guide](https://claudefa.st/blog/guide/agents/agent-teams)
