---
name: desktop-compat
description: "Claude Desktop and Cowork compatibility guide. Documents which Maestro features work in Desktop vs. Terminal vs. Cowork, environment detection logic, and output adaptation rules for each context."
---

# Desktop Compatibility

Maestro runs in three distinct Anthropic environments: Claude Code Terminal, Claude Desktop, and Claude Cowork. Each has a different capability profile. This skill documents what works where, how to detect the current environment, and how to adapt Maestro behavior accordingly.

---

## Environment Overview

| Environment | Primary Use | Output Rendering | Bash Tool | Hooks | MCP Tools | Agent Dispatch |
|-------------|-------------|-----------------|-----------|-------|-----------|----------------|
| Claude Code Terminal | Local development, CI, automation | Plain text, box-drawing | Full | Full | Full | Full |
| Claude Desktop | Interactive conversation, daily use | Markdown rendered | None | None | Full (if configured) | Full |
| Claude Cowork | Team collaboration, shared sessions | Markdown rendered | None | None | Full (if configured) | Full |

---

## Feature Availability Matrix

### Core Maestro Features

| Feature | Terminal | Desktop | Cowork |
|---------|----------|---------|--------|
| Skills system (SKILL.md loading) | Full | Full | Full |
| Agent dispatch (delegation skill) | Full | Full | Full |
| Worktree isolation (workspace skill) | Full | None | Partial |
| MCP tools (if configured) | Full | Full | Full |
| Hooks system | Full | None | None |
| Bash tool | Full | None | None |
| Memory skill | Full | Full | Full |
| AskUserQuestion | Full | Full | Full |
| Box-drawing output | Full | None | None |
| Progress bars (Unicode) | Full | None | None |
| ANSI colors | Full | None | None |
| Slash commands (/maestro, /skill) | Full | Full | Full |
| Cost tracking (token-ledger) | Full | Partial | Partial |
| Checkpoint / approval gates | Full | Full | Full |
| Opus loop (autonomous continuation) | Full | Partial | Partial |
| Session resume via SDK | Full | None | None |
| Shared notes.md | None | None | Full |
| Shared .maestro/ state | None | None | Full |
| Team worktrees (parallel humans) | None | None | Full |
| Squad roles mapped to humans | None | None | Full |

### Tool Availability

| Tool | Terminal | Desktop | Cowork |
|------|----------|---------|--------|
| Bash | Full | None | None |
| Read | Full | Full | Full |
| Edit | Full | Full | Full |
| Write | Full | Full | Full |
| Glob | Full | Full | Full |
| Grep | Full | Full | Full |
| Agent (subagent dispatch) | Full | Full | Full |
| WebFetch | Full | Full | Full |
| WebSearch | Full | Full | Full |
| mcp__* (MCP tools) | Full | Full (if configured) | Full (if configured) |
| TodoWrite | Full | Full | Full |
| AskUserQuestion | Full | Full | Full |

---

## Environment Detection

### Step 1 — Check $CLAUDE_SESSION_TYPE

This is the authoritative signal. When set, trust it completely:

```
$CLAUDE_SESSION_TYPE == "terminal"  → TERMINAL mode
$CLAUDE_SESSION_TYPE == "desktop"   → DESKTOP mode
$CLAUDE_SESSION_TYPE == "cowork"    → COWORK mode
$CLAUDE_SESSION_TYPE == "remote"    → REMOTE mode
$CLAUDE_SESSION_TYPE == "sdk"       → SDK mode
```

### Step 2 — Infer from session hints (fallback)

When `$CLAUDE_SESSION_TYPE` is not set, infer from available signals:

```bash
# Desktop detection signals
echo $CLAUDE_DESKTOP_SESSION       # "true" if in Desktop app
echo $CLAUDE_CLIENT_TYPE           # "desktop" if Desktop app

# Cowork detection signals
echo $CLAUDE_COWORK_SESSION        # "true" if in Cowork
echo $CLAUDE_TEAM_SESSION          # "true" if team session active
echo $CLAUDE_CLIENT_TYPE           # "cowork" if Cowork app
```

### Full Decision Tree

```
$CLAUDE_SESSION_TYPE set?
  YES → use its value directly
        terminal → TERMINAL mode
        desktop  → DESKTOP mode
        cowork   → COWORK mode
        remote   → REMOTE mode
        sdk      → SDK mode
  NO  →
        tty attached ([ -t 0 ])?
          YES → TERMINAL mode
          NO  →
                CLAUDE_DESKTOP_SESSION=true
                OR CLAUDE_CLIENT_TYPE=desktop?
                  YES → DESKTOP mode
                  NO  →
                        CLAUDE_COWORK_SESSION=true
                        OR CLAUDE_CLIENT_TYPE=cowork
                        OR CLAUDE_TEAM_SESSION=true?
                          YES → COWORK mode
                          NO  → TERMINAL mode (safe default)
```

### Config Override

Force a specific environment in `.maestro/config.yaml`:

```yaml
output:
  force_environment: desktop   # terminal | desktop | cowork | remote | sdk
```

---

## Claude Desktop — Limitations and Adaptations

Claude Desktop renders markdown but has no terminal, no shell, and no hooks. Many Maestro features that depend on the Bash tool or lifecycle hooks are unavailable.

### What Is Unavailable in Desktop

**No Bash tool:**
- Cannot run shell commands, scripts, or git operations
- Cannot execute tests (`npm test`, `pytest`, etc.)
- The hooks-integration skill has no effect — hooks are never fired
- The ci-watch skill cannot poll CI runners
- The git-craft skill cannot commit, push, or create branches

**No hooks system:**
- Branch guard (PreToolUse hook) is not active — commits to main are not blocked
- Audit log (PostToolUse hook) does not write entries
- Memory re-injection on PostCompact does not fire
- Session lifecycle events (SessionStart, Stop, StopFailure) do not occur

**No terminal output rendering:**
- Box-drawing characters (`┌`, `─`, `│`, `└`) appear as literal Unicode, not boxes
- ANSI color codes appear as raw escape sequences
- Progress bars using Unicode blocks (`█`, `▓`, `░`) do not animate
- Wide tables (80-char box-drawing) may wrap or truncate

### Output Adaptation for Desktop

In Desktop mode, all Maestro output follows these rules:

| Output Element | Terminal Mode | Desktop Mode |
|---------------|---------------|--------------|
| Section headers | `┌─── Header ───┐` box | `## Header` markdown heading |
| Status rows | `│  key    value │` | `- **key:** value` list item |
| Progress bar | `[======>    ] 4/10` | `Progress: 40% (4 of 10 stories)` |
| Tables | Box-drawing table | Markdown table |
| Diagrams | ASCII box art | Mermaid code block (rendered inline) |
| Error output | Full trace with box | Fenced code block, no border |
| AskUserQuestion | Up to 4 options | 2-3 options max |
| Max line width | 80 chars | 60 chars |
| ANSI colors | Used | None |

### Desktop Output Examples

**Story checkpoint — Terminal:**
```
┌─────────────────────────────────────────────────────────┐
│  Story 3/7 complete: API Routes                         │
├─────────────────────────────────────────────────────────┤
│  Files     4 created, 2 modified                        │
│  Tests     8 new, all passing                           │
│  Tokens    34,200 (story) / 127,800 (total)             │
│                                                         │
│  [GO] Continue   [PAUSE] Review   [SKIP] Skip story     │
└─────────────────────────────────────────────────────────┘
```

**Story checkpoint — Desktop:**
```
[maestro] Story 3/7 complete: API Routes

- **Files:** 4 created, 2 modified
- **Tests:** 8 new, all passing
- **Progress:** 43% (3 of 7 stories)

Continue / Review / Abort
```

**Error output — Terminal:**
```
┌─────────────────────────────────────────────────────────┐
│  Test Failure                                           │
│  File: src/utils/pricing.test.ts:47                     │
│  Expected: 29.99   Received: 30.00                      │
│  Fix: use toBeCloseTo() for float assertions            │
└─────────────────────────────────────────────────────────┘
```

**Error output — Desktop:**
```
[maestro] Test failure in `src/utils/pricing.test.ts:47`

Expected `29.99`, received `30.00`.
Fix: use `toBeCloseTo()` for float assertions.
```

### Desktop Workarounds

**No Bash tool — running tests:**
Use the TodoWrite tool to record what manual steps the user must run, then ask for results:

```
[maestro] I cannot run tests directly in Desktop mode.

Please run in your terminal:
  npm test

Then share the output and I will continue.
```

**No hooks — branch guard:**
Include an explicit instruction at the start of every session to never commit to main. Without hooks, this relies on instruction-following, not hard enforcement.

**No PostCompact — memory re-injection:**
Desktop sessions do not trigger PostCompact. If a long session is compacted, Maestro cannot automatically re-inject memories. Keep a short `CONTEXT.md` in the project root and instruct Maestro to read it at the start of each session.

---

## Claude Cowork — Team Collaboration Features

Cowork is Claude Desktop's team mode. Multiple humans and agents share a session, a codebase reference, and a `.maestro/` state directory. Cowork extends Desktop capabilities with shared state and team coordination primitives.

### Shared State

In Cowork, the `.maestro/` directory is shared across all team members:

```
.maestro/
  ├── state.md              # Shared project state — all members read/write
  ├── notes.md              # Shared team communication channel
  ├── stories/              # Stories visible to all team members and agents
  ├── config.yaml           # Shared project configuration
  └── workspaces/           # Per-feature workspaces, optionally shared
```

`state.local.md` is the only file that remains local — it holds per-session state like the active squad and active workspace name.

### Shared notes.md

`notes.md` is the async communication channel for Cowork teams. Team members and agents write to it when they need to leave context for others.

Format for agent entries:

```markdown
## [agent] 2026-03-18T14:32:00Z — implementer

Story M6-S22 complete. PR #87 ready for review.
Tests: 14 passing. One concern: see AC3 note in story file.
```

Format for human entries:

```markdown
## [human] rodrigo — 2026-03-18T15:00Z

Approved PR #87. Merged. Moving M6-S23 to active.
```

Agents must read `notes.md` at the start of each task to pick up context left by teammates. Agents must write to `notes.md` when completing a story, blocking on an issue, or leaving context that a teammate will need.

### Team Worktrees

Cowork supports multiple agents working simultaneously via Git worktrees. Each agent is assigned a dedicated worktree for its story:

```
project/
  ├── (main working tree — default workspace)
  └── .maestro/worktrees/
      ├── agent-m6-s22/     # Implementer working on M6-S22
      ├── agent-m6-s23/     # Implementer working on M6-S23
      └── agent-qa-s22/     # QA reviewing M6-S22
```

Worktree assignment is tracked in `state.md`:

```yaml
worktrees:
  - id: agent-m6-s22
    story: M6-S22
    agent: implementer
    branch: feat/m6-s22-desktop-compat
    human: null
  - id: agent-m6-s23
    story: M6-S23
    agent: implementer
    branch: feat/m6-s23-next-story
    human: rodrigo        # human team member assigned to review
```

Worktrees in Cowork are created by the orchestrator or by a team lead, not by individual agents. Agents receive their worktree path in their task context.

### Squad Roles Mapped to Humans

In Cowork, squad roles can be assigned to human team members instead of AI agents. This allows Maestro to coordinate human-AI hybrid teams.

Squad definition with human assignments (`squads/hybrid-team/squad.md`):

```yaml
---
name: hybrid-team
description: Mixed human-AI development team
---

roles:
  - role: orchestrator
    type: ai
    model: claude-opus-4-5
    description: Breaks epics into stories, assigns work

  - role: implementer
    type: ai
    model: claude-sonnet-4-6
    description: Implements stories via TDD

  - role: reviewer
    type: human
    member: "@alice"
    description: Senior engineer — reviews PRs before merge

  - role: qa
    type: human
    member: "@bob"
    description: QA engineer — validates acceptance criteria

  - role: product
    type: human
    member: "@rodrigo"
    description: Product owner — approves story definitions
```

When a role is assigned to a human, Maestro replaces agent dispatch with a handoff:

```
[maestro] Story M6-S22 ready for review.

Assigned to: @alice (reviewer)

Next step: @alice reviews PR #87 and approves or requests changes.
Waiting for human action — run `/maestro resume` after @alice completes the review.
```

### Cowork Session Coordination

When multiple agents are active simultaneously in Cowork, coordination rules prevent conflicts:

**File locking (advisory):**
Before editing a file, an agent writes its intent to `state.md`:

```yaml
file_locks:
  - file: src/components/PriceTable.tsx
    locked_by: agent-m6-s22
    since: 2026-03-18T14:30:00Z
```

Other agents check `state.md` before editing. If a file is locked, the agent waits or works on a different file. Locks are released when the agent commits its changes.

**Notes protocol in parallel sessions:**
When two agents complete stories at the same time, they each append to `notes.md` independently. The orchestrator reads both entries before deciding the next action.

**Conflict resolution:**
If two agents produce conflicting changes to the same file:
1. The later agent detects the conflict when attempting to commit
2. It writes a `CONFLICT` entry to `notes.md`
3. The orchestrator resolves the conflict before continuing

---

## Decision Guide: Which Environment to Use

| Situation | Recommended Environment |
|-----------|------------------------|
| Full autonomous dev loop (TDD, hooks, CI, git) | Claude Code Terminal |
| Interactive planning, architecture, reviewing code | Claude Desktop |
| Team reviewing stories together, async handoffs | Claude Cowork |
| Running Maestro in CI/CD pipeline | Claude Code Terminal (SDK mode) |
| Pair-working with AI on a feature | Claude Desktop or Cowork |
| Parallel story execution (multiple agents simultaneously) | Claude Code Terminal (worktrees) |
| Human-AI hybrid team with role assignments | Claude Cowork |

The honest trade-off: Terminal has the most capability. Desktop is the best interactive experience for a solo user. Cowork adds team coordination but retains the same output rendering limitations as Desktop.

---

## Configuration

In `.maestro/config.yaml`:

```yaml
desktop_compat:
  auto_detect: true                  # Detect environment automatically
  force_environment: null            # null | terminal | desktop | cowork
  cowork:
    shared_notes: true               # Write to notes.md on story completion
    advisory_locks: true             # Check file_locks in state.md before edits
    human_handoff_message: true      # Show handoff message when role is human
    wait_for_resume: true            # Pause after human handoff, wait for /maestro resume
```

---

## References

- Output profiles and formatting rules: `skills/universal-output/SKILL.md`
- Remote and mobile output adaptation: `skills/dispatch-compat/SKILL.md`
- Platform compatibility (Gemini CLI, Codex CLI, Cursor): `skills/compatibility/SKILL.md`
- Ecosystem detection overview: `skills/ecosystem/SKILL.md`
- Workspace and worktree management: `skills/workspace/SKILL.md`
- Squad role definitions: `skills/squad/SKILL.md`
- Hooks reference: `skills/hooks-integration/SKILL.md`
