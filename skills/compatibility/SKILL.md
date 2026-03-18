---
name: compatibility
description: "Hook parity table and migration guides across Claude Code, Gemini CLI, Codex CLI, and Cursor. Documents what works where, what degrades gracefully, and practical workarounds for missing features."
---

# Platform Compatibility Reference

Maestro is built on Claude Code's full feature set. This document records exactly what works on each supported platform, what degrades, and what is unavailable — so you can make honest decisions about where to run Maestro and what to expect.

Rating key:

| Rating | Meaning |
|--------|---------|
| **Full** | Feature works as documented |
| **Partial** | Feature exists but behaves differently or has gaps |
| **None** | No equivalent — the platform cannot support it |
| **Unknown** | Not yet verified |

---

## Hook Event Parity

Claude Code fires 15 lifecycle hooks. Other platforms either have a different hook API or no hooks at all.

| Hook Event | Claude Code | Gemini CLI | Codex CLI | Cursor |
|-----------|-------------|-----------|-----------|--------|
| `SessionStart` | Full | Partial | None | None |
| `Stop` | Full | Partial | None | None |
| `StopFailure` | Full | None | None | None |
| `SubagentStop` | Full | None | None | None |
| `PreToolUse` | Full | None | None | None |
| `PostToolUse` | Full | None | None | None |
| `Notification` | Full | None | None | None |
| `PostCompact` | Full | None | None | None |
| `InstructionsLoaded` | Full | Partial | None | None |
| `WorktreeCreate` | Full | None | None | None |
| `WorktreeRemove` | Full | None | None | None |
| `TeammateIdle` | Full | None | None | None |
| `TaskCompleted` | Full | None | None | None |
| `Elicitation` | Full | None | None | None |
| `ElicitationResult` | Full | None | None | None |

### Hook Notes by Platform

**Gemini CLI**
Gemini CLI supports a hooks-like mechanism via its extension API, but the event model is different. There is no `PreToolUse` event (no way to intercept and block a tool call before it runs). `SessionStart` and `Stop` equivalents exist but receive different payloads. `InstructionsLoaded` has a loose analogue when `GEMINI.md` is parsed at session start. Shell scripts registered as handlers work, but blocking semantics (returning a non-zero exit code to deny a tool call) are not supported.

**Codex CLI**
No hook system. Codex CLI is a command-execution model — it interprets instructions and runs commands, but there is no lifecycle event bus that can be subscribed to. Behavioral customization happens entirely through the system prompt passed at invocation.

**Cursor**
Cursor does not expose a hook API to extensions or rules. Background agents run autonomously but do not fire lifecycle events you can intercept. `.cursorrules` controls agent behavior through prompt injection, not event handlers.

---

## Tool Availability

| Tool | Claude Code | Gemini CLI | Codex CLI | Cursor |
|------|-------------|-----------|-----------|--------|
| Bash | Full | Full | Full | Partial |
| Read | Full | Full | Full | Full |
| Edit | Full | Full | Full | Full |
| Write | Full | Full | Full | Full |
| Glob | Full | Partial | Partial | Partial |
| Grep | Full | Partial | Partial | Partial |
| Agent (subagent dispatch) | Full | None | None | Partial |
| WebFetch | Full | Full | None | Unknown |
| WebSearch | Full | Partial | None | Unknown |
| NotebookEdit | Full | None | None | None |
| mcp__* (MCP tools) | Full | None | None | Partial |
| TodoWrite | Full | Unknown | None | Partial |
| AskUserQuestion | Full | None | None | None |

**Bash on Cursor:** Cursor's background agents run commands but the interactive approval model differs — the agent may pause for user confirmation rather than running with bypass permissions.

**Agent tool on Cursor:** Cursor has background agents, but they are not dispatched programmatically from within a session the same way Claude Code's Agent tool works. Cursor agents are invoked by the IDE, not by the AI model as a tool call.

**AskUserQuestion:** This is a Claude Code-specific tool. No other platform has a structured interactive prompt mechanism. Workaround: include decision logic in the instruction file (GEMINI.md, system prompt, .cursorrules) so the agent makes choices autonomously.

---

## Core Maestro Features

| Feature | Claude Code | Gemini CLI | Codex CLI | Cursor |
|---------|-------------|-----------|-----------|--------|
| Skills system (SKILL.md loading) | Full | Partial | None | Partial |
| Agent dispatch (delegation skill) | Full | None | None | None |
| Worktree isolation (workspace skill) | Full | None | None | None |
| MCP server support | Full | None | None | Partial |
| Memory (semantic + episodic) | Full | Partial | None | None |
| Slash commands (/maestro, /skill) | Full | None | None | None |
| Hook-based branch guard | Full | None | None | None |
| Session continuity (resume) | Full | Partial | None | None |
| Cost tracking (token-ledger) | Full | None | None | None |
| Checkpoint / approval gates | Full | None | None | Partial |
| Opus loop (autonomous continuation) | Full | None | None | None |
| Remote control | Full | None | None | None |
| HTTP event bus | Full | None | None | None |
| MCP Elicitation | Full | None | None | None |

### Skills System

**Gemini CLI (Partial):** GEMINI.md is the instruction file, analogous to CLAUDE.md. Skill content can be pasted or referenced inline in GEMINI.md. There is no dynamic skill loading — all instructions must be present in the file at session start. The `/skill` invocation pattern does not exist; skills must be described as static instructions.

**Cursor (Partial):** `.cursorrules` (or the newer `.cursor/rules/` directory) plays the role of CLAUDE.md. Skill content can be embedded in rules files. No dynamic invocation — rules are always-on prompt injections, not callable units.

**Codex CLI:** Instruction delivery is via a system prompt passed at launch. No persistent instruction file is loaded by convention.

### Memory

**Gemini CLI (Partial):** GEMINI.md can include static context that persists across sessions by being updated manually. There is no automated memory consolidation. The `@` reference syntax in GEMINI.md enables pulling in external files, which partially substitutes for Maestro's memory re-injection on PostCompact — but it is static, not event-driven.

**Codex CLI / Cursor:** No equivalent memory system. Context must be included in the instruction file or re-provided each session.

### Worktree Isolation

Worktree isolation depends on `WorktreeCreate` / `WorktreeRemove` hooks and the `git worktree` command being managed by Claude Code's workspace skill. None of the other platforms fire these events. The underlying `git worktree` command still works as a shell operation, but automated lifecycle management (register, verify cleanup, assign agents) is unavailable.

---

## Migration Guides

### Running Maestro-inspired Workflows on Gemini CLI

**What works:**
- File operations (Read, Edit, Write, Bash) — identical capability
- Session instructions via GEMINI.md — paste skill content here
- Basic sequential dev loop — describe the implementer/QA pattern in GEMINI.md
- Memory via manual GEMINI.md updates and the `@file` include syntax

**What degrades:**
- No `PreToolUse` blocking — branch guard cannot intercept commits. Workaround: instruct in GEMINI.md to never commit to main and always use a feature branch.
- No `PostCompact` — memory re-injection does not happen automatically. Workaround: keep critical state in a short `CONTEXT.md` file and reference it with `@CONTEXT.md` in GEMINI.md.
- No `Stop` loop — the opus loop (autonomous continuation) cannot be replicated. Run Gemini CLI commands manually for each phase.
- `AskUserQuestion` is unavailable — checkpoints must be replaced with explicit stopping points in the instruction (e.g., "stop and print WAITING_FOR_APPROVAL when the story is ready for review").

**What is unavailable:**
- Parallel agent dispatch (no Agent tool)
- Worktree isolation
- MCP servers
- Cost tracking
- Slash commands

**Recommended GEMINI.md approach:**

```
# Project Instructions

## Branch Policy
Always work on a feature branch. Never commit to main. If on main, create a branch before any changes.

## Dev Loop
Implement → test → report status. If tests fail, fix and retry up to 3 times, then stop with BLOCKED.

## Context
@CONTEXT.md
```

---

### Running Maestro-inspired Workflows on Codex CLI

**What works:**
- File operations (Read, Edit, Write) and Bash commands
- Sequential instruction following from the system prompt
- Basic feature implementation with a well-structured prompt

**What degrades:**
- No persistent instruction file — system prompt must be passed at each invocation. Workaround: use a shell alias or wrapper script that always passes `--system-prompt /path/to/instructions.md`.
- No WebFetch — research steps requiring URL fetching must be done outside Codex CLI.
- Sessions are stateless by default — re-pass context on every run.

**What is unavailable:**
- All hooks
- Agent dispatch
- Memory system
- Skills system
- MCP support
- Checkpoints / approval gates
- Cost tracking

**Minimal system prompt pattern:**

```
You implement features following TDD. Work in /path/to/project.
Never commit to main. Use feature branches.
After implementing: run tests. If they fail, fix and retry. Report DONE or BLOCKED when finished.
```

---

### Running Maestro-inspired Workflows on Cursor

**What works:**
- File operations — Cursor agents read, edit, and create files
- `.cursor/rules/` — embed skill instructions as always-on rules
- Background agents can execute multi-step tasks
- MCP servers can be configured in Cursor's MCP settings

**What degrades:**
- No hook events — behavioral guardrails (branch guard, audit log) must be encoded as rules in `.cursorrules` or `.cursor/rules/`.
- Agent dispatch is IDE-managed, not model-managed — parallel story execution requires manually launching multiple Cursor agent sessions.
- Checkpoints are available in Cursor's native agent UI but are not programmatically controllable via Maestro commands.
- MCP support is partial — Cursor supports MCP but not all servers are compatible; elicitation is unsupported.

**What is unavailable:**
- Slash commands (/maestro, /skill invocation)
- Opus loop / autonomous continuation
- Hook-based branch guard (must use rules instead)
- Session resume via SDK
- Cost tracking at the Maestro level
- Memory re-injection on compaction

**Recommended .cursor/rules approach:**

Create `.cursor/rules/maestro-compat.mdc`:

```
---
description: Maestro-compatible dev loop rules
alwaysApply: true
---

## Branch Policy
Never commit to main. Always use a feature branch.

## Implementation Pattern
Write a failing test first. Make it pass. Refactor. Repeat for each acceptance criterion.

## Completion
Report STATUS: DONE with test count and files changed. Report STATUS: BLOCKED if you cannot proceed.
```

---

## Feature Workarounds by Gap

### No PreToolUse (Gemini CLI, Codex CLI, Cursor)

**Gap:** Cannot intercept and block tool calls before they execute. Maestro uses this for branch guard (blocking commits to main) and delegation (routing edits to the correct agent).

**Workaround:** Encode the constraint as a high-priority instruction at the top of the instruction file.

```
CRITICAL: Never run git push to main or git commit while on the main branch.
Before any git operation: run `git branch --show-current` and verify you are not on main.
```

This relies on instruction-following rather than hard enforcement. It is weaker than a hook-based block but covers the common case.

---

### No Agent Tool (Gemini CLI, Codex CLI)

**Gap:** Cannot dispatch subagents in parallel. Maestro's dev-loop dispatches an implementer agent and a QA agent as parallel workers.

**Workaround:** Run phases sequentially in a single session. Replace "dispatch implementer, then QA" with "implement, then switch to QA persona in the same session."

```
Phase 1 (Implementer): Write failing tests, then implementation to make them pass.
Phase 2 (QA Reviewer): Review the implementation against the acceptance criteria. Report any gaps.
Phase 3 (Fixer): Fix any issues identified by QA.
```

Sequential execution is slower but produces the same artifacts. The main loss is parallelism — a two-story batch that would take 5 minutes in parallel takes 10 minutes sequentially.

---

### No PostCompact (Gemini CLI, Codex CLI, Cursor)

**Gap:** After context compaction, Maestro re-injects semantic memories and the current story spec. Without PostCompact, this state is lost silently.

**Workaround:** Keep a `CONTEXT.md` file in the project root that the agent is instructed to read at the start of every session and after any compaction-like event (long pause, restart).

```
At the start of each session, read CONTEXT.md and treat it as your current state.
After completing any major phase, update CONTEXT.md with the current story, progress, and next step.
```

---

### No AskUserQuestion (Gemini CLI, Codex CLI)

**Gap:** Maestro uses AskUserQuestion for checkpoints — pausing to show the user a structured choice before proceeding.

**Workaround:** Replace interactive checkpoints with explicit output markers. Instruct the agent to stop and print a sentinel string when a decision is needed. The user reads the output and re-invokes with their decision.

```
When you need approval before proceeding, print exactly:
  CHECKPOINT: [description of what was done]
  OPTIONS: Continue / Abort / Modify
Then stop. Do not continue until the next invocation includes a choice.
```

---

### No Worktree Isolation (Gemini CLI, Codex CLI, Cursor)

**Gap:** Maestro creates Git worktrees for parallel story execution, routing each agent to an isolated branch.

**Workaround:** Use separate branches manually. For sequential workflows this is not a gap — one branch per feature, merged when done. For parallel workflows, create branches manually before invoking agents and tell each agent which branch to work on.

---

### No MCP Support (Gemini CLI, Codex CLI)

**Gap:** MCP servers provide tools like database access, Jira integration, Linear queries, and structured approval dialogs. Without MCP, these integrations are unavailable.

**Workaround:** Use CLI tools or REST API calls via Bash instead of MCP tools. Slower and less structured, but functional for most integrations.

```
# Instead of MCP Linear tool:
curl -s -H "Authorization: Bearer $LINEAR_API_KEY" \
  "https://api.linear.app/graphql" \
  -d '{"query": "{ issues { nodes { id title } } }"}'
```

---

## Platform Selection Guide

Use this table to choose the right platform for your workflow.

| Requirement | Recommended Platform |
|------------|---------------------|
| Full Maestro feature set | Claude Code |
| Autonomous multi-story dev loop | Claude Code |
| Hook-based security (branch guard) | Claude Code |
| Parallel agent dispatch | Claude Code |
| Basic feature implementation without parallel agents | Any |
| Google AI / Gemini model preference | Gemini CLI (with degraded features) |
| IDE-integrated coding with rules | Cursor (with degraded features) |
| Minimal dependency, scripted automation | Codex CLI (with manual session management) |

The honest recommendation: if you need more than basic sequential implementation, use Claude Code. The hook system, agent dispatch, and memory re-injection are what make Maestro reliable at scale. The other platforms can run a subset of the workflow, but they require manual workarounds that reduce reliability and increase operational overhead.

---

## References

- Claude Code hooks reference: `skills/hooks-integration/SKILL.md`
- Agent dispatch: `skills/delegation/SKILL.md`
- Workspace / worktree management: `skills/workspace/SKILL.md`
- Memory system: `skills/memory/SKILL.md`
- Ecosystem detection (Claude Code variants): `skills/ecosystem/SKILL.md`
- Dispatch compat (remote/mobile): `skills/dispatch-compat/SKILL.md`
