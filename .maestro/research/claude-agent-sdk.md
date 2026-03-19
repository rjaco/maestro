# Research: Anthropic Claude Agent SDK — March 2026

Comprehensive technical research on the `@anthropic-ai/claude-agent-sdk` (formerly Claude Code SDK).
This document covers every API surface, configuration option, event type, and pattern relevant to Maestro.

---

## Package Identity

| Attribute | Value |
|:---|:---|
| npm package | `@anthropic-ai/claude-agent-sdk` |
| Python package | `claude-agent-sdk` |
| Old npm name | `@anthropic-ai/claude-code` |
| Old Python name | `claude-code-sdk` |
| GitHub (TS) | `github.com/anthropics/claude-agent-sdk-typescript` |
| GitHub (Python) | `github.com/anthropics/claude-agent-sdk-python` |
| Demos repo | `github.com/anthropics/claude-agent-sdk-demos` |
| Official docs | `platform.claude.com/docs/en/agent-sdk/overview` |

**Architecture:** The SDK spawns the Claude Code CLI as a subprocess. The CLI communicates with the Anthropic API. The SDK wraps this subprocess with a typed async generator interface. You do NOT need Claude Code installed separately — the SDK bundles its own executable.

---

## Core API — TypeScript

### `query()` — primary function

```typescript
function query({
  prompt,
  options
}: {
  prompt: string | AsyncIterable<SDKUserMessage>;
  options?: Options;
}): Query;
```

Returns a `Query` object which extends `AsyncGenerator<SDKMessage, void>`.

**Usage:**
```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const message of query({
  prompt: "Find and fix the bug in auth.ts",
  options: { allowedTools: ["Read", "Edit", "Bash"], permissionMode: "acceptEdits" }
})) {
  if (message.type === "result" && message.subtype === "success") {
    console.log(message.result);
    console.log(`Cost: $${message.total_cost_usd}`);
  }
}
```

### `query()` — streaming input / multi-turn (V1)

```typescript
async function* generateMessages() {
  yield {
    type: "user" as const,
    session_id: "",
    message: { role: "user" as const, content: "Turn 1 prompt" },
    parent_tool_use_id: null
  };
  // yield more as needed
}

for await (const message of query({ prompt: generateMessages(), options: { ... } })) { ... }
```

### `Query` object — methods

The `Query` object has these callable methods (some only available in streaming input mode):

| Method | Description |
|:---|:---|
| `interrupt()` | Interrupt a running query (streaming mode only) |
| `rewindFiles(userMessageId, { dryRun? })` | Restore files to their state at a past message. Requires `enableFileCheckpointing: true` |
| `setPermissionMode(mode)` | Change permission mode mid-session (streaming mode only) |
| `setModel(model?)` | Change model mid-session (streaming mode only) |
| `initializationResult()` | Full init data: commands, models, agents, account |
| `supportedCommands()` | Available slash commands |
| `supportedModels()` | Available models with display info |
| `supportedAgents()` | Available subagents |
| `mcpServerStatus()` | Status of connected MCP servers |
| `accountInfo()` | Account information |
| `reconnectMcpServer(name)` | Reconnect a named MCP server |
| `toggleMcpServer(name, enabled)` | Enable/disable an MCP server |
| `setMcpServers(servers)` | Replace MCP servers dynamically |
| `streamInput(stream)` | Feed additional user messages for multi-turn |
| `stopTask(taskId)` | Stop a background task by ID |
| `close()` | Terminate the subprocess and clean up |

### `tool()` — create custom MCP tool

```typescript
function tool<Schema extends AnyZodRawShape>(
  name: string,
  description: string,
  inputSchema: Schema,             // Zod 3 or Zod 4 schema
  handler: (args: InferShape<Schema>, extra: unknown) => Promise<CallToolResult>,
  extras?: { annotations?: ToolAnnotations }  // readOnly, destructive, openWorld
): SdkMcpToolDefinition<Schema>;
```

### `createSdkMcpServer()` — in-process MCP server

```typescript
function createSdkMcpServer(options: {
  name: string;
  version?: string;
  tools?: Array<SdkMcpToolDefinition<any>>;
}): McpSdkServerConfigWithInstance;
```

### `listSessions()` — enumerate past sessions

```typescript
function listSessions(options?: {
  dir?: string;          // project dir (omit = all projects)
  limit?: number;
  includeWorktrees?: boolean;  // default: true
}): Promise<SDKSessionInfo[]>;
```

`SDKSessionInfo` fields: `sessionId`, `summary`, `lastModified`, `fileSize`, `customTitle`, `firstPrompt`, `gitBranch`, `cwd`.

### `getSessionMessages()` — read session transcript

```typescript
function getSessionMessages(
  sessionId: string,
  options?: { dir?: string; limit?: number; offset?: number }
): Promise<SessionMessage[]>;
```

---

## `Options` — complete configuration reference

All fields on the options object passed to `query()`:

| Field | Type | Default | Description |
|:---|:---|:---|:---|
| `abortController` | `AbortController` | new AbortController() | Cancel operations |
| `additionalDirectories` | `string[]` | `[]` | Extra dirs Claude can access |
| `agent` | `string` | `undefined` | Name of agent to use for main thread |
| `agents` | `Record<string, AgentDefinition>` | `undefined` | Programmatic subagent definitions |
| `allowDangerouslySkipPermissions` | `boolean` | `false` | Required when using `bypassPermissions` |
| `allowedTools` | `string[]` | `[]` | Pre-approve these tools (others fall through to `permissionMode`) |
| `betas` | `SdkBeta[]` | `[]` | Enable beta features e.g. `['context-1m-2025-08-07']` |
| `canUseTool` | `CanUseTool` | `undefined` | Custom runtime permission callback |
| `continue` | `boolean` | `false` | Continue most recent session in cwd |
| `cwd` | `string` | `process.cwd()` | Working directory |
| `debug` | `boolean` | `false` | Enable debug mode |
| `debugFile` | `string` | `undefined` | Write debug logs to file |
| `disallowedTools` | `string[]` | `[]` | Always deny these tools (overrides everything incl. bypassPermissions) |
| `effort` | `'low' \| 'medium' \| 'high' \| 'max'` | `'high'` | Reasoning depth |
| `enableFileCheckpointing` | `boolean` | `false` | Track file changes for `rewindFiles()` |
| `env` | `Record<string, string \| undefined>` | `process.env` | Env vars. `CLAUDE_AGENT_SDK_CLIENT_APP` = User-Agent label |
| `executable` | `'bun' \| 'deno' \| 'node'` | auto | JS runtime to use |
| `executableArgs` | `string[]` | `[]` | Args to the runtime |
| `extraArgs` | `Record<string, string \| null>` | `{}` | Additional CLI args |
| `fallbackModel` | `string` | `undefined` | Model to use if primary fails |
| `forkSession` | `boolean` | `false` | When resuming, create a fork instead of continuing |
| `hooks` | `Partial<Record<HookEvent, HookCallbackMatcher[]>>` | `{}` | Hook callbacks |
| `includePartialMessages` | `boolean` | `false` | Emit `stream_event` messages (live text deltas) |
| `maxBudgetUsd` | `number` | `undefined` | Spend cap in USD |
| `maxTurns` | `number` | `undefined` | Tool-use round trip cap |
| `mcpServers` | `Record<string, McpServerConfig>` | `{}` | MCP server configs |
| `model` | `string` | CLI default | Model ID e.g. `"claude-sonnet-4-6"` |
| `outputFormat` | `{ type: 'json_schema', schema: JSONSchema }` | `undefined` | Structured output schema |
| `pathToClaudeCodeExecutable` | `string` | bundled | Override CLI executable path |
| `permissionMode` | `PermissionMode` | `'default'` | Global permission mode |
| `permissionPromptToolName` | `string` | `undefined` | MCP tool for permission prompts |
| `persistSession` | `boolean` | `true` | Set false for in-memory only (not resumable) |
| `plugins` | `SdkPluginConfig[]` | `[]` | Load local plugins |
| `promptSuggestions` | `boolean` | `false` | Emit predicted next prompt after each turn |
| `resume` | `string` | `undefined` | Session ID to resume |
| `resumeSessionAt` | `string` | `undefined` | Resume at a specific message UUID |
| `sandbox` | `SandboxSettings` | `undefined` | Sandbox configuration |
| `sessionId` | `string` | auto-generated | Pin a specific UUID for this session |
| `settingSources` | `SettingSource[]` | `[]` | Which filesystem settings to load |
| `spawnClaudeCodeProcess` | `(options) => SpawnedProcess` | `undefined` | Custom subprocess spawner (for VMs, containers) |
| `stderr` | `(data: string) => void` | `undefined` | Callback for stderr output |
| `strictMcpConfig` | `boolean` | `false` | Strict MCP validation |
| `systemPrompt` | `string \| { type: 'preset'; preset: 'claude_code'; append?: string }` | `undefined` | Override system prompt |
| `thinking` | `ThinkingConfig` | `{ type: 'adaptive' }` | Controls reasoning/thinking behavior |
| `toolConfig` | `ToolConfig` | `undefined` | Built-in tool config (`askUserQuestion.previewFormat`) |
| `tools` | `string[] \| { type: 'preset'; preset: 'claude_code' }` | `undefined` | Override full tool list |

---

## Message Types — complete SDKMessage union

```typescript
type SDKMessage =
  | SDKAssistantMessage         // type: "assistant"
  | SDKUserMessage              // type: "user"
  | SDKUserMessageReplay        // type: "user", isReplay: true
  | SDKResultMessage            // type: "result"
  | SDKSystemMessage            // type: "system", subtype: "init"
  | SDKPartialAssistantMessage  // type: "stream_event" (partial streaming)
  | SDKCompactBoundaryMessage   // type: "system", subtype: "compact_boundary"
  | SDKStatusMessage
  | SDKHookStartedMessage
  | SDKHookProgressMessage
  | SDKHookResponseMessage
  | SDKToolProgressMessage
  | SDKAuthStatusMessage
  | SDKTaskNotificationMessage
  | SDKTaskStartedMessage
  | SDKTaskProgressMessage
  | SDKFilesPersistedEvent
  | SDKToolUseSummaryMessage
  | SDKRateLimitEvent
  | SDKPromptSuggestionMessage;
```

### Key message shapes

**SDKSystemMessage (init)**
```typescript
{
  type: "system";
  subtype: "init";
  uuid: string;
  session_id: string;
  agents?: string[];
  apiKeySource: string;
  betas?: string[];
  claude_code_version: string;
  cwd: string;
  tools: string[];
  mcp_servers: { name: string; status: string; }[];
  model: string;
  permissionMode: PermissionMode;
  slash_commands: string[];
  output_style: string;
  skills: string[];
  plugins: { name: string; path: string; }[];
}
```

**SDKAssistantMessage**
```typescript
{
  type: "assistant";
  uuid: string;
  session_id: string;
  message: BetaMessage;         // Anthropic SDK type — has .content, .usage, .id, .model, .stop_reason
  parent_tool_use_id: string | null;
  error?: 'authentication_failed' | 'billing_error' | 'rate_limit' | 'invalid_request' | 'server_error' | 'unknown';
}
```

**SDKResultMessage**
```typescript
// Success
{
  type: "result";
  subtype: "success";
  uuid: string;
  session_id: string;
  duration_ms: number;
  duration_api_ms: number;
  is_error: false;
  num_turns: number;
  result: string;                              // Final text output
  stop_reason: string | null;                  // "end_turn" | "max_tokens" | "refusal"
  total_cost_usd: number;
  usage: NonNullableUsage;
  modelUsage: { [modelName: string]: ModelUsage };
  permission_denials: SDKPermissionDenial[];
  structured_output?: unknown;
}

// Error variants (no `result` field)
{
  type: "result";
  subtype: "error_max_turns" | "error_during_execution" | "error_max_budget_usd" | "error_max_structured_output_retries";
  // ... same fields as success except no `result`
  errors: string[];
}
```

**SDKCompactBoundaryMessage**
```typescript
{
  type: "system";
  subtype: "compact_boundary";
  uuid: string;
  session_id: string;
  compact_metadata: {
    trigger: "manual" | "auto";
    pre_tokens: number;
  };
}
```

---

## Permission System

### Permission evaluation order (highest to lowest priority)

1. **Hooks** — can allow, deny, or pass through
2. **Deny rules** (`disallowedTools`) — always blocks, even in `bypassPermissions`
3. **Permission mode** — global behavior for unresolved tools
4. **Allow rules** (`allowedTools`) — pre-approves listed tools
5. **`canUseTool` callback** — runtime interactive approval

### Permission modes

| Mode | Behavior | Python available? |
|:---|:---|:---|
| `"default"` | Unmatched tools call `canUseTool`; no callback = deny | Yes |
| `"dontAsk"` | Unmatched tools denied without prompting (no `canUseTool`) | No (TS only) |
| `"acceptEdits"` | Auto-approves: Edit, Write, mkdir, touch, rm, mv, cp | Yes |
| `"bypassPermissions"` | All tools approved (deny rules and hooks still apply) | Yes |
| `"plan"` | No tool execution; planning text only | Yes |

**Warning:** `allowedTools` does NOT constrain `bypassPermissions`. In bypass mode, every tool runs regardless of `allowedTools`. Use `disallowedTools` for hard blocks.

### Dynamic permission change

```typescript
const q = query({ prompt: "...", options: { permissionMode: "default" } });
await q.setPermissionMode("acceptEdits");  // Change mid-stream
for await (const message of q) { ... }
```

### `CanUseTool` callback

```typescript
type CanUseTool = (
  toolName: string,
  input: Record<string, unknown>,
  options: {
    signal: AbortSignal;
    suggestions?: PermissionUpdate[];
    blockedPath?: string;
    decisionReason?: string;
    toolUseID: string;
    agentID?: string;
  }
) => Promise<PermissionResult>;

type PermissionResult =
  | { behavior: "allow"; updatedInput?: Record<string, unknown>; updatedPermissions?: PermissionUpdate[]; toolUseID?: string; }
  | { behavior: "deny"; message: string; interrupt?: boolean; toolUseID?: string; };
```

---

## Session Management

### Session storage location

Sessions stored at: `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`
Where `<encoded-cwd>` = absolute path with non-alphanumeric chars replaced by `-`.

### Session options

| Option | When to use |
|:---|:---|
| Neither (default) | One-shot task, no resumption needed |
| `continue: true` | Continue most recent session in cwd (no ID tracking) |
| `resume: sessionId` | Resume a specific session by ID |
| `forkSession: true` + `resume` | Branch from a session without modifying original |
| `persistSession: false` | In-memory only, not written to disk (TS only) |
| `resumeSessionAt: uuid` | Resume at a specific message within a session |

### Capturing session ID

```typescript
// Session ID available on BOTH init system message AND result message
for await (const message of query({ prompt: "..." })) {
  if (message.type === "system" && message.subtype === "init") {
    sessionId = message.session_id;  // Available early
  }
  if (message.type === "result") {
    sessionId = message.session_id;  // Authoritative, always present
  }
}
```

### Fork pattern

```typescript
let forkedId: string | undefined;
for await (const message of query({
  prompt: "Try OAuth2 instead",
  options: { resume: sessionId, forkSession: true }
})) {
  if (message.type === "system" && message.subtype === "init") {
    forkedId = message.session_id;  // Fork gets a new ID
  }
}
// Original sessionId unchanged; forkedId is the new branch
```

### Resume across hosts

Session files are machine-local. To resume on another host:
1. Copy `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl` to same path on target
2. Or: capture key outputs as application state and inject into a fresh session prompt

---

## Subagents

### AgentDefinition schema

```typescript
type AgentDefinition = {
  description: string;                              // Required: tells Claude when to invoke
  prompt: string;                                   // Required: subagent system prompt
  tools?: string[];                                 // Tool allowlist (omit = inherit all)
  disallowedTools?: string[];                       // Explicit tool blocklist
  model?: "sonnet" | "opus" | "haiku" | "inherit"; // Model override
  mcpServers?: AgentMcpServerSpec[];                // MCP servers for this agent
  skills?: string[];                                // Skills to preload
  maxTurns?: number;                                // Turn cap for this subagent
  criticalSystemReminder_EXPERIMENTAL?: string;     // Experimental system reminder
};
```

### Creating subagents

```typescript
for await (const message of query({
  prompt: "Use the code-reviewer agent to review auth module",
  options: {
    allowedTools: ["Read", "Grep", "Glob", "Agent"],  // Agent tool required
    agents: {
      "code-reviewer": {
        description: "Expert code reviewer for security and quality reviews. Use when reviewing code.",
        prompt: "You are a code review specialist. Identify security issues and suggest improvements.",
        tools: ["Read", "Grep", "Glob"],  // Read-only
        model: "sonnet"
      },
      "test-runner": {
        description: "Runs test suites and analyzes failures.",
        prompt: "You are a test specialist. Run tests and diagnose failures.",
        tools: ["Bash", "Read", "Grep"]
      }
    }
  }
})) { ... }
```

### What subagents inherit vs. do NOT inherit

| Subagent receives | Subagent does NOT receive |
|:---|:---|
| Its own system prompt (`AgentDefinition.prompt`) | Parent's conversation history |
| Agent tool's prompt string (the only channel from parent) | Parent's system prompt |
| Project CLAUDE.md (via `settingSources`) | Parent's tool results |
| Tool definitions (from `tools` field) | Skills (unless listed in `skills` field, TS only) |

### Subagent detection in message stream

```typescript
for (const block of msg.message?.content ?? []) {
  // Both "Task" (old) and "Agent" (new) names appear across SDK versions
  if (block.type === "tool_use" && (block.name === "Task" || block.name === "Agent")) {
    console.log(`Subagent invoked: ${block.input.subagent_type}`);
  }
}
// Messages from within a subagent have:
if (msg.parent_tool_use_id) { /* running inside subagent */ }
```

### Parallel subagents

Multiple subagents can run concurrently — the SDK will coordinate them. This is the primary mechanism for parallelizing work.

**Subagents cannot spawn their own subagents.** Do not include `Agent` in a subagent's `tools` array.

---

## Hooks System

### Available hook events

| Hook Event | Python | TypeScript | Trigger |
|:---|:---:|:---:|:---|
| `PreToolUse` | Y | Y | Before a tool executes (can block/modify) |
| `PostToolUse` | Y | Y | After a tool returns |
| `PostToolUseFailure` | Y | Y | On tool execution error |
| `UserPromptSubmit` | Y | Y | When a prompt is submitted |
| `Stop` | Y | Y | When agent finishes execution |
| `SubagentStart` | Y | Y | When a subagent spawns |
| `SubagentStop` | Y | Y | When a subagent completes |
| `PreCompact` | Y | Y | Before context compaction |
| `PermissionRequest` | Y | Y | When a permission dialog would show |
| `Notification` | Y | Y | Agent status messages |
| `SessionStart` | N | Y | Session initialization |
| `SessionEnd` | N | Y | Session termination |
| `Setup` | N | Y | Session setup/maintenance |
| `TeammateIdle` | N | Y | Teammate becomes idle |
| `TaskCompleted` | N | Y | Background task completes |
| `ConfigChange` | N | Y | Config file changes |
| `WorktreeCreate` | N | Y | Git worktree created |
| `WorktreeRemove` | N | Y | Git worktree removed |

### Hook callback signature

```typescript
type HookCallback = (
  input: HookInput,
  toolUseID: string | undefined,
  options: { signal: AbortSignal }
) => Promise<HookJSONOutput>;
```

### HookCallbackMatcher

```typescript
interface HookCallbackMatcher {
  matcher?: string;     // Regex matched against tool name (for tool hooks)
  hooks: HookCallback[];
  timeout?: number;     // Seconds (default: 60)
}
```

### Hook inputs — key shapes

All inputs extend `BaseHookInput`:
```typescript
type BaseHookInput = {
  session_id: string;
  transcript_path: string;
  cwd: string;
  permission_mode?: string;
  agent_id?: string;
  agent_type?: string;
};
```

Key hook-specific fields:
- `PreToolUseHookInput`: `tool_name`, `tool_input`, `tool_use_id`
- `PostToolUseHookInput`: `tool_name`, `tool_input`, `tool_response`, `tool_use_id`
- `PostToolUseFailureHookInput`: `tool_name`, `tool_input`, `tool_use_id`, `error`, `is_interrupt?`
- `StopHookInput`: `stop_hook_active`, `last_assistant_message?`
- `SubagentStartHookInput`: `agent_id`, `agent_type`
- `SubagentStopHookInput`: `agent_id`, `agent_type`, `agent_transcript_path`, `stop_hook_active`
- `NotificationHookInput`: `message`, `title?`, `notification_type`
- `SessionStartHookInput`: `source` (`"startup" | "resume" | "clear" | "compact"`), `agent_type?`, `model?`
- `SessionEndHookInput`: `reason` (ExitReason)
- `UserPromptSubmitHookInput`: `prompt`

### Hook outputs

```typescript
// Allow (empty = allow with no changes)
return {};

// Block
return {
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Reason shown to Claude"
  }
};

// Modify input
return {
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    updatedInput: { ...originalInput, file_path: "/sandbox" + originalPath }
  }
};

// Inject context + block
return {
  systemMessage: "System reminder injected into conversation",
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "..."
  }
};

// Async (non-blocking side effect)
return { async: true, asyncTimeout: 30000 };
```

**Priority:** `deny` overrides `ask` overrides `allow` when multiple hooks apply.

---

## Built-in Tools

| Tool | Category | Description |
|:---|:---|:---|
| `Read` | File | Read any file in working directory |
| `Write` | File | Create new files |
| `Edit` | File | Make precise edits to existing files |
| `Bash` | Execution | Run terminal commands, scripts, git |
| `Glob` | Search | Find files by pattern |
| `Grep` | Search | Search file contents with regex |
| `WebSearch` | Web | Search the web |
| `WebFetch` | Web | Fetch and parse web pages |
| `AskUserQuestion` | Interaction | Ask user clarifying questions with options |
| `Agent` | Orchestration | Invoke a subagent |
| `Skill` | Orchestration | Invoke a skill |
| `TodoWrite` | Orchestration | Track tasks |
| `ToolSearch` | Discovery | Find and load tools on-demand |

**MCP tool naming:** `mcp__{server_name}__{tool_name}`

---

## Custom Tools (In-Process MCP)

```typescript
import { query, tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

const server = createSdkMcpServer({
  name: "my-tools",
  version: "1.0.0",
  tools: [
    tool(
      "fetch_data",
      "Fetch data from an API endpoint",
      { endpoint: z.string().url(), params: z.record(z.string()).optional() },
      async (args) => {
        const res = await fetch(args.endpoint);
        return { content: [{ type: "text", text: await res.text() }] };
      },
      { annotations: { readOnly: true } }  // Enables parallel execution
    )
  ]
});

// Custom tools require streaming input mode (async generator prompt)
async function* messages() {
  yield { type: "user" as const, session_id: "", message: { role: "user" as const, content: "..." }, parent_tool_use_id: null };
}

for await (const msg of query({
  prompt: messages(),
  options: {
    mcpServers: { "my-tools": server },
    allowedTools: ["mcp__my-tools__fetch_data"]
  }
})) { ... }
```

**Note:** Custom MCP tools require streaming input mode (async generator). A plain string `prompt` will not work with in-process MCP servers.

---

## MCP Server Configuration Types

```typescript
type McpServerConfig =
  | { type?: "stdio"; command: string; args?: string[]; env?: Record<string, string>; }
  | { type: "sse"; url: string; headers?: Record<string, string>; }
  | { type: "http"; url: string; headers?: Record<string, string>; }
  | { type: "sdk"; name: string; instance: McpServer; }  // In-process
  | { type: "claudeai-proxy"; url: string; id: string; };
```

---

## Cost Tracking

### ResultMessage cost fields

```typescript
// On SDKResultMessage (both success and error variants):
total_cost_usd: number          // Authoritative total for this query() call
usage: {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens: number;  // Higher rate than input tokens
  cache_read_input_tokens: number;      // Lower rate than input tokens
}
modelUsage: {
  [modelName: string]: {
    costUSD: number;
    inputTokens: number;
    outputTokens: number;
    cacheReadInputTokens: number;
    cacheCreationInputTokens: number;
  }
}
duration_ms: number
duration_api_ms: number
num_turns: number
```

### Per-step usage (TypeScript only)

Each `SDKAssistantMessage.message.usage` has token counts per API call. When Claude uses parallel tools, multiple messages share the same `message.id` — deduplicate by ID to avoid double-counting.

### Accumulating across multiple query() calls

The SDK does NOT provide a session-level total. Accumulate manually:
```typescript
let totalSpend = 0;
for (const prompt of prompts) {
  for await (const msg of query({ prompt })) {
    if (msg.type === "result") totalSpend += msg.total_cost_usd ?? 0;
  }
}
```

### Budget cap

```typescript
options: { maxBudgetUsd: 0.50 }  // Stop after $0.50 spent
// ResultMessage.subtype === "error_max_budget_usd" when hit
```

---

## Setting Sources — Filesystem Config Loading

By default (v0.1.0+), the SDK loads NO filesystem settings. You must opt in explicitly.

```typescript
type SettingSource = "user" | "project" | "local";
```

| Source | Loads from |
|:---|:---|
| `"user"` | `~/.claude/settings.json`, `~/.claude/CLAUDE.md`, `~/.claude/rules/*.md` |
| `"project"` | `./.claude/settings.json`, `./CLAUDE.md`, `./.claude/rules/*.md`, `./.claude/skills/` |
| `"local"` | `./CLAUDE.local.md`, `./.claude/settings.local.json` |

**Precedence (highest → lowest):** local > project > user. Programmatic options always override filesystem settings.

**To load CLAUDE.md you also need:**
```typescript
systemPrompt: { type: "preset", preset: "claude_code" }
```

---

## V2 API Preview (Unstable)

A simplified interface replacing the async generator pattern:

```typescript
import {
  unstable_v2_createSession,
  unstable_v2_resumeSession,
  unstable_v2_prompt
} from "@anthropic-ai/claude-agent-sdk";

// One-shot
const result = await unstable_v2_prompt("What is 2+2?", { model: "claude-opus-4-6" });

// Multi-turn session (TypeScript 5.2+ `await using` auto-closes)
await using session = unstable_v2_createSession({ model: "claude-opus-4-6" });

await session.send("Turn 1");
for await (const msg of session.stream()) { /* handle messages */ }

await session.send("Turn 2");
for await (const msg of session.stream()) { /* handle messages */ }

// Resume
await using resumed = unstable_v2_resumeSession(sessionId, { model: "claude-opus-4-6" });
```

`SDKSession` interface:
```typescript
interface SDKSession {
  readonly sessionId: string;
  send(message: string | SDKUserMessage): Promise<void>;
  stream(): AsyncGenerator<SDKMessage, void>;
  close(): void;
}
```

**V2 limitations:** No `forkSession`, some advanced streaming patterns not yet ported. Not recommended for production.

---

## Breaking Changes from Claude Code SDK (v0.0.x → Claude Agent SDK v0.1.0)

| What changed | Before | After |
|:---|:---|:---|
| Package name | `@anthropic-ai/claude-code` | `@anthropic-ai/claude-agent-sdk` |
| Python options type | `ClaudeCodeOptions` | `ClaudeAgentOptions` |
| System prompt default | Claude Code preset loaded | No system prompt (minimal) |
| Settings sources default | All filesystem settings loaded | No filesystem settings loaded |

**Migration:** Update imports; add `settingSources: ["user", "project", "local"]` to restore old behavior; add `systemPrompt: { type: "preset", preset: "claude_code" }` to restore old system prompt.

---

## Authentication

```bash
# Anthropic direct
export ANTHROPIC_API_KEY=your-key

# Amazon Bedrock
export CLAUDE_CODE_USE_BEDROCK=1
# + AWS credentials

# Google Vertex AI
export CLAUDE_CODE_USE_VERTEX=1
# + GCloud credentials

# Microsoft Azure AI Foundry
export CLAUDE_CODE_USE_FOUNDRY=1
# + Azure credentials
```

---

## Effort Levels

| Level | Reasoning depth | Best for |
|:---|:---|:---|
| `"low"` | Minimal | File lookups, directory listing |
| `"medium"` | Balanced | Routine edits, standard tasks |
| `"high"` | Thorough (default) | Refactors, debugging |
| `"max"` | Maximum depth | Multi-step problems, deep analysis |

TypeScript defaults to `"high"`. Python leaves unset (model default).

---

## Community Projects Built on SDK

| Project | Description |
|:---|:---|
| `23blocks-OS/ai-maestro` | Multi-agent orchestration with Claude Code, Next.js, CozoDB, tmux |
| `ruvnet/ruflo` | Multi-agent swarm platform with RAG integration |
| `jeremylongshore/claude-code-plugins-plus-skills` | 340 plugins + 1367 agent skills marketplace |
| `hesreallyhim/awesome-claude-code` | Curated skills, hooks, commands, orchestrators |
| `rohitg00/awesome-claude-code-toolkit` | 135 agents, 42 commands, 150+ plugins |
| `mbruhler/claude-orchestration` | Multi-agent workflow orchestration plugin |
| `wshobson/agents` | Intelligent automation and multi-agent orchestration |

---

## Demo Projects (Official)

| Demo | Pattern illustrated |
|:---|:---|
| `hello-world` | Basic `query()` loop |
| `hello-world-v2` | V2 `send()`/`stream()` API |
| `research-agent` | **Multi-agent**: coordinator + parallel researcher subagents + synthesis |
| `email-agent` | IMAP integration with agentic search |
| `resume-generator` | Web search + `.docx` generation |
| `simple-chat-app` | React + Express + WebSocket streaming |
| `ask-user-question-previews` | Interactive UI with HTML preview cards + `canUseTool` WebSocket |
| `excel-demo` | Spreadsheet manipulation |

---

## Patterns and Best Practices

### Context isolation via subagents
Each subagent starts with a fresh conversation. Only its final message returns to the parent. Use subagents for any subtask that would otherwise bloat the main context.

### Minimal tool surfaces
Scope subagents to the minimum tools they need. Every tool definition adds context. Use `ToolSearch` for on-demand loading instead of preloading all MCP tools.

### Effort tuning for cost
Set `effort: "low"` for simple lookup agents. Reserve `"max"` for complex reasoning tasks. This is the simplest cost lever.

### Session persistence strategy
For multi-user or distributed systems, capture session IDs and persist them in your database. Reconstruct sessions by copying `.jsonl` files or by injecting prior context into fresh session prompts.

### CLAUDE.md for persistent instructions
Instructions that need to survive context compaction belong in CLAUDE.md, not in the prompt. CLAUDE.md is re-injected on every API request.

### PreCompact hook for transcript archiving
Register a `PreCompact` hook to archive the full conversation before the compactor summarizes it. The hook receives `trigger: "manual" | "auto"`.

### Hooks for security boundaries
Use `PreToolUse` hooks to enforce hard blocks (`disallowedTools` is the simplest mechanism but hooks allow context-aware logic like checking file paths or command patterns).

### Dynamic MCP servers
`setMcpServers()` on the `Query` object lets you add/remove MCP servers mid-session without restarting.

---

## Maestro Enhancement Opportunities

### 1. Session registry
Maestro's orchestrator could use `listSessions()` and `getSessionMessages()` to build a session picker UI, letting users resume past agent runs. The `SDKSessionInfo.gitBranch` field enables per-branch session filtering.

### 2. SDK-native hooks replacing shell hooks
Maestro currently uses filesystem hooks (shell scripts in `.claude/hooks/`). Migrating to programmatic hooks via the SDK's `hooks` option would enable:
- In-process logic without subprocess overhead
- Structured returns (`updatedInput`, `systemMessage`)
- Per-query hook configuration
- `SubagentStart` / `SubagentStop` for real-time subagent tracking

### 3. Cost tracking dashboard
`SDKResultMessage.modelUsage` breaks costs down per model. Maestro could aggregate these across all agent runs and surface them in a cost dashboard or enforce per-agent spend limits via `maxBudgetUsd`.

### 4. Parallel subagent orchestration
The research-agent demo shows the canonical pattern: a coordinator agent that spawns multiple specialist subagents in parallel. Maestro's dispatcher could use this natively instead of running separate CLI processes.

### 5. `forkSession` for speculative execution
Maestro could fork a session before risky operations, allow the fork to proceed, then either commit (keep fork) or abandon (revert to original) based on outcome. Combine with `enableFileCheckpointing` + `rewindFiles()` for filesystem rollback.

### 6. V2 API for Maestro's multi-turn CLI chat
The V2 `createSession()` + `send()`/`stream()` pattern maps cleanly onto Maestro's interactive chat loop. Each user message becomes a `send()` call; the stream yields progress.

### 7. `settingSources` for project-aware agents
Maestro agents that need access to CLAUDE.md, skills, and hooks from the current project should pass `settingSources: ["project"]`. This integrates Maestro's existing skill and hook infrastructure with SDK-spawned agents.

### 8. `spawnClaudeCodeProcess` for sandboxing
For Maestro's multi-tenant or isolated-workspace mode, the `spawnClaudeCodeProcess` hook allows running the Claude Code subprocess inside a Docker container, VM, or nsjail sandbox without changing SDK call sites.

### 9. `canUseTool` for interactive approval in Maestro UI
Maestro could surface a tool approval UI by providing a `canUseTool` callback that sends a WebSocket message to the frontend and waits for the user's allow/deny response. The `ask-user-question-previews` demo shows this exact pattern.

### 10. `promptSuggestions: true` for guided UX
Enable `promptSuggestions` to get predicted next prompts after each turn. Maestro's UI could surface these as quick-action chips.

---

## Sources

- [Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [TypeScript SDK reference](https://platform.claude.com/docs/en/agent-sdk/typescript)
- [TypeScript V2 preview](https://platform.claude.com/docs/en/agent-sdk/typescript-v2-preview)
- [Python SDK reference](https://platform.claude.com/docs/en/agent-sdk/python)
- [How the agent loop works](https://platform.claude.com/docs/en/agent-sdk/agent-loop)
- [Sessions guide](https://platform.claude.com/docs/en/agent-sdk/sessions)
- [Permissions guide](https://platform.claude.com/docs/en/agent-sdk/permissions)
- [Hooks guide](https://platform.claude.com/docs/en/agent-sdk/hooks)
- [Subagents guide](https://platform.claude.com/docs/en/agent-sdk/subagents)
- [Custom tools guide](https://platform.claude.com/docs/en/agent-sdk/custom-tools)
- [Cost tracking guide](https://platform.claude.com/docs/en/agent-sdk/cost-tracking)
- [Claude Code features in SDK](https://platform.claude.com/docs/en/agent-sdk/claude-code-features)
- [Migration guide](https://platform.claude.com/docs/en/agent-sdk/migration-guide)
- [Quickstart](https://platform.claude.com/docs/en/agent-sdk/quickstart)
- [SDK demos repo](https://github.com/anthropics/claude-agent-sdk-demos)
- [TypeScript SDK repo](https://github.com/anthropics/claude-agent-sdk-typescript)
- [Python SDK repo](https://github.com/anthropics/claude-agent-sdk-python)
- [Promptfoo provider docs](https://www.promptfoo.dev/docs/providers/claude-agent-sdk/)
- [Community: awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
