---
name: codex-adapter
description: "Compatibility guide for using Maestro patterns in OpenAI Codex CLI. Documents what works as-is, what degrades gracefully, and workarounds for missing capabilities."
---

# Codex CLI Adapter

This guide covers how Maestro patterns apply — and where they break down — in OpenAI Codex CLI. Codex CLI runs in a sandboxed environment with restricted tool access and no hook or agent system. The gaps are real; this document does not pretend otherwise.

Use this guide when you want to apply Maestro's skills and conventions in a Codex CLI context, or when evaluating whether Maestro's dev-loop is a good fit for a Codex-based workflow.

---

## Environment Constraints

Codex CLI runs in a sandboxed container. Key constraints:

| Capability | Claude Code (Maestro native) | Codex CLI |
|-----------|------------------------------|-----------|
| File read/write | Unrestricted | Sandboxed to project directory |
| Shell execution | Full access | Limited; network calls blocked |
| External network | Available | Blocked by default in sandbox |
| Agent dispatch | Native (`Agent` tool) | Not available |
| Hook system | Full lifecycle hooks | Not available |
| Slash commands | Native skill activation | Not available |
| MCP servers | Configurable | Not available |
| Token tracking | Exposed | Not exposed |
| Session memory | Persistent via files | Single-session only |

---

## What Works Without Modification

These Maestro patterns are pure instruction-following — they work in Codex CLI because they do not depend on Claude Code-specific tools.

### Skill Files as Reference Documents

All Maestro skill `.md` files are plain markdown instruction documents. Codex can read and follow them as system-level context. The content works; the activation mechanism doesn't.

Skills that translate well as reference documents:

| Skill | Use in Codex |
|-------|-------------|
| `skills/dev-loop/implementer-prompt.md` | Paste or reference as system instructions for implementation work |
| `skills/dev-loop/qa-reviewer-prompt.md` | Use as a review checklist after implementation |
| `skills/git-craft/` | Commit message conventions followed as instructions |
| `skills/output-format/` | Box-drawing output format (Codex renders markdown) |
| `skills/context-engine/references/` | Load as reference documents for context budget rules |
| `profiles/` | Role-specific behavior instructions |
| `templates/` | Document templates for stories, strategies, roadmaps |

**How to load a skill in Codex:**

Option A — Paste skill content into the system prompt or conversation:
```
[System]
Follow the conventions in the document below for all commit operations:

<skill>
[contents of skills/git-craft/SKILL.md]
</skill>
```

Option B — Reference the file path and instruct Codex to read it:
```
Read skills/git-craft/SKILL.md and apply its conventions for this session.
```

Option B requires Codex to have file read access, which is available within the sandbox.

---

## What Degrades Gracefully

These features partially work but with reduced capability or manual effort.

### Dev-Loop Phases

Maestro's dev-loop orchestrates Implementer → QA Reviewer → Checkpoint in a pipeline. In Codex, you run these phases manually in sequence.

**Native Maestro:**
```
/maestro → decomposes feature → dispatches Implementer agent → dispatches QA Reviewer → checkpoint
```

**Codex equivalent (manual pipeline):**
```
Step 1: Paste story file + implementer-prompt.md → Codex implements
Step 2: Paste output + qa-reviewer-prompt.md → Codex reviews
Step 3: Review output manually, decide to proceed or fix
Step 4: Run git commands manually via Codex shell access
```

This works, but it requires you to manage the handoff between phases. There is no automatic dispatch, retry logic, or checkpoint prompting.

### Story Files

Maestro story `.md` files (with frontmatter) are readable by Codex. The frontmatter (status, type, acceptance criteria) can be parsed and followed as instructions.

**What works:** Codex can read a story file and implement against its acceptance criteria.

**What degrades:** Codex cannot update the story frontmatter (status, commit hash) automatically as part of a pipeline — that requires orchestration logic Codex does not have.

**Workaround:** After Codex completes implementation, manually update the story status in the file, or prompt Codex explicitly:
```
Update the status field in the story file frontmatter from "in_progress" to "done".
```

### Git Operations

Codex CLI has shell access within the sandbox. `git` commands work.

**What works:**
- `git add`, `git commit`, `git status`, `git diff`
- Following git-craft commit message conventions

**What degrades:**
- No automatic commit after story completion (no orchestration layer)
- No PR creation via `gh` CLI if network is blocked
- No hook scripts running before/after commits

**Workaround:** Prompt Codex to stage and commit at the end of each session:
```
Stage all changed files and create a commit following the conventions in
skills/git-craft/SKILL.md. Use the story title as the commit subject.
```

---

## What Does Not Work

These capabilities have no workaround in Codex CLI. Be honest with your team about these gaps.

### Agent Dispatch

Maestro's `Agent` tool spawns isolated sub-agents for Implementer, QA Reviewer, Strategist, etc. Codex has no equivalent. There is no way to run sub-agents, parallelize work, or isolate context between roles.

**Impact:** The full Maestro dev-loop (multi-agent pipeline) cannot run in Codex. You can use the skill files as checklists and run phases manually, but automated orchestration is not possible.

### Hook System

Maestro's `hooks/` directory contains shell scripts that fire on Claude Code lifecycle events. Codex has no lifecycle hooks.

**Impact:** Any Maestro behavior that relies on hooks — audit logging, pre-commit validation, cost tracking, session state persistence — does not run. There is no workaround within Codex itself.

If hooks are critical, consider running Codex inside a shell wrapper (similar to the Gemini approach), but note that per-tool hooks cannot be replicated.

### Slash Command Skill Activation

Maestro's `/skill-name` syntax is a Claude Code feature. Codex does not support slash commands or the `Skill` tool.

**Impact:** Skills cannot be activated via command. You must load skill content manually at the start of each session.

### MCP Servers

Maestro integrates with MCP servers for kanban, notifications, brain, and other capabilities. Codex CLI does not support MCP server connections.

**Impact:** Skills that depend on MCP tools (kanban sync, Slack/Discord notifications, Notion/Obsidian brain) do not work. Only skills that use file I/O and shell commands are available.

### Persistent Memory Across Sessions

Maestro's memory system persists user preferences and project context in files that Claude Code reloads in future sessions. Codex does not auto-load memory files between sessions.

**Impact:** Every Codex session starts fresh. There is no automatic memory persistence.

**Workaround:** At the start of each Codex session, manually paste your memory index or instruct Codex to read the memory directory:
```
Read all files in .maestro/memory/ and apply their rules for this session.
```

This requires discipline; it will not happen automatically.

---

## Recommended Usage Pattern

Given Codex's constraints, the most practical Maestro-on-Codex workflow is:

1. **Use Maestro on Claude Code** for orchestration, decomposition, and multi-agent work.
2. **Use Codex CLI** for bounded, single-story implementation tasks where you want a second model's perspective or a sandboxed execution environment.
3. **Load the relevant skill files** into Codex as system context for the specific task.
4. **Manage handoffs manually** — do not expect Codex to update story files or trigger downstream actions automatically.

### Session Template for Codex

At the start of a Codex session working on a Maestro story:

```
System context:
- Project conventions: [paste or reference CLAUDE.md or GEMINI.md]
- Implementer role: [paste skills/dev-loop/implementer-prompt.md]
- Output format: [paste skills/output-format/maestro.md]

Task:
Implement the story in .maestro/stories/[story-file].md.
Follow all acceptance criteria. Write tests first (TDD).
At the end, stage all changed files and commit using git-craft conventions.
```

---

## Skills Usable as Codex Reference Documents

| Skill File | Purpose | Codex-compatible? |
|-----------|---------|-------------------|
| `skills/dev-loop/implementer-prompt.md` | Implementation instructions | Yes — paste as system context |
| `skills/dev-loop/qa-reviewer-prompt.md` | Review checklist | Yes — paste as system context |
| `skills/dev-loop/error-catalog.md` | Error pattern reference | Yes — reference document |
| `skills/git-craft/SKILL.md` | Commit conventions | Yes — instruction document |
| `skills/output-format/maestro.md` | Output formatting rules | Yes — style guide |
| `profiles/backend-engineer.md` | Role behavior profile | Yes — persona document |
| `profiles/frontend-engineer.md` | Role behavior profile | Yes — persona document |
| `templates/` | Document templates | Yes — static templates |
| `skills/kanban/SKILL.md` | Kanban sync | No — requires MCP |
| `skills/notify/` | Notifications | No — requires MCP/network |
| `skills/brain/` | Knowledge base | No — requires MCP |
| `skills/scheduler/SKILL.md` | Cron scheduling | No — requires hook system |
| `skills/watch/SKILL.md` | File watching | No — requires hook system |
| `skills/ci-watch/` | CI monitoring | No — requires network |

---

## Summary

Codex CLI is a capable code generation tool, but it is not an orchestration platform. Maestro's value comes from its orchestration layer — agent dispatch, hooks, lifecycle management, skill composition. That layer does not exist in Codex.

What Codex can use:
- Skill files as plain instruction documents
- Story files as task definitions
- Git operations via shell access
- Output formatting conventions

What Codex cannot replicate:
- Multi-agent pipelines
- Hook-triggered automation
- MCP integrations
- Persistent session memory
- Slash-command skill activation

If your team needs Maestro's full capabilities, use Claude Code. If you want to use Codex for specific bounded tasks alongside a Maestro project, load the relevant skill files manually at the start of each session and manage handoffs yourself.
