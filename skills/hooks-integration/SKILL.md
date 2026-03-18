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

## HTTP Hooks as Event Bus

**Requires:** Claude Code v2.1.76+

Claude Code v2.1.76 introduced `"type": "http"` hooks that POST JSON payloads to a URL instead of spawning a shell process. This enables a local event bus pattern: a lightweight HTTP server receives all hook events, maintains state across them, and can trigger downstream actions without forking subprocesses.

### Use Cases

- **Local dashboard**: visualize agent progress in real time by consuming hook events
- **Webhook relay**: forward events to an external system (CI, Slack, Linear) without shell scripting
- **State machine**: track multi-step agent progress by accumulating events in a server-side store

### Example Configuration

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "http",
        "url": "http://localhost:3456/hooks/stop"
      }]
    }],
    "PreToolUse": [{
      "hooks": [
        {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/branch-guard.sh"},
        {"type": "http", "url": "http://localhost:3456/hooks/pre-tool"}
      ]
    }]
  }
}
```

Shell and HTTP hooks can coexist in the same event list. Claude Code POSTs the same JSON payload that would be piped to a shell hook.

### Benefits Over Shell Hooks

- No subprocess overhead — HTTP is a direct network call
- Structured JSON in and out — no parsing of stdin/stdout
- The server can maintain state across events (e.g., token counters, failure streaks)
- A single server process handles all events, simplifying coordination

### Limitation

A running HTTP server is required before Claude Code starts. Use `scripts/service-installer.sh` to register the event-bus server as a system service so it is always available.

---

## MCP Elicitation for Approval Gates

**Requires:** Claude Code v2.1.76+

Claude Code v2.1.76 added MCP Elicitation — a mechanism by which an MCP server can request structured user input mid-task rather than relying on free-form prompts. Two hooks integrate with it:

| Hook | Fires When |
|------|-----------|
| `Elicitation` | An MCP server has requested user input |
| `ElicitationResult` | The user has responded to the elicitation dialog |

### Why Elicitation Is Better Than Prompt-Based Approval Gates

1. **Structured dialog** — the MCP server defines the input schema; the user sees a typed form, not a free-form prompt
2. **Validated response** — the response is typed and schema-validated before it reaches the server
3. **Auditable** — `ElicitationResult` fires after every response, giving hooks a reliable intercept point for logging

### Maestro Integration

Replace `AskUserQuestion`-based checkpoints with MCP elicitation wherever an MCP server is available in the session. The pattern:

1. A custom MCP server (e.g., `maestro-approval`) exposes an approval tool
2. The orchestrator calls the tool when a checkpoint is reached
3. The MCP server issues an elicitation request with an `Accept / Reject / Modify` schema
4. The `ElicitationResult` hook fires when the user responds; Maestro logs the decision via the audit-log skill
5. The orchestrator reads the typed response and routes accordingly

### Example: Story Approval Dialog

```json
{
  "elicitation": {
    "title": "Review story changes?",
    "schema": {
      "type": "object",
      "properties": {
        "decision": {
          "type": "string",
          "enum": ["Accept", "Reject", "Modify"],
          "description": "Approve the proposed changes, reject them, or request modifications"
        },
        "notes": {
          "type": "string",
          "description": "Optional feedback for the agent"
        }
      },
      "required": ["decision"]
    }
  }
}
```

### Hook Registration

```json
{
  "hooks": {
    "Elicitation": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/elicitation-hook.sh"}]}],
    "ElicitationResult": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/elicitation-result-hook.sh"}]}]
  }
}
```

---

## Adding a New Hook

1. Create the handler script in `hooks/` (shell) or document in a skill (skill-level)
2. Register shell hooks in `hooks/hooks.json`
3. Skill-level hooks are invoked by the orchestrator at the appropriate point
4. Test with: `echo '{"tool_name":"Bash","tool_input":{"command":"echo test"}}' | hooks/your-hook.sh`
