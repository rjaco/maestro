---
name: agent-sdk
description: "Programmatic Maestro control via @anthropic-ai/claude-agent-sdk (TypeScript) and claude_agent_sdk (Python). Enables CI/CD pipelines, bots, dashboards, and scripts to spawn and drive Maestro sessions."
---

# Agent SDK Integration

Control Maestro programmatically using `@anthropic-ai/claude-agent-sdk` (TypeScript) or `claude_agent_sdk` (Python). Scripts, CI pipelines, bots, and dashboards can invoke Maestro commands and stream results — with full access to skills, MCP servers, and persistent memory.

---

## Quick Start

Get Maestro running from code in under 5 minutes.

### TypeScript

```bash
npm install @anthropic-ai/claude-agent-sdk
```

```typescript
import { query } from '@anthropic-ai/claude-agent-sdk'

for await (const event of query({
  prompt: '/maestro "Add user auth" --yolo',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user']
})) {
  if (event.type === 'result') console.log(event.result)
}
```

### Python

```bash
pip install claude-agent-sdk
```

```python
import claude_agent_sdk

for event in claude_agent_sdk.query(
    prompt='/maestro "Add user auth" --yolo',
    options={
        "cwd": "/path/to/project",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
    },
):
    if event["type"] == "result":
        print(event["result"])
```

That's it. The session runs Maestro inside the project at `cwd`, uses its `.maestro/config.yaml` and installed skills, and streams back every event.

---

## Loading Maestro Skills Programmatically

`settingSources: ['project', 'user']` loads skills from two layers:

| Source | Location | Contains |
|--------|----------|----------|
| `'project'` | `.claude/` in `cwd` | Project-specific skills, CLAUDE.md, MCP servers |
| `'user'` | `~/.claude/` | Globally installed Maestro skills |

Both sources are loaded by default. To load only the project-level Maestro install:

```typescript
// TypeScript — project-only skills
for await (const event of query({
  prompt: '/maestro status',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project']   // omit 'user' for isolation
})) { /* ... */ }
```

```python
# Python — project-only skills
for event in claude_agent_sdk.query(
    prompt='/maestro status',
    options={
        "cwd": "/path/to/project",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project"],
    },
):
    pass
```

Named Maestro skills can be referenced directly in any prompt:

```typescript
// Invoke specific skills by name
for await (const event of query({
  prompt: 'Use the decompose skill to break this down: Build a REST API for user management',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user']
})) {
  if (event.type === 'result') console.log(event.result)
}
```

```python
for event in claude_agent_sdk.query(
    prompt="Use the decompose skill to break this down: Build a REST API for user management",
    options={
        "cwd": "/path/to/project",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
    },
):
    if event["type"] == "result":
        print(event["result"])
```

---

## Dispatching Agents with Maestro's Context Engine

Maestro's `context-engine` skill automatically composes right-sized context packages for each dispatched agent, reducing token usage by 70-85% compared to naive full-context injection.

When you invoke Maestro via the SDK, the context engine runs transparently:

1. It reads your project's `.maestro/dna.md`, `.maestro/stories/`, and CLAUDE.md
2. Scores each context piece for relevance to the current task
3. Assembles a minimal, high-signal package for each sub-agent

You can observe the context engine's decisions by reading `.maestro/context-log.md` after a run.

### Triggering Context-Aware Agent Dispatch

```typescript
// TypeScript — full Maestro orchestration with context engine active
let sessionId: string | undefined

for await (const event of query({
  prompt: '/maestro "Build a REST API for user management" --yolo',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user'],
  resume: sessionId
})) {
  if (event.type === 'system' && event.subtype === 'init') {
    sessionId = event.session_id
  }
  if (event.type === 'tool_use') {
    // Each tool_use event is a context-engine-dispatched sub-agent action
    console.log(`Tool: ${event.name}`, event.input)
  }
  if (event.type === 'result') {
    console.log(event.result)
  }
}
```

```python
# Python — full Maestro orchestration with context engine active
session_id = None

for event in claude_agent_sdk.query(
    prompt='/maestro "Build a REST API for user management" --yolo',
    options={
        "cwd": "/path/to/project",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
        "resume": session_id,
    },
):
    if event["type"] == "system" and event.get("subtype") == "init":
        session_id = event["session_id"]
    elif event["type"] == "tool_use":
        print(f"Tool: {event['name']}", event.get("input"))
    elif event["type"] == "result":
        print(event["result"])
```

The context log written to `.maestro/context-log.md` shows per-agent context packages:

```
[2026-03-18T14:22:01] Story 01-user-auth | Agent: implementer | Tier: T3
  Composed: 3,412 tokens (budget: 4,000-8,000)
  Included: story-spec(312), rules(198), api-patterns(287), file:route.ts[40-80](423)
  Excluded: component-patterns(0.12), vision(0.05), roadmap(0.08)
```

---

## Using forkSession for Parallel Agent Work

`forkSession` creates a copy of the current session state before a risky operation. If the operation fails, the fork is discarded and the original session remains intact. This maps directly to Maestro's `speculative` skill.

### TypeScript

```typescript
import { query } from '@anthropic-ai/claude-agent-sdk'

let stableSessionId: string | undefined

// First, establish a stable session
for await (const event of query({
  prompt: '/maestro init',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user']
})) {
  if (event.type === 'system' && event.subtype === 'init') {
    stableSessionId = event.session_id
  }
}

// Fork before a risky operation
let forkedId: string | undefined
let success = false

for await (const event of query({
  prompt: '/maestro "Migrate to new auth schema" --yolo',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user'],
  resume: stableSessionId,
  options: {
    forkSession: true,
    enableFileCheckpointing: true
  }
})) {
  if (event.type === 'system' && event.subtype === 'init') {
    forkedId = event.session_id
  }
  if (event.type === 'result' && event.subtype === 'success') {
    success = true
    stableSessionId = forkedId  // promotion: fork becomes the new stable
  }
}

if (!success && forkedId) {
  // Migration failed — rewind files to the pre-fork state
  const q = query({
    prompt: 'noop',
    options: { resume: forkedId }
  })
  await q.rewindFiles(stableSessionId!, { dryRun: false })
  await q.close()
  console.log('Migration failed. Files rewound to stable state.')
}
```

### Python

```python
import claude_agent_sdk

stable_session_id = None

# Establish a stable session
for event in claude_agent_sdk.query(
    prompt='/maestro init',
    options={
        "cwd": "/path/to/project",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
    },
):
    if event["type"] == "system" and event.get("subtype") == "init":
        stable_session_id = event["session_id"]

# Fork before a risky operation
forked_id = None
success = False

for event in claude_agent_sdk.query(
    prompt='/maestro "Migrate to new auth schema" --yolo',
    options={
        "cwd": "/path/to/project",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
        "resume": stable_session_id,
        "forkSession": True,
        "enableFileCheckpointing": True,
    },
):
    if event["type"] == "system" and event.get("subtype") == "init":
        forked_id = event["session_id"]
    elif event["type"] == "result" and event.get("subtype") == "success":
        success = True
        stable_session_id = forked_id  # promote fork to stable

if not success:
    print("Migration failed. Stable session preserved.")
```

### Parallel Forks

Run multiple speculative implementations simultaneously and keep whichever succeeds first:

```typescript
// TypeScript — run three implementations in parallel, keep the first that passes QA
const candidates = [
  '/maestro "Implement auth with JWT" --yolo',
  '/maestro "Implement auth with sessions" --yolo',
  '/maestro "Implement auth with OAuth" --yolo',
]

const runs = candidates.map(async (prompt) => {
  let forkId: string | undefined
  for await (const event of query({
    prompt,
    cwd: '/path/to/project',
    permissionMode: 'bypassPermissions',
    settingSources: ['project', 'user'],
    resume: stableSessionId,
    options: { forkSession: true, enableFileCheckpointing: true }
  })) {
    if (event.type === 'system' && event.subtype === 'init') forkId = event.session_id
    if (event.type === 'result' && event.subtype === 'success') return forkId
  }
  return null
})

const winner = (await Promise.any(runs.map(p => p.then(id => id ?? Promise.reject()))))
console.log('Winning session:', winner)
```

---

## Reading Maestro State Files

Maestro maintains two state files in `.maestro/`. SDK integrations can read these to monitor progress, extract structured data, or trigger external workflows.

### State File Locations

| File | Purpose | Access |
|------|---------|--------|
| `.maestro/state.md` | Shared project state — completed features, history | Version-controlled |
| `.maestro/state.local.md` | Active session state — current run, metrics | Git-ignored |

### state.md Format

The shared state file tracks completed features and project history:

```markdown
# Maestro Project State

## Features Completed
- 2026-03-18 Add user authentication (OAuth + JWT)
- 2026-03-18 REST API for user management

## Current Session
No active session.

## History
- 2026-03-17 Maestro initialized
- 2026-03-18 Milestone 1 completed (4 stories, 3h 12m, ~$2.40)
```

### state.local.md Format

The local state file is YAML front matter followed by free-text notes. It holds the active session's runtime data:

```yaml
---
maestro_version: "1.3.0"
active: true
session_id: "b8e4d291-7f3a-4c1e-a9b2-5d8f6e3c1a7b"
feature: "Add user authentication"
mode: yolo                     # yolo | checkpoint | manual
layer: opus                    # opus | sonnet
current_story: 2
total_stories: 4
phase: implementing            # planning | implementing | qa | done
current_milestone: 1
total_milestones: 3
milestones:
  M1: pending                  # pending | in_progress | completed | failed
  M2: pending
  M3: pending
fix_cycle: 0
max_fix_cycles: 3
token_budget: 10.00
time_budget_hours: 4
consecutive_failures: 0
max_consecutive_failures: 5
started_at: "2026-03-18T18:05:00Z"
last_updated: "2026-03-18T22:34:20Z"
token_spend: 1.42
estimated_remaining: 8.58
---
NORTH STAR: Make Maestro indistinguishable from an official Anthropic product.
Mode: yolo
Branch: development
```

### Parsing State Files in TypeScript

```typescript
import { readFileSync } from 'fs'
import { parse as parseYaml } from 'yaml'

interface MaestroState {
  maestro_version: string
  active: boolean
  session_id: string
  feature: string
  mode: 'yolo' | 'checkpoint' | 'manual'
  layer: 'opus' | 'sonnet'
  current_story: number
  total_stories: number
  phase: string
  current_milestone: number
  total_milestones: number
  milestones: Record<string, string>
  fix_cycle: number
  token_spend: number
  estimated_remaining: number
  started_at: string
  last_updated: string
}

function readMaestroState(projectRoot: string): MaestroState | null {
  try {
    const raw = readFileSync(`${projectRoot}/.maestro/state.local.md`, 'utf-8')
    const match = raw.match(/^---\n([\s\S]+?)\n---/)
    if (!match) return null
    return parseYaml(match[1]) as MaestroState
  } catch {
    return null  // No active session
  }
}

// Usage
const state = readMaestroState('/path/to/project')
if (state?.active) {
  console.log(`Story ${state.current_story}/${state.total_stories} — $${state.token_spend} spent`)
}
```

### Parsing State Files in Python

```python
import re
import yaml
from pathlib import Path

def read_maestro_state(project_root: str) -> dict | None:
    """Parse .maestro/state.local.md and return the YAML front matter as a dict."""
    state_path = Path(project_root) / ".maestro" / "state.local.md"
    try:
        raw = state_path.read_text()
        match = re.match(r"^---\n([\s\S]+?)\n---", raw)
        if not match:
            return None
        return yaml.safe_load(match.group(1))
    except FileNotFoundError:
        return None  # No active session

# Usage
state = read_maestro_state("/path/to/project")
if state and state.get("active"):
    pct = (state["current_story"] / state["total_stories"] * 100) if state["total_stories"] else 0
    print(f"Story {state['current_story']}/{state['total_stories']} ({pct:.0f}%) — ${state['token_spend']:.2f} spent")
```

### Polling State in Real Time

```python
import time
import yaml
import re
from pathlib import Path

def watch_maestro(project_root: str, poll_interval: float = 2.0):
    """Stream state updates while a Maestro session is active."""
    state_path = Path(project_root) / ".maestro" / "state.local.md"
    last_updated = None

    while True:
        try:
            raw = state_path.read_text()
            match = re.match(r"^---\n([\s\S]+?)\n---", raw)
            if match:
                state = yaml.safe_load(match.group(1))
                if state.get("last_updated") != last_updated:
                    last_updated = state["last_updated"]
                    yield state
                if not state.get("active"):
                    return
        except FileNotFoundError:
            pass
        time.sleep(poll_interval)

# Usage
for state in watch_maestro("/path/to/project"):
    print(f"[{state['last_updated']}] Phase: {state['phase']} | Story: {state['current_story']}/{state['total_stories']}")
```

---

## Core Integration Pattern

### TypeScript — `query` function

```typescript
import { query } from '@anthropic-ai/claude-agent-sdk'

let sessionId: string | undefined

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

### Python — `query` function

```python
import claude_agent_sdk

session_id = None

for event in claude_agent_sdk.query(
    prompt='/maestro "Add user auth" --yolo',
    options={
        "cwd": "/path/to/project",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
        "resume": session_id,
    },
):
    if event["type"] == "system" and event.get("subtype") == "init":
        session_id = event["session_id"]
    if event["type"] == "result":
        print(event["result"])
```

---

## Event Types

| Event type | Subtype | Key fields | Purpose |
|------------|---------|------------|---------|
| `system` | `init` | `session_id` | Capture ID for session resumption |
| `assistant` | — | `text` | Stream Maestro's response live |
| `tool_use` | — | `name`, `input` | Monitor tool calls for logging or audit |
| `result` | `success` | `result`, `total_cost_usd`, `modelUsage` | Final output when the turn completes |
| `result` | `error_max_budget_usd` | — | Budget cap reached |

---

## Use Cases

### CI/CD Integration

```typescript
// TypeScript — triggered by GitHub Actions on PR open
for await (const event of query({
  prompt: `/maestro "${process.env.PR_TITLE}" --yolo`,
  cwd: process.env.GITHUB_WORKSPACE!,
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user']
})) {
  if (event.type === 'result') console.log(event.result)
}
```

```python
# Python — triggered by GitHub Actions on PR open
import os
import claude_agent_sdk

for event in claude_agent_sdk.query(
    prompt=f'/maestro "{os.environ["PR_TITLE"]}" --yolo',
    options={
        "cwd": os.environ["GITHUB_WORKSPACE"],
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
    },
):
    if event["type"] == "result":
        print(event["result"])
```

### Scheduled Automation

```typescript
// TypeScript — cron: 0 9 * * * — daily health check
for await (const _ of query({
  prompt: '/health-score --report',
  cwd: '/srv/myproject',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user']
})) { /* drain */ }
```

```python
# Python — daily health check
for _ in claude_agent_sdk.query(
    prompt='/health-score --report',
    options={
        "cwd": "/srv/myproject",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
    },
):
    pass
```

### Telegram Bot

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

### Web Dashboard

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

### Multi-Project Orchestration

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

```python
import asyncio
import claude_agent_sdk

async def health_check(cwd: str):
    for event in claude_agent_sdk.query(
        prompt='/health-score',
        options={
            "cwd": cwd,
            "permissionMode": "bypassPermissions",
            "settingSources": ["project", "user"],
        },
    ):
        if event["type"] == "result":
            print(f"[{cwd}]", event["result"])

projects = ["/srv/api", "/srv/frontend", "/srv/infra"]
asyncio.run(asyncio.gather(*[health_check(p) for p in projects]))
```

---

## Session Management

Each project or chat context gets its own session ID. Sessions enable multi-turn conversations — Maestro remembers context, open stories, and state across calls.

Persist session IDs between process restarts using SQLite or a JSON file:

```typescript
// TypeScript — SQLite (recommended for bots and multi-user contexts)
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

```python
# Python — SQLite
import sqlite3
from pathlib import Path

db = sqlite3.connect(".maestro/sessions.db")
db.execute("CREATE TABLE IF NOT EXISTS sessions (key TEXT PRIMARY KEY, session_id TEXT, updated_at TEXT)")
db.commit()

def save_session(key: str, session_id: str):
    db.execute("INSERT OR REPLACE INTO sessions VALUES (?, ?, datetime())", (key, session_id))
    db.commit()

def load_session(key: str) -> str | None:
    row = db.execute("SELECT session_id FROM sessions WHERE key = ?", (key,)).fetchone()
    return row[0] if row else None
```

To start a fresh session (equivalent to `/newchat`), omit `resume`. The next `init` event carries the new session ID.

---

## Safety Considerations

`bypassPermissions` disables all tool confirmation prompts — required for non-interactive use but grants full write/run access to the project.

- **Allowlist callers** — restrict by chat ID, user ID, or IP before processing any prompt
- **Validate `cwd`** — never let callers set `cwd` to arbitrary paths
- **Rate limit** — prevent runaway sessions in bot-facing deployments
- **Monitor costs** — use token-ledger or log `result` event metadata; set spend alerts
- **Audit `tool_use` events** — log every tool call to detect unexpected actions
- **Treat as root access** — never expose SDK endpoints publicly without authentication

---

## Advanced Patterns (v0.1.0+)

### Cost Tracking with modelUsage

The SDK provides per-model cost breakdown on every result:

```typescript
// TypeScript
if (event.type === 'result') {
  console.log(`Total: $${event.total_cost_usd}`)
  for (const [model, usage] of Object.entries(event.modelUsage)) {
    console.log(`  ${model}: $${usage.costUSD} (${usage.inputTokens}in/${usage.outputTokens}out)`)
  }
}
```

```python
# Python
if event["type"] == "result":
    print(f"Total: ${event['total_cost_usd']}")
    for model, usage in event.get("modelUsage", {}).items():
        print(f"  {model}: ${usage['costUSD']} ({usage['inputTokens']}in/{usage['outputTokens']}out)")
```

Maestro's `token-ledger` and `cost-dashboard` skills can consume this data for per-story and per-agent cost breakdowns.

### Budget Caps

```typescript
// TypeScript
const q = query({
  prompt: '/maestro "Build auth system" --yolo',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user'],
  options: { maxBudgetUsd: 5.00 }
})
// result.subtype === "error_max_budget_usd" when hit
```

```python
# Python
for event in claude_agent_sdk.query(
    prompt='/maestro "Build auth system" --yolo',
    options={
        "cwd": "/path/to/project",
        "permissionMode": "bypassPermissions",
        "settingSources": ["project", "user"],
        "maxBudgetUsd": 5.00,
    },
):
    if event["type"] == "result" and event.get("subtype") == "error_max_budget_usd":
        print("Budget cap reached.")
```

### Dynamic MCP Server Management

```typescript
const q = query({ prompt: '...', options: { mcpServers: {} } })
// Later, add a new server
await q.setMcpServers({ 'my-db': { type: 'stdio', command: 'db-mcp' } })
```

### V2 API Preview (Multi-Turn Sessions)

Simplified interface for interactive or chat-style Maestro usage:

```typescript
import { unstable_v2_createSession } from '@anthropic-ai/claude-agent-sdk'

await using session = unstable_v2_createSession({
  model: 'claude-opus-4-6',
  settingSources: ['project', 'user'],
  systemPrompt: { type: 'preset', preset: 'claude_code' }
})

await session.send('/maestro init')
for await (const msg of session.stream()) { /* handle init */ }

await session.send('/maestro "Add user auth" --yolo')
for await (const msg of session.stream()) { /* handle build */ }
```

### Programmatic Hooks (SDK-Native)

Replace shell-based hooks with in-process TypeScript:

```typescript
for await (const event of query({
  prompt: '...',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user'],
  options: {
    hooks: {
      PreToolUse: [{
        matcher: 'Bash',
        hooks: [async (input) => {
          if (input.tool_input?.command?.includes('rm -rf')) {
            return {
              hookSpecificOutput: {
                hookEventName: 'PreToolUse',
                permissionDecision: 'deny',
                permissionDecisionReason: 'Destructive command blocked by Maestro'
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

---

## Integration with Maestro Skills

When invoked via the SDK, all Maestro skills behave identically to interactive use:

- All `/maestro` commands and skill names work as normal
- `settingSources: ['project', 'user']` loads `.maestro/config.yaml` and skills from both layers
- MCP servers configured in the project are available
- Memory (`.claude/agent-memory/`) and state (`.maestro/state.md`) persist across calls
- `--yolo` mode, checkpoints, and multi-story runs behave the same as in the terminal
- The `ecosystem` skill detects SDK mode automatically — interactive prompts are suppressed and output is structured for programmatic consumption
