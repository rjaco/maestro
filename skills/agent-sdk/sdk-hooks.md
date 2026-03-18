# SDK-Native Hooks Migration Guide

Reference for migrating from Maestro's shell script hooks to Claude Agent SDK programmatic hooks. Shell hooks remain the default for Claude Code terminal usage. SDK hooks are for Agent SDK / bot / CI integrations.

## Shell Hooks vs SDK Hooks

| Aspect | Shell Hooks | SDK Hooks |
|--------|-------------|-----------|
| Format | Bash scripts in `hooks/` | TypeScript callbacks |
| Returns | JSON to stdout | Structured objects |
| Performance | Subprocess spawn per event | In-process function call |
| Debugging | Log files | Stack traces + breakpoints |
| Types | No type safety | Full TypeScript types |
| State | File-based (read/write files) | In-memory + file |

## SDK Hook Format

```typescript
import { Agent } from '@anthropic-ai/agent-sdk'

const agent = new Agent({
  model: 'claude-opus-4-5',
  hooks: {
    PreToolUse: async ({ tool, input }) => {
      if (tool === 'Bash' && (input.command as string)?.includes('git push --force')) {
        return { permissionDecision: 'deny', reason: 'Force push not allowed' }
      }
      return {}  // allow
    },
    Stop: async ({ session }) => {
      return { decision: 'block', reason: 'Continue Opus loop' }
    }
  }
})
```

## 18 SDK Hook Events

### Tool Lifecycle
| Hook | Fires when | Receives | Actions |
|------|-----------|----------|---------|
| **PreToolUse** | Before any tool executes | `tool`, `input`, `session` | Allow `{}`, deny `{permissionDecision:'deny', reason}`, modify input |
| **PostToolUse** | After tool completes | `tool`, `input`, `output`, `session` | Observe, log, trigger side-effects |
| **PreToolUseApproval** | Before prompting user for approval | `tool`, `input`, `session` | Pre-approve `{approved:true}` or let prompt through |
| **ToolError** | Tool call throws | `tool`, `input`, `error`, `session` | Log, increment failure counter, trigger self-heal |
| **PermissionDenied** | PreToolUse hook denies a call | `tool`, `input`, `reason` | Log the denial |

### Session Lifecycle
| Hook | Fires when | Receives | Actions |
|------|-----------|----------|---------|
| **Stop** | Agent is about to exit | `session`, `reason` | Allow `{}`, block `{decision:'block', reason, systemMessage?}` |
| **SubagentStart** | Sub-agent (Agent tool) begins | `subagentId`, `prompt`, `session` | Observe, modify prompt |
| **SubagentStop** | Sub-agent finishes | `subagentId`, `output`, `session` | Accumulate results, trigger next step |
| **SessionEnd** | Session fully torn down | `session`, `finalState` | Persist state, generate report |
| **MaxTokensReached** | Context limit hit | `tokenCount`, `session` | Trigger compaction, checkpoint |

### Compaction
| Hook | Fires when | Receives | Actions |
|------|-----------|----------|---------|
| **PreCompact** | Before context window is compressed | `tokenCount`, `session` | Save state before history is lost |
| **PostCompact** | After compaction completes | `summary`, `session` | Verify summary, inject reminders |

### Messages and Streaming
| Hook | Fires when | Receives | Actions |
|------|-----------|----------|---------|
| **Notification** | Claude generates a notification | `message`, `type`, `session` | Desktop alert, Slack post, audio |
| **UserMessage** | User message added | `message`, `session` | Pre-process, log |
| **AssistantMessage** | Claude produces a response | `message`, `session` | Log, trigger downstream |
| **StreamStart** | Streaming response begins | `session` | Start timer, open UI stream |
| **StreamChunk** | Each streaming chunk | `chunk`, `session` | Pipe to UI |
| **StreamEnd** | Streaming completes | `fullText`, `session` | Finalize stream |

## Migration Examples

### branch-guard.sh → PreToolUse

Block git operations on main without subprocess or jq:

```typescript
PreToolUse: async ({ tool, input }) => {
  if (tool !== 'Bash') return {}
  const cmd = input.command as string | undefined
  if (cmd?.includes('git push') && cmd?.includes('main')) {
    return { permissionDecision: 'deny', reason: 'Use a development branch' }
  }
  return {}
}
```

### opus-loop-hook.sh → Stop callback

State lives in-memory — no YAML frontmatter parsing with sed/grep:

```typescript
Stop: async ({ session }) => {
  const state = session.state as MaestroState | undefined
  if (!state?.active || state.layer !== 'opus') return {}
  if (['completed', 'aborted', 'paused'].includes(state.phase)) return {}
  if (state.token_spend >= state.token_budget && state.token_budget > 0) return {}
  if (state.consecutive_failures >= state.max_consecutive_failures) return {}
  if (!['full_auto', 'until_pause'].includes(state.opus_mode)) return {}
  return {
    decision: 'block',
    reason: `Continue Opus loop. Milestone: ${state.current_milestone}/${state.total_milestones}.`,
    systemMessage: 'Maestro Opus active. Do NOT stop. Execute next milestone via dev-loop.'
  }
}
```

### notification-hook.sh → Notification callback

No shell spawning for osascript or notify-send:

```typescript
Notification: async ({ session }) => {
  const state = session.state as MaestroState | undefined
  if (!state?.active || !['checkpoint', 'paused'].includes(state.phase)) return
  await fetch(process.env.SLACK_WEBHOOK!, {
    method: 'POST',
    body: JSON.stringify({ text: `Maestro needs input — ${state.feature} (${state.phase})` })
  })
}
```

### stop-hook.sh → Stop callback

Block exit during autonomous dev-loop phases:

```typescript
Stop: async ({ session }) => {
  const state = session.state as MaestroState | undefined
  if (!state?.active) return {}
  const autonomous = ['validate', 'delegate', 'implement', 'self_heal', 'qa_review', 'git_craft']
  if (!autonomous.includes(state.phase)) return {}
  return {
    decision: 'block',
    reason: `Continue dev-loop. Story: ${state.current_story}/${state.total_stories}.`,
    systemMessage: `Maestro dev-loop active. Feature: ${state.feature}. Do NOT stop.`
  }
}
```

## Hybrid Approach

Do not replace shell hooks wholesale. Both systems serve different deployment contexts:

| Context | Use |
|---------|-----|
| Claude Code terminal sessions | Shell hooks (`hooks/hooks.json`) |
| Agent SDK bots / CI runners | SDK hooks in TypeScript |
| Plugin distribution | Shell hooks (zero dependencies) |
| Programmatic agents in Node.js monorepo | SDK hooks (colocated with agent code) |

Shell hooks remain the default because they work in any POSIX environment without Node.js and require no build step for distribution. SDK hooks are preferred when spawning agents programmatically in TypeScript, where type-safe returns, in-memory state, and debuggability outweigh distribution simplicity.

Practical pattern: keep `hooks/hooks.json` for terminal users and export an `sdkHooks` object from `hooks/sdk.ts` for programmatic usage — same logic, two surfaces.

## Benefits

- No `jq`/`grep`/`sed` needed — use native property access on typed objects
- Type-safe hook returns — compiler catches malformed decisions at build time
- Full session state in-memory — no file I/O on every hook invocation
- No subprocess spawn — hook runs in the same Node.js process as the agent
- Stack traces and breakpoints instead of log file archaeology
