---
name: hooks-integration
description: "Reference for all Claude Code hooks used by Maestro. Documents when each fires, what Maestro does with it, and configuration."
---

# Hooks Integration

Maestro leverages Claude Code's hook system for lifecycle management, security, and automation. This reference documents all hooks and their Maestro handlers.

## Hook Summary

| Hook | Fires When | Blocks? | Maestro Handler | Purpose |
|------|-----------|---------|-----------------|---------|
| PreToolUse | Before any tool call | Yes | `hooks/branch-guard.sh` | Block git ops on main branch |
| PostToolUse | After tool completes | No | audit-log skill | Log decisions |
| Stop | Claude finishes responding | No | `hooks/opus-loop-hook.sh`, `hooks/stop-hook.sh` | Opus loop continuation, session persistence |
| StopFailure | On API errors | No | doom-loop skill | Error recovery, fallback handler |
| Notification | Claude emits notification | No | `hooks/notification-hook.sh` | Desktop/audio alerts |
| PostCompact | After context compaction | No | memory skill | Re-inject critical state |
| InstructionsLoaded | CLAUDE.md/rules load | No | mcp-detect skill | Skill registry refresh |
| WorktreeCreate | Git worktree created | No | workspace skill | Track active worktrees |
| WorktreeRemove | Git worktree removed | No | workspace skill | Verify cleanup |
| SubagentStop | Subagent completes | No | delegation skill | Track agent completion |

## PreToolUse — Branch Guard

**Handler:** `hooks/branch-guard.sh`

Intercepts Bash tool calls that would commit or push directly to `main`. Blocks the operation with a message directing to the `development` branch.

**Blocked patterns:**
- `git push ... main`
- `git commit` while on main branch
- `git merge` into main

**Configuration:** Registered in `hooks/hooks.json` under `PreToolUse`.

## Stop — Opus Loop + Session Persistence

**Handlers:** `hooks/opus-loop-hook.sh`, `hooks/stop-hook.sh`

Two handlers chain on Stop:

1. **opus-loop-hook.sh**: If an Opus session is active (`layer: opus`, `active: true`, mode `full_auto` or `until_pause`), blocks the exit and re-injects the orchestration prompt to continue the autonomous loop. Checks safety valves (token budget, consecutive failures) before looping.

2. **stop-hook.sh**: For non-Opus active sessions, prevents exit during dev-loop execution. Re-injects continuation prompt with current story context.

## StopFailure — Doom-Loop Fallback

**Handler:** doom-loop skill (skill-level, not shell script)

When an API error occurs during agent execution:
1. Log the error pattern
2. Check if it matches a doom-loop pattern (repeated identical failures)
3. If doom-loop detected: escalate model or halt with diagnostic
4. If transient error: allow retry with backoff

## Notification — Desktop/Audio Alerts

**Handler:** `hooks/notification-hook.sh`

Fires when Maestro reaches a checkpoint or needs user input. Sends desktop notifications via `osascript` (macOS) or `notify-send` (Linux). Combined with `scripts/audio-alert.sh` for sound alerts.

## PostCompact — Memory Re-Injection

**Handler:** memory skill (skill-level)

After context compaction, critical state may be lost. PostCompact triggers:
1. Re-inject high-confidence semantic memories
2. Re-inject current story spec and acceptance criteria
3. Re-inject HANDOFF.md if available
4. Log compaction event for debugging

## InstructionsLoaded — Registry Refresh

**Handler:** mcp-detect skill (skill-level)

When CLAUDE.md or skill files are loaded/reloaded:
1. Scan for available MCP servers
2. Update skill registry
3. Detect environment (terminal, desktop, cowork)

## WorktreeCreate / WorktreeRemove — Workspace Lifecycle

**Handler:** workspace skill (skill-level)

Track worktree lifecycle for parallel agent management:
- **Create**: Register worktree path, branch, agent assignment
- **Remove**: Verify changes were merged, clean up branch

## SubagentStop — Agent Completion

**Handler:** delegation skill (skill-level)

When a dispatched subagent completes:
1. Capture result status (DONE, BLOCKED, NEEDS_CONTEXT)
2. Log token spend and model used
3. Update audit log with decision outcome
4. Route to QA or next phase

## hooks.json Configuration

```json
{
  "hooks": {
    "PreToolUse": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/branch-guard.sh"}]}],
    "Stop": [{"hooks": [
      {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/opus-loop-hook.sh"},
      {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.sh"}
    ]}],
    "Notification": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/notification-hook.sh"}]}]
  }
}
```

## Adding a New Hook

1. Create the handler script in `hooks/` (shell) or document in a skill (skill-level)
2. Register shell hooks in `hooks/hooks.json`
3. Skill-level hooks are invoked by the orchestrator at the appropriate point
4. Test with: `echo '{"tool_name":"Bash","tool_input":{"command":"echo test"}}' | hooks/your-hook.sh`
