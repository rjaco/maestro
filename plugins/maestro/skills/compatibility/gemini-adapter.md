---
name: gemini-adapter
description: "Adapter guide for using Maestro patterns in Gemini CLI. Maps Maestro concepts and tools to Gemini equivalents, with honest coverage of limitations."
---

# Gemini CLI Adapter

This guide maps Maestro's Claude Code conventions to Gemini CLI equivalents. Use it when you want to apply Maestro's orchestration patterns — skills, hooks, dev-loop — in a Gemini CLI project.

Not everything translates 1:1. This document is explicit about what works, what degrades, and what has no equivalent.

---

## Project Instructions: CLAUDE.md → GEMINI.md

Maestro uses `CLAUDE.md` to inject persistent project conventions into every Claude Code session. Gemini CLI uses `GEMINI.md` for the same purpose.

**How to adapt Maestro's CLAUDE.md for Gemini:**

1. Copy your project's `CLAUDE.md` content into `GEMINI.md` at the repo root.
2. Remove any Claude Code-specific tool references (e.g., `Agent`, `AskUserQuestion`).
3. Replace them with Gemini-compatible equivalents (see tool map below).
4. Keep skill activation instructions, but use Gemini's activation syntax.

**What carries over unchanged:**
- Project conventions, coding standards, file structure rules
- Skill definitions as plain instruction documents
- Memory index and reference files
- Output format preferences (box-drawing, status labels, etc.)

**What must be adapted:**
- Tool references in skill files (see tool map below)
- Hook triggers (see Hooks section)
- Agent dispatch patterns (see Agent section)

---

## Tool Map

| Maestro Tool (Claude Code) | Gemini Equivalent | Notes |
|---------------------------|-------------------|-------|
| `Read` | `read_file` | Direct equivalent |
| `Edit` | `replace_in_file` | Equivalent; Gemini uses search/replace approach |
| `Write` | `write_file` | Direct equivalent |
| `Bash` | `run_shell_command` | Equivalent; same sandbox considerations |
| `Glob` | `list_directory` + `glob` | Gemini has glob-style matching |
| `Grep` | `search_files` | Equivalent text search |
| `AskUserQuestion` | Input prompting via `@user` | Gemini prompts the user inline; no structured options list |
| `WebFetch` | `fetch_url` | Equivalent |
| `WebSearch` | `google_search` | Gemini has native Google Search integration |
| `Agent` | No native equivalent | See Agent Dispatch section below |
| `Skill` (slash commands) | `activate_skill` tool | See Skill Activation section below |
| `NotebookEdit` | `edit_notebook` | Equivalent for Jupyter notebooks |

---

## Agent Dispatch

Maestro uses the `Agent` tool to spawn sub-agents (Implementer, QA Reviewer, etc.) running in isolated contexts. This is a Claude Code-specific capability.

**Gemini has no native Agent dispatch.**

### Workaround: Sequential Execution in Same Context

Instead of dispatching to a sub-agent, instruct Gemini to adopt the agent's persona and execute its responsibilities in the current session:

```
# Maestro (Claude Code)
Agent(skill="implementer", story=story_file)

# Gemini CLI equivalent
"You are now acting as the Implementer agent. Follow the implementer role
defined in agents/implementer.md. Your input is [story_file]. Proceed."
```

**Limitations of this workaround:**
- No context isolation — the sub-agent shares the parent's full context window
- No parallel execution — agents run sequentially, not concurrently
- Token cost is higher — the full conversation history is visible to the "sub-agent"
- No guaranteed role enforcement — Gemini may drift from the persona without hooks

**Recommendation:** For Gemini, flatten the orchestration. Instead of a multi-agent pipeline (Strategist → Implementer → QA Reviewer), design single-pass prompts that embed the relevant role criteria directly.

---

## Skill Activation

Maestro skills are activated in Claude Code via slash commands (`/commit`, `/ship`, etc.) or the `Skill` tool. Gemini CLI uses the `activate_skill` tool or direct instruction injection.

### Via `activate_skill` Tool

If your Gemini project has the `activate_skill` tool registered:

```
# Claude Code
/commit

# Gemini CLI
activate_skill("commit")
```

### Via Direct Instruction Injection

If no tool registration is available, paste the skill file contents into the session:

```
# In your Gemini prompt
"Follow the instructions in skills/git-craft/SKILL.md for all commit operations."
```

Or reference the file path in `GEMINI.md` to load it at session start:

```markdown
<!-- GEMINI.md -->
## Active Skills
- Commit conventions: see skills/git-craft/SKILL.md
- Ship process: see skills/ship/SKILL.md
```

**What carries over unchanged:**
- Skill content and logic — skill `.md` files are plain instructions, not code
- Provider sub-files (e.g., `kanban/provider-github.md`)
- Reference documents (e.g., `context-engine/references/`)

**What does not carry over:**
- Automatic slash-command registration
- Skill loading from `CLAUDE.md` imports

---

## Hooks

Maestro's hook system (`hooks/`) triggers shell scripts on Claude Code lifecycle events: pre-tool, post-tool, pre-session, post-session, stop, etc.

**Gemini has limited hook support.** As of early 2026, Gemini CLI supports a subset of lifecycle events.

### Supported in Gemini CLI

| Hook Event | Gemini Support | Notes |
|------------|---------------|-------|
| Pre-session setup | Partial | Via `GEMINI.md` initialization instructions |
| Post-session | None | No native equivalent |
| Pre-tool call | None | No interception layer |
| Post-tool call | None | No interception layer |
| File system events | None | No watch hooks |
| Stop/interrupt | None | No native equivalent |

### Workaround: Inline Hook Logic

Embed hook behavior directly in skill instructions rather than relying on lifecycle events:

```markdown
<!-- In GEMINI.md or skill file -->
Before running any shell command:
  1. Check if the command modifies files outside the project root.
  2. If yes, ask for confirmation before proceeding.
```

This replicates pre-tool safety checks without a hook system.

### Workaround: Shell Wrapper Scripts

For session-level hooks (audit logging, cost tracking), use a shell wrapper:

```bash
#!/bin/bash
# gemini-session.sh — wraps Gemini CLI with pre/post hooks

# Pre-session hook
bash hooks/pre-session.sh

# Run Gemini
gemini "$@"
EXIT_CODE=$?

# Post-session hook
bash hooks/post-session.sh $EXIT_CODE

exit $EXIT_CODE
```

**Note:** This only covers session boundaries, not per-tool events.

---

## Memory System

Maestro's memory system stores user preferences, project context, and feedback in `.claude/agent-memory/`. It relies on Claude Code's file persistence between sessions.

**Gemini equivalent:** Create a `GEMINI.md`-referenced memory directory at `.gemini/memory/`. Gemini CLI does not auto-load memory files, so reference them explicitly in `GEMINI.md`:

```markdown
<!-- GEMINI.md -->
## Persistent Memory
Load and apply rules from `.gemini/memory/` at session start.
Current entries:
- feedback_testing.md — testing conventions
- user_profile.md — user role and preferences
```

---

## Dev-Loop Compatibility

| Maestro Dev-Loop Phase | Gemini Support | Notes |
|----------------------|---------------|-------|
| Story planning (decompose) | Full | Pure instruction-following |
| Implementer agent | Partial | Single-context workaround |
| QA Reviewer agent | Partial | Single-context workaround |
| Checkpoint prompts | Full | Gemini can prompt for user decision |
| Commit (git-craft) | Full | `run_shell_command` runs git |
| Ship (PR creation) | Full | `gh` CLI available via shell |
| Kanban sync | Full | MCP tools or shell commands |
| Token tracking | None | Gemini does not expose per-call token counts |

---

## What Does Not Work in Gemini CLI

Be explicit with your team about these gaps:

- **Agent isolation** — No sub-agent context separation. All work runs in one context.
- **Parallel agents** — No concurrent execution of Implementer + QA Reviewer.
- **Per-tool hooks** — No interception before/after individual tool calls.
- **Slash-command activation** — Skills must be activated manually or via `GEMINI.md` references.
- **Token ledger** — Gemini does not expose token counts in a way Maestro can consume.
- **`AskUserQuestion` options UI** — Gemini prompts inline; no structured option rendering.

---

## Quick-Start Checklist

To port a Maestro project to Gemini CLI:

- [ ] Create `GEMINI.md` from your `CLAUDE.md`, replacing Claude-specific tool names
- [ ] Reference active skill files in `GEMINI.md` under "Active Skills"
- [ ] Replace `Agent` dispatch calls with inline persona instructions
- [ ] Embed hook logic in skill instructions (no lifecycle hooks available)
- [ ] Create `.gemini/memory/` directory and reference it in `GEMINI.md`
- [ ] Use `run_shell_command` for all Bash operations
- [ ] Accept that token tracking and parallel agent execution are unavailable
