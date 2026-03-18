---
name: agent-sdk
description: "Programmatic Maestro control via @anthropic-ai/claude-agent-sdk. Enables CI/CD pipelines, bots, dashboards, and scripts to spawn and drive Maestro sessions."
---

# Agent SDK Integration

Control Maestro programmatically using `@anthropic-ai/claude-agent-sdk`. Scripts, CI pipelines, bots, and dashboards can invoke Maestro commands and stream results — with full access to skills, MCP servers, and persistent memory.

## Core Integration Pattern

```typescript
import { query } from '@anthropic-ai/claude-agent-sdk'

for await (const event of query({
  prompt: '/maestro "Add user auth" --yolo',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user'],
  resume: sessionId  // omit to start a fresh session
})) {
  if (event.type === 'system' && event.subtype === 'init') sessionId = event.session_id
  if (event.type === 'result') console.log(event.result)
}
```

| Parameter | Description |
|-----------|-------------|
| `prompt` | Any Maestro command or plain instruction |
| `cwd` | Project root — determines which `.maestro/` config loads |
| `permissionMode` | `'bypassPermissions'` skips all tool confirmations |
| `settingSources` | `['project', 'user']` loads skills from both layers |
| `resume` | Session ID from a prior `init` event — multi-turn continuity |

## Event Types

| Event type | Subtype | Key fields | Purpose |
|------------|---------|------------|---------|
| `system` | `init` | `session_id` | Capture ID for session resumption |
| `assistant` | — | `text` | Stream Maestro's response live |
| `tool_use` | — | `name`, `input` | Monitor tool calls for logging or audit |
| `result` | — | `result` | Final output text when the turn completes |

## Use Cases

### 1. CI/CD Integration

```typescript
// scripts/maestro-ci.ts — triggered by GitHub Actions on PR open
for await (const event of query({
  prompt: `/maestro "${process.env.PR_TITLE}" --yolo`,
  cwd: process.env.GITHUB_WORKSPACE!,
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user']
})) {
  if (event.type === 'result') console.log(event.result)
}
```

### 2. Scheduled Automation

```typescript
// cron: 0 9 * * * — daily health check
for await (const _ of query({
  prompt: '/health-score --report',
  cwd: '/srv/myproject',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user']
})) { /* drain */ }
```

### 3. Telegram Bot

Route chat messages to Maestro with per-chat session continuity:

```typescript
import { Bot } from 'grammy'
import { query } from '@anthropic-ai/claude-agent-sdk'

const sessions = new Map<number, string>()  // chat_id → session_id
const ALLOWED = new Set([parseInt(process.env.ALLOWED_CHAT_ID!)])

const bot = new Bot(process.env.TELEGRAM_TOKEN!)

bot.on('message:text', async (ctx) => {
  if (!ALLOWED.has(ctx.chat.id)) return

  let resultText = ''
  for await (const event of query({
    prompt: ctx.message.text,
    cwd: process.env.PROJECT_ROOT!,
    permissionMode: 'bypassPermissions',
    settingSources: ['project', 'user'],
    resume: sessions.get(ctx.chat.id)
  })) {
    if (event.type === 'system' && event.subtype === 'init')
      sessions.set(ctx.chat.id, event.session_id)
    if (event.type === 'result') resultText = event.result
  }

  await ctx.reply(resultText || 'Done.')
})

bot.start()
```

### 4. Web Dashboard

Stream events to a browser via Server-Sent Events:

```typescript
app.post('/api/maestro', async (req, res) => {
  if (!isAuthenticated(req)) return res.status(401).end()
  res.setHeader('Content-Type', 'text/event-stream')
  for await (const event of query({
    prompt: req.body.command,
    cwd: req.body.project,
    permissionMode: 'bypassPermissions',
    settingSources: ['project', 'user'],
    resume: req.body.sessionId
  })) {
    res.write(`data: ${JSON.stringify(event)}\n\n`)
  }
  res.end()
})
```

### 5. Multi-Project Orchestration

Manage multiple repos from one controller:

```typescript
const projects = ['/srv/api', '/srv/frontend', '/srv/infra']

await Promise.all(projects.map(async (cwd) => {
  for await (const event of query({
    prompt: '/health-score',
    cwd,
    permissionMode: 'bypassPermissions',
    settingSources: ['project', 'user']
  })) {
    if (event.type === 'result') console.log(`[${cwd}]`, event.result)
  }
}))
```

## Session Management

Each project or chat context gets its own session ID. Sessions enable multi-turn conversations — Maestro remembers context, open stories, and state across calls.

Persist session IDs between process restarts using SQLite or a JSON file:

```typescript
// SQLite — recommended for bots and multi-user contexts
import Database from 'better-sqlite3'

const db = new Database('.maestro/sessions.db')
db.prepare(`CREATE TABLE IF NOT EXISTS sessions (
  key TEXT PRIMARY KEY, session_id TEXT, updated_at TEXT
)`).run()

const save = (key: string, id: string) =>
  db.prepare('INSERT OR REPLACE INTO sessions VALUES (?, ?, datetime())').run(key, id)

const load = (key: string): string | undefined =>
  (db.prepare('SELECT session_id FROM sessions WHERE key = ?').get(key) as any)?.session_id
```

To start a fresh session (equivalent to `/newchat`), omit `resume`. The next `init` event carries the new session ID.

## Safety Considerations

`bypassPermissions` disables all tool confirmation prompts — required for non-interactive use but grants full write/run access to the project.

- **Allowlist callers** — restrict by chat ID, user ID, or IP before processing any prompt
- **Validate `cwd`** — never let callers set `cwd` to arbitrary paths
- **Rate limit** — prevent runaway sessions in bot-facing deployments
- **Monitor costs** — use token-ledger or log `result` event metadata; set spend alerts
- **Audit `tool_use` events** — log every tool call to detect unexpected actions
- **Treat as root access** — never expose SDK endpoints publicly without authentication

## Advanced Patterns (v0.1.0+)

### forkSession — Speculative Execution

Fork a session before risky operations. If the fork fails, discard it; if it succeeds, keep it:

```typescript
// Fork from a stable point
let forkedId: string | undefined
for await (const msg of query({
  prompt: "Try migrating to the new auth schema",
  options: {
    resume: stableSessionId,
    forkSession: true,
    enableFileCheckpointing: true
  }
})) {
  if (msg.type === "system" && msg.subtype === "init") forkedId = msg.session_id
  if (msg.type === "result" && msg.subtype === "success") {
    // Migration worked — keep the fork
    stableSessionId = forkedId!
  }
  if (msg.type === "result" && msg.subtype !== "success") {
    // Migration failed — rewind files and discard fork
    const q = query({ prompt: "noop", options: { resume: forkedId } })
    await q.rewindFiles(stableSessionId, { dryRun: false })
    await q.close()
  }
}
```

This pattern maps directly to Maestro's `speculative` skill — risky story implementations can fork first, validate, then commit.

### Cost Tracking with modelUsage

The SDK provides per-model cost breakdown on every result:

```typescript
if (msg.type === "result") {
  console.log(`Total: $${msg.total_cost_usd}`)
  for (const [model, usage] of Object.entries(msg.modelUsage)) {
    console.log(`  ${model}: $${usage.costUSD} (${usage.inputTokens}in/${usage.outputTokens}out)`)
  }
}
```

Maestro's `token-ledger` and `cost-dashboard` skills can consume this data for per-story and per-agent cost breakdowns.

### Budget Caps

```typescript
const q = query({
  prompt: '/maestro "Build auth system" --yolo',
  options: { maxBudgetUsd: 5.00 }
})
// result.subtype === "error_max_budget_usd" when hit
```

### Dynamic MCP Server Management

Add or remove MCP servers mid-session:

```typescript
const q = query({ prompt: "...", options: { mcpServers: {} } })
// Later, add a new server
await q.setMcpServers({ "my-db": { type: "stdio", command: "db-mcp" } })
```

### V2 API Preview (Multi-Turn Sessions)

Simplified interface for interactive/chat-style Maestro usage:

```typescript
import { unstable_v2_createSession } from "@anthropic-ai/claude-agent-sdk"

await using session = unstable_v2_createSession({
  model: "claude-opus-4-6",
  settingSources: ["project", "user"],
  systemPrompt: { type: "preset", preset: "claude_code" }
})

await session.send('/maestro init')
for await (const msg of session.stream()) { /* handle init */ }

await session.send('/maestro "Add user auth" --yolo')
for await (const msg of session.stream()) { /* handle build */ }
```

### Programmatic Hooks (SDK-Native)

Replace shell-based hooks with in-process TypeScript:

```typescript
for await (const msg of query({
  prompt: "...",
  options: {
    hooks: {
      PreToolUse: [{
        matcher: "Bash",
        hooks: [async (input) => {
          if (input.tool_input?.command?.includes("rm -rf")) {
            return {
              hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: "Destructive command blocked by Maestro"
              }
            }
          }
          return {}
        }]
      }],
      SubagentStop: [{
        hooks: [async (input) => {
          console.log(`Agent ${input.agent_id} completed (${input.agent_type})`)
          return {}
        }]
      }]
    }
  }
})) { /* ... */ }
```

This enables real-time subagent tracking, custom security gates, and structured logging without subprocess overhead.

## Integration with Maestro Skills

When invoked via the SDK, all Maestro skills behave identically to interactive use:

- All `/maestro` commands and skill names work as normal
- `settingSources: ['project', 'user']` loads `.maestro/config.yaml` and skills from both layers
- MCP servers configured in the project are available
- Memory (`.claude/agent-memory/`) and state (`.maestro/state.md`) persist across calls
- `--yolo` mode, checkpoints, and multi-story runs behave the same as in the terminal
