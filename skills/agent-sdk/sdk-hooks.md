# SDK-Native Hooks — Reference and Examples

Reference for Maestro's Agent SDK programmatic hooks. Shell hooks remain the default for Claude Code terminal usage. SDK hooks are for Agent SDK / bot / CI integrations.

---

## Hook Event Reference

All 18 hook events with their TypeScript callback signatures.

### Tool Lifecycle

| Hook | Fires when | Callback signature | Return type |
|------|-----------|-------------------|-------------|
| **PreToolUse** | Before any tool executes | `(ctx: { tool: string; input: Record<string, unknown>; session: Session }) => Promise<PreToolUseResult>` | `{}` (allow) or `{ permissionDecision: 'deny'; reason: string }` or `{ input: Record<string, unknown> }` (modify) |
| **PostToolUse** | After tool completes | `(ctx: { tool: string; input: Record<string, unknown>; output: unknown; session: Session }) => Promise<void>` | `void` |
| **PreToolUseApproval** | Before user approval prompt | `(ctx: { tool: string; input: Record<string, unknown>; session: Session }) => Promise<{ approved: boolean }>` | `{ approved: true }` to skip prompt |
| **ToolError** | Tool call throws | `(ctx: { tool: string; input: Record<string, unknown>; error: Error; session: Session }) => Promise<void>` | `void` |
| **PermissionDenied** | PreToolUse hook denies a call | `(ctx: { tool: string; input: Record<string, unknown>; reason: string }) => Promise<void>` | `void` |

### Session Lifecycle

| Hook | Fires when | Callback signature | Return type |
|------|-----------|-------------------|-------------|
| **Stop** | Agent is about to exit | `(ctx: { session: Session; reason: string }) => Promise<StopResult>` | `{}` (allow) or `{ decision: 'block'; reason: string; systemMessage?: string }` |
| **SubagentStart** | Sub-agent (Agent tool) begins | `(ctx: { subagentId: string; prompt: string; session: Session }) => Promise<{ prompt?: string }>` | `{}` or `{ prompt: string }` (modify) |
| **SubagentStop** | Sub-agent finishes | `(ctx: { subagentId: string; output: string; session: Session }) => Promise<void>` | `void` |
| **SessionEnd** | Session fully torn down | `(ctx: { session: Session; finalState: unknown }) => Promise<void>` | `void` |
| **MaxTokensReached** | Context limit hit | `(ctx: { tokenCount: number; session: Session }) => Promise<void>` | `void` |

### Compaction

| Hook | Fires when | Callback signature | Return type |
|------|-----------|-------------------|-------------|
| **PreCompact** | Before context window is compressed | `(ctx: { tokenCount: number; session: Session }) => Promise<void>` | `void` |
| **PostCompact** | After compaction completes | `(ctx: { summary: string; session: Session }) => Promise<void>` | `void` |

### Messages and Streaming

| Hook | Fires when | Callback signature | Return type |
|------|-----------|-------------------|-------------|
| **Notification** | Claude generates a notification | `(ctx: { message: string; type: string; session: Session }) => Promise<void>` | `void` |
| **UserMessage** | User message added to conversation | `(ctx: { message: string; session: Session }) => Promise<{ message?: string }>` | `{}` or `{ message: string }` (modify) |
| **AssistantMessage** | Claude produces a response | `(ctx: { message: string; session: Session }) => Promise<void>` | `void` |
| **StreamStart** | Streaming response begins | `(ctx: { session: Session }) => Promise<void>` | `void` |
| **StreamChunk** | Each streaming token chunk arrives | `(ctx: { chunk: string; session: Session }) => Promise<void>` | `void` |
| **StreamEnd** | Streaming completes | `(ctx: { fullText: string; session: Session }) => Promise<void>` | `void` |

---

## Copy-Pasteable Examples

### PreToolUse — block destructive Bash commands

Prevents `rm -rf` and `git reset --hard` before they execute. Returns a deny decision with a human-readable reason.

```typescript
import { Agent } from '@anthropic-ai/agent-sdk'

const DESTRUCTIVE_PATTERNS: RegExp[] = [
  /rm\s+-rf?\s+[^-]/,        // rm -rf <path>
  /git\s+reset\s+--hard/,    // git reset --hard
  /git\s+push\s+--force/,    // git push --force
  /git\s+clean\s+-f/,        // git clean -f
  /chmod\s+-R\s+777/,        // chmod -R 777
  />\s*\/dev\/sd[a-z]/,      // write to raw block device
]

const agent = new Agent({
  model: 'claude-opus-4-6',
  hooks: {
    PreToolUse: async ({ tool, input }) => {
      if (tool !== 'Bash') return {}
      const cmd = (input.command as string | undefined) ?? ''
      const match = DESTRUCTIVE_PATTERNS.find(p => p.test(cmd))
      if (match) {
        return {
          permissionDecision: 'deny',
          reason: `Destructive command blocked by Maestro safety hook: matched pattern ${match}`,
        }
      }
      return {}
    },
  },
})
```

---

### PostToolUse — log tool duration and token usage

Tracks elapsed time per tool call and accumulates token usage from the session. Useful for profiling long-running agent runs.

```typescript
import { Agent } from '@anthropic-ai/agent-sdk'
import * as fs from 'node:fs/promises'

interface ToolMetrics {
  tool: string
  durationMs: number
  inputTokens?: number
  outputTokens?: number
  timestamp: string
}

const toolStartTimes = new Map<string, number>()
const metricsLog: ToolMetrics[] = []

const agent = new Agent({
  model: 'claude-opus-4-6',
  hooks: {
    PreToolUse: async ({ tool }) => {
      toolStartTimes.set(tool, Date.now())
      return {}
    },
    PostToolUse: async ({ tool, session }) => {
      const startTime = toolStartTimes.get(tool)
      const durationMs = startTime ? Date.now() - startTime : -1
      toolStartTimes.delete(tool)

      const usage = (session as any).usage
      const entry: ToolMetrics = {
        tool,
        durationMs,
        inputTokens: usage?.input_tokens,
        outputTokens: usage?.output_tokens,
        timestamp: new Date().toISOString(),
      }
      metricsLog.push(entry)

      // Flush every 10 entries to avoid losing data on crash
      if (metricsLog.length % 10 === 0) {
        await fs.appendFile(
          '/tmp/maestro-tool-metrics.jsonl',
          metricsLog.slice(-10).map(e => JSON.stringify(e)).join('\n') + '\n',
        )
      }
    },
  },
})
```

---

### Stop — save HANDOFF.md on session end

Writes a handoff file so the next agent session (or human reviewer) can pick up exactly where this one left off.

```typescript
import { Agent } from '@anthropic-ai/agent-sdk'
import * as fs from 'node:fs/promises'
import * as path from 'node:path'

const agent = new Agent({
  model: 'claude-opus-4-6',
  hooks: {
    Stop: async ({ session, reason }) => {
      const state = (session as any).state ?? {}
      const handoffPath = path.join(process.cwd(), 'HANDOFF.md')

      const content = [
        '# Maestro Session Handoff',
        '',
        `Generated: ${new Date().toISOString()}`,
        `Stop reason: ${reason}`,
        '',
        '## Session State',
        '```json',
        JSON.stringify(state, null, 2),
        '```',
        '',
        '## Last Active Story',
        state.current_story ? `- Story: ${state.current_story}` : '- No active story',
        state.current_milestone ? `- Milestone: ${state.current_milestone}/${state.total_milestones}` : '',
        '',
        '## Resume Instructions',
        '1. Review the session state above',
        '2. Run `/maestro status` to check current branch and worktrees',
        '3. Continue from the last milestone or re-delegate the story',
      ].filter(line => line !== undefined).join('\n')

      await fs.writeFile(handoffPath, content, 'utf8')
      console.log(`[maestro:Stop] Handoff written to ${handoffPath}`)

      // Allow the stop to proceed
      return {}
    },
  },
})
```

---

### SubagentStart / SubagentStop — track active agents and log completion times

Maintains a live registry of running sub-agents and records how long each one ran.

```typescript
import { Agent } from '@anthropic-ai/agent-sdk'

interface AgentRecord {
  subagentId: string
  prompt: string
  startedAt: number
}

const activeAgents = new Map<string, AgentRecord>()
const completionLog: Array<{ subagentId: string; durationMs: number; completedAt: string }> = []

const agent = new Agent({
  model: 'claude-opus-4-6',
  hooks: {
    SubagentStart: async ({ subagentId, prompt }) => {
      activeAgents.set(subagentId, {
        subagentId,
        prompt: prompt.slice(0, 120),   // store a preview, not the full prompt
        startedAt: Date.now(),
      })
      console.log(`[maestro:SubagentStart] ${subagentId} started (${activeAgents.size} active)`)
      return {}
    },

    SubagentStop: async ({ subagentId, output }) => {
      const record = activeAgents.get(subagentId)
      if (record) {
        const durationMs = Date.now() - record.startedAt
        activeAgents.delete(subagentId)
        completionLog.push({
          subagentId,
          durationMs,
          completedAt: new Date().toISOString(),
        })
        console.log(
          `[maestro:SubagentStop] ${subagentId} finished in ${(durationMs / 1000).toFixed(1)}s` +
          ` (${activeAgents.size} still active)`,
        )
      }
    },
  },
})

// Expose for inspection (useful in tests or monitoring endpoints)
export function getActiveAgents() {
  return Array.from(activeAgents.values())
}
export function getCompletionLog() {
  return [...completionLog]
}
```

---

### PreCompact — archive conversation before compaction

Snapshots the current conversation history to disk before the compaction algorithm discards it. Keeps a rolling archive so no context is permanently lost.

```typescript
import { Agent } from '@anthropic-ai/agent-sdk'
import * as fs from 'node:fs/promises'
import * as path from 'node:path'

const ARCHIVE_DIR = path.join(process.cwd(), '.maestro', 'compaction-archives')

const agent = new Agent({
  model: 'claude-opus-4-6',
  hooks: {
    PreCompact: async ({ tokenCount, session }) => {
      await fs.mkdir(ARCHIVE_DIR, { recursive: true })

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
      const archivePath = path.join(ARCHIVE_DIR, `pre-compact-${timestamp}.json`)

      const snapshot = {
        archivedAt: new Date().toISOString(),
        tokenCount,
        sessionId: (session as any).id ?? 'unknown',
        messages: (session as any).messages ?? [],
        state: (session as any).state ?? {},
      }

      await fs.writeFile(archivePath, JSON.stringify(snapshot, null, 2), 'utf8')
      console.log(`[maestro:PreCompact] Archived ${tokenCount} tokens to ${archivePath}`)
    },
  },
})
```

---

### WorktreeCreate / WorktreeRemove — log worktree lifecycle

Logs when Maestro creates or removes a git worktree. Keeps a persistent worktree journal for post-mortems and audits.

```typescript
import { Agent } from '@anthropic-ai/agent-sdk'
import * as fs from 'node:fs/promises'
import * as path from 'node:path'

const WORKTREE_LOG = path.join(process.cwd(), '.maestro', 'worktree-journal.jsonl')

async function appendJournal(entry: Record<string, unknown>) {
  await fs.mkdir(path.dirname(WORKTREE_LOG), { recursive: true })
  await fs.appendFile(WORKTREE_LOG, JSON.stringify(entry) + '\n', 'utf8')
}

const agent = new Agent({
  model: 'claude-opus-4-6',
  hooks: {
    WorktreeCreate: async ({ worktreePath, branch, session }: any) => {
      const entry = {
        event: 'create',
        worktreePath,
        branch,
        sessionId: (session as any).id ?? 'unknown',
        timestamp: new Date().toISOString(),
      }
      await appendJournal(entry)
      console.log(`[maestro:WorktreeCreate] ${worktreePath} on branch ${branch}`)
    },

    WorktreeRemove: async ({ worktreePath, session }: any) => {
      const entry = {
        event: 'remove',
        worktreePath,
        sessionId: (session as any).id ?? 'unknown',
        timestamp: new Date().toISOString(),
      }
      await appendJournal(entry)
      console.log(`[maestro:WorktreeRemove] ${worktreePath} removed`)
    },
  },
})
```

---

### UserPromptSubmit — classify user messages

Intercepts incoming user messages and tags them as one of three Maestro-specific intents: `status_check`, `pause`, or `redirect`. Lets downstream orchestration logic branch on intent rather than re-parsing free text.

```typescript
import { Agent } from '@anthropic-ai/agent-sdk'

type MaestroIntent = 'status_check' | 'pause' | 'redirect' | 'unknown'

interface ClassifiedMessage {
  original: string
  intent: MaestroIntent
  classifiedAt: string
}

const STATUS_CHECK_PATTERNS = [/\bstatus\b/i, /what.*happening/i, /where are we/i, /progress/i]
const PAUSE_PATTERNS = [/\bpause\b/i, /\bstop\b/i, /\bhalt\b/i, /wait a moment/i]
const REDIRECT_PATTERNS = [/instead.*do/i, /switch to/i, /\bredirect\b/i, /change.*approach/i]

function classify(message: string): MaestroIntent {
  if (STATUS_CHECK_PATTERNS.some(p => p.test(message))) return 'status_check'
  if (PAUSE_PATTERNS.some(p => p.test(message))) return 'pause'
  if (REDIRECT_PATTERNS.some(p => p.test(message))) return 'redirect'
  return 'unknown'
}

const classifiedLog: ClassifiedMessage[] = []

const agent = new Agent({
  model: 'claude-opus-4-6',
  hooks: {
    UserMessage: async ({ message }) => {
      const intent = classify(message)
      classifiedLog.push({
        original: message.slice(0, 200),
        intent,
        classifiedAt: new Date().toISOString(),
      })

      if (intent !== 'unknown') {
        console.log(`[maestro:UserMessage] intent=${intent}`)
      }

      // Return unmodified — classification is side-effect only
      return {}
    },
  },
})

export function getClassifiedLog() {
  return [...classifiedLog]
}
```

---

## How to Wire Into Maestro

### When to use shell hooks (hooks.json) vs SDK hooks

| Factor | Shell hooks | SDK hooks |
|--------|-------------|-----------|
| **Deployment target** | Claude Code terminal sessions | Agent SDK bots, CI runners, Node.js programs |
| **Dependencies** | Zero — any POSIX shell | Node.js + TypeScript build step |
| **Distribution** | Works everywhere out of the box | Requires project setup |
| **Can modify tool input** | No | Yes — return `{ input: { ...modified } }` |
| **Access to session state** | File-based only | Direct in-memory object access |
| **Debugging** | Log file archaeology | Stack traces and breakpoints |
| **Logic complexity** | Simple scripts (< ~50 lines) | Complex stateful logic |
| **Type safety** | None | Full TypeScript compiler checks |

**Rule of thumb:** if a hook needs to read or write files, send a webhook, or do anything more complex than a regex check, prefer SDK hooks when running programmatically. Keep shell hooks for terminal users who do not run a build step.

### Shell hooks: good for simple scripts, work everywhere, no build step

Shell hooks live in `hooks/hooks.json` and execute as subprocesses. Every hook gets JSON on stdin and must write JSON to stdout. They work for any user of Maestro without installing Node.js or running `npm install`.

```jsonc
// hooks/hooks.json
{
  "hooks": {
    "PreToolUse": [{ "command": "bash hooks/branch-guard.sh" }],
    "Stop":       [{ "command": "bash hooks/stop-hook.sh" }]
  }
}
```

Use shell hooks when:
- You are shipping to users who only have Claude Code installed
- The logic is simple enough that bash + jq is readable
- You want zero-dependency distribution (plugins, shared `hooks/` directories)

### SDK hooks: good for complex logic, can modify tool inputs, in-process

SDK hooks are TypeScript functions registered on the `Agent` constructor. They run in the same Node.js process as the agent — no subprocess spawn, no stdin/stdout serialization.

```typescript
// hooks/sdk.ts — export a hooks object, import it wherever you construct an Agent
export const maestroHooks = {
  PreToolUse: blockDestructiveCommands,
  PostToolUse: logToolMetrics,
  Stop: writeHandoff,
  SubagentStart: trackAgentStart,
  SubagentStop: trackAgentStop,
  PreCompact: archiveBeforeCompact,
  UserMessage: classifyUserIntent,
}

// entrypoint.ts
import { Agent } from '@anthropic-ai/agent-sdk'
import { maestroHooks } from './hooks/sdk.js'

const agent = new Agent({ model: 'claude-opus-4-6', hooks: maestroHooks })
```

Use SDK hooks when:
- You need to modify a tool's input before it executes
- You need in-memory state shared across multiple hook events (e.g., start/stop timing)
- The logic involves async I/O, external APIs, or structured TypeScript types
- You are already running in a Node.js / TypeScript project with a build step

### Hybrid pattern (recommended)

Keep `hooks/hooks.json` for terminal users. Export `maestroHooks` from `hooks/sdk.ts` for programmatic usage. Same logic, two surfaces — no duplication of safety rules.

```
hooks/
  hooks.json       <- terminal users (Claude Code)
  sdk.ts           <- programmatic users (Agent SDK, CI)
  branch-guard.sh  <- shared logic called by hooks.json
```

---

## Prior Migration Examples

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

---

## Benefits

- No `jq`/`grep`/`sed` needed — use native property access on typed objects
- Type-safe hook returns — compiler catches malformed decisions at build time
- Full session state in-memory — no file I/O on every hook invocation
- No subprocess spawn — hook runs in the same Node.js process as the agent
- Stack traces and breakpoints instead of log file archaeology
