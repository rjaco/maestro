# AioX Dashboard — Research Report

**Source:** https://github.com/SynkraAI/aiox-dashboard
**Also mirrored at:** https://github.com/SynkraAI/aios-dashboard
**Date researched:** 2026-03-18
**Researcher:** Maestro research agent

---

## Summary

AioX Dashboard (package name `@aios/dashboard`) is an open-source SPA companion for the `aiox-core` / `aios-core` CLI orchestrator. It is a **web-based observability and control layer** for a multi-agent AI development system. The project is early-stage (v0.5.0, 39 stars, 43 forks, active since Feb 2026) but architecturally rich. It has a clearly stated "CLI First → Observability Second → UI Third" philosophy, meaning the CLI/agents are the system of record and the dashboard is a passive observer with some control affordances.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Vite 7 + React 19 + TypeScript |
| State | Zustand stores (one per domain) |
| Data fetching | TanStack React Query v5 |
| Styling | Tailwind CSS + two custom design systems (see below) |
| Animations | Framer Motion v11 |
| Drag-and-drop | dnd-kit |
| Backend engine | Bun + Hono (lightweight HTTP + WebSocket server) |
| Persistence | Supabase (optional) + localStorage via Zustand persist |
| Real-time transport | WebSocket (`/live`) and SSE (`/stream/agent`) |
| Testing | Vitest + React Testing Library + Playwright e2e |
| Component docs | Storybook 10 (every component has a `.stories.tsx`) |
| Icons | Lucide React |
| Markdown rendering | react-markdown + remark-gfm + rehype-raw |
| ANSI display | ansi-to-html |
| Diagrams | Mermaid |

**Two co-existing design systems:**
1. **Glassmorphism system** — default, dark, frosted-glass aesthetic. CSS custom property tokens, `glass-*` Tailwind utilities, `GlassCard / GlassButton` primitives.
2. **AIOX Cockpit / brutalist system** — activated by `data-theme="aiox"` on `<html>`. No border-radius, monospace body (Roboto Mono), display font (TASAOrbiterDisplay), neon lime (#D1FF00) on near-black (#050505). Cockpit-prefixed components: `CockpitKpiCard`, `CockpitAlert`, `CockpitBadge`, `CockpitSpinner`, `CockpitTickerStrip`, `CockpitFooterBar`, `CockpitStatusIndicator`.

---

## Application Structure (Views)

The app is a single-page application with a sidebar navigation that switches between lazy-loaded view components. From `App.tsx`:

```
dashboard       → DashboardWorkspace (unified overview + cockpit)
stories         → StoryWorkspace (Kanban + list)
agents          → AgentsMonitor
bob / orchestrator → TaskOrchestrator
terminals       → TerminalsView
monitor         → MonitorWorkspace (event feed + timeline)
context         → ContextView
roadmap         → RoadmapView
squads          → SquadsView
github          → GitHubView
qa              → QAMetrics
engine          → EngineWorkspace
knowledge       → KnowledgeView
agent-directory → AgentDirectory
task-catalog    → TaskCatalog
workflow-catalog→ WorkflowCatalog
authority-matrix→ AuthorityMatrix
handoff-flows   → HandoffVisualization
sales-room      → SalesRoomPanel
world           → GatherWorld (avatar-based presence)
settings        → SettingsPage
```

View transitions use Framer Motion `AnimatePresence` with `opacity` + `y` slide-in animations (200ms). Each view is isolated in an `ErrorBoundary` + `Suspense` so crashes are contained.

---

## UI/UX Patterns

### Layout
- Fixed left sidebar for navigation
- Fixed bottom `StatusBar` (28px height) showing real-time global state
- Main content area fills remaining space with `h-full flex flex-col` pattern
- Each view manages its own internal layout (header / scrollable content / footer)
- `FocusModeIndicator` overlay for distraction-free mode
- Global `⌘K` command palette (CommandPalette.tsx, 13KB) — keyboard-first navigation

### StatusBar (always visible, bottom)
Displays continuously:
- Network connectivity (online/offline with `Wifi` / `WifiOff` icon)
- API rate limit counter (`API: N/100`)
- Claude API readiness (`Claude Ready` / `Claude Busy` with pulsing StatusDot)
- Bob orchestrator status (`Bob: Active / Idle` with pulse animation)
- Currently running agent badge (`@dev`, `@qa`, etc.) — sourced from live engine job query
- Notification bell with unread count badge

This is a proven pattern for CLI tool observers: **one persistent status line aggregates the most important real-time signals**.

### GlassCard / GlassButton primitives
Every section is wrapped in `GlassCard` (variant: default / subtle / elevated / error). Buttons have `variant: primary / secondary / ghost / danger` and `size: sm / md / lg`. Both support `leftIcon` / `rightIcon` slots.

### LiveMetricCard (src/components/dashboard/LiveMetricCard.tsx)
A purpose-built animated metric card with:
- Framer Motion spring-animated number counting (via `useSpring` + `useTransform`)
- Value-change pulse animation: scale 1→1.02→1 + glow border for 600ms
- Live dot indicator (breathing green dot, 1.5s cycle via `animate={{ opacity: [1, 0.4, 1] }}`)
- Inline SVG sparkline (last N data points, area fill + polyline)
- Trend indicator (up/down/flat arrow with color coding: green/red/gray)
- Four value formats: `number`, `percent`, `currency`, `duration`

### CockpitDashboard (brutalist theme)
Top-level KPI grid with:
- `CockpitTickerStrip` — horizontally scrolling marquee of key stats (agents online, executions, success rate, MCP tools, latency)
- `CockpitKpiCard` — label / value / trend / change line; no rounded corners
- `CockpitAlert` — left-border-accent alert cards (error/warning/info/success)
- `CockpitSectionDivider` — numbered section headers (`01 / Key Metrics`)
- `CockpitStatusIndicator` — pulse dot for service health
- `CockpitFooterBar` — left/center/right footer strip

KPI tiles displayed: Squads active, Agents online, Executions (with success %), MCP tools + servers, Cost Today / This Month, Latency + throughput.

Service health grid: Claude API, OpenAI API, MCP Servers (N/N), API Gateway — each shows OK/Down badge with pulsing indicator.

Token usage summary: Total tokens, Claude tokens, OpenAI tokens, request count.

---

## How It Visualizes Agent Activity

### Monitor View (src/components/monitor/)
The core real-time view. Components:

**LiveMonitor.tsx** orchestrates:
1. `MetricsPanel` — 4 metric cards (active executions, errors/min, latency ms, throughput req/min)
2. `AgentStatusCards` — per-agent status cards showing current action
3. `CurrentToolIndicator` — when a tool is actively running: animated dots (`...`) + elapsed timer in format `120ms` / `1.2s`
4. `EventList` — scrollable chronological feed of monitor events
5. Stats footer — 4 stat blocks: Total Events, Success Rate %, Error count, Active Sessions

**MonitorEvent types:** `tool_call | message | error | system`

**AgentActivityStore** (agentActivityStore.ts) subscribes to MonitorStore and maintains a `Map<agentKey, AgentLiveActivity>` with:
- Agent name normalization: `"@dev (Dex)"` → `"dex"`
- Action label extraction: `"ToolUse: Read"` → `"Reading file..."`, `"Bash"` → `"Running command..."`, etc.
- 8-second auto-deactivation timeout after last event
- 15-second stale cleanup interval

Action label mappings (terminal-relevant patterns):
```
Read    → Reading file...
Edit    → Editing code...
Write   → Writing file...
Bash    → Running command...
Grep    → Searching code...
Glob    → Finding files...
Agent   → Spawning agent...
WebSearch/WebFetch → Searching web...
message event → Thinking...
error event → Error encountered
```

### ActivityTimeline (src/components/monitor/ActivityTimeline.tsx)
Chronological timeline combining two data sources:
1. Real-time WebSocket events from MonitorStore
2. Historical execution records from Supabase API

Shows relative timestamps (`2min`, `1h`, `3d`). Filterable by event type. Falls back to rich demo data if no real connection.

Demo data structure reveals the system's mental model of events:
- `execution` — build completed, test run, deploy
- `tool_call` — individual file reads/writes/greps
- `message` — inter-agent communication (story assigned, review completed)
- `error` — TypeScript errors, test failures, connection timeouts
- `system` — agent activated, QA gate passed

---

## Kanban Board (Story Management)

**StoryStatus values:** `backlog | in_progress | ai_review | human_review | pr_created | done | error`

This is a 7-column Kanban that maps exactly to an AI-augmented development workflow. Key design decisions:
- `ai_review` and `human_review` are separate columns — explicit gate between AI and human sign-off
- `pr_created` is a distinct status — visible to track PRs not yet merged
- `error` is a first-class status column, not just a filter

**Story fields:** id, title, description, status, priority (`low|medium|high|critical`), complexity (`simple|standard|complex`), category (`feature|fix|refactor|docs`), assignedAgent, epicId, acceptanceCriteria[], technicalNotes, progress (0-100), `bobOrchestrated` boolean, filePath, createdAt, updatedAt.

The `bobOrchestrated` boolean flags stories that were created/managed by the orchestrator agent ("Bob"), giving visibility into autonomous vs human-initiated work.

**KanbanBoard.tsx** uses `dnd-kit` for drag-and-drop between columns. Store includes race-condition guard (`inProgressOps` Set) to prevent duplicate state mutations during rapid drag events.

**Filtering:** status, epicId, free-text search across title/id/description. Store is persisted to localStorage, with merge logic that falls back to sample stories when store is empty.

---

## Metrics and Analytics

From `CockpitDashboard` and `DashboardOverview`:

| Metric | Source | Update frequency |
|---|---|---|
| Squads active count | Engine `/registry/squads` API | Query cache (5 min) |
| Agents online count | Engine `/registry/agents` API | Query cache |
| Executions (total, success rate) | Engine `/jobs` API history | Query cache |
| MCP tools/servers count | Engine `/pool` or separate endpoint | Query cache |
| Cost today / this month | Supabase or engine API | Query cache |
| Avg latency (ms) | Engine `/health` API | Query cache |
| Throughput (req/min) | Engine `/health` or `/pool` API | Query cache |
| CPU / memory | MonitorStore (WebSocket feed) | Real-time |
| Active executions | Engine `/pool` API | Real-time blend |
| Errors/min | MonitorStore computed | Real-time |
| Token usage (total, Claude, OpenAI) | Engine `/execute` history | Query cache |
| LLM health (Claude / OpenAI available) | Engine health endpoint | Query cache |

All query-based data uses TanStack React Query with `staleTime: 5 minutes`, `retry: 1`, `refetchOnWindowFocus: false`, exponential backoff.

**MetricsPanel** merges WebSocket (store) metrics with API (React Query) data: API data takes priority over WebSocket data, providing graceful degradation if API is down.

---

## Real-Time Architecture

### Connection modes (3 tiers):
1. **Local mode** — WebSocket to monitor server at `ws://localhost:4001/stream`. Monitor server is a separate process that captures Claude CLI events.
2. **Engine mode** — WebSocket to engine at `ws://localhost:4002/live`. Engine is the Bun/Hono process that directly spawns CLI agents.
3. **Cloud mode** — WebSocket to a relay server at `VITE_RELAY_URL`. Dashboard connects with `?room=<roomId>&token=<token>` for multi-user scenarios.

Connection selection is determined by `getConnectionConfig()` reading env vars. Automatic fallback: engine unavailable → probe monitor server → connect if available.

### WebSocket protocol (MonitorStore):
- `init` message: sends buffered last-50 events + room state on connect
- `event` message: single new event
- `room_update`: cloud mode — CLI connected/disconnected state
- `pong`: heartbeat response
- Reconnect: exponential backoff, max 5 attempts (1s→2s→4s→8s→16s→30s cap)
- Event buffer: capped at 50 events in memory

### SSE streaming (engine `/stream/agent`):
Maps Claude CLI `--output-format stream-json` output to SSE events:
- `start` — execution begins, with agentId and agentName
- `text` — streamed text delta from Claude
- `tools` — tool_use block detected (tool name, input, success flag)
- `done` — execution complete with duration
- `error` — failure with error message
- `[DONE]` — stream sentinel

Engine also broadcasts WebSocket events (`broadcast('job:started', {...})`) so the monitor view sees job lifecycle events in real time.

### MonitorEvent → AgentActivity bridge:
`agentActivityStore.ts` subscribes to `monitorStore` via `useMonitorStore.subscribe()` and processes only new events (tracked by `lastEventCount`). This is a cross-store reactive pattern without React components.

---

## CLI-to-Dashboard Integration

The engine (`engine/`) is a Bun process that:
1. Reads `.aios-core/` config to discover squads/agents/workflows
2. Maintains a job queue (SQLite via `initDb()`)
3. Spawns `claude` CLI processes via `Bun.spawn()` with `--output-format stream-json`
4. Serves the built dashboard SPA as static files (`dist/` dir)
5. Exposes REST + WebSocket + SSE endpoints for the dashboard to consume

The CLI tool (`aios`) is a separate package (`packages/cli/`) that triggers the engine. The engine is the bridge between CLI invocations and the dashboard.

**Key env vars:**
```
VITE_MONITOR_URL=http://localhost:4001   # separate monitor process
VITE_ENGINE_URL=http://localhost:4002    # engine process
VITE_RELAY_URL=ws://...                 # cloud relay (optional)
VITE_SUPABASE_URL + ANON_KEY           # persistent storage (optional)
```

**Engine config** (`engine.config.yaml`):
- Process pool: max 5 concurrent CLI processes, max 3 per squad
- Spawn timeout: 30s, execution timeout: 5 min
- Workspace: `.workspace/` dir per job, cleaned on success
- Memory: 8000 token context budget, top-10 recall

---

## Terminals View

**TerminalsView.tsx** shows per-agent terminal sessions:
- Grid / List toggle (using same `LayoutGrid / List` icon pattern)
- Up to 12 sessions, capacity shown as `N/12` + ProgressBar in footer
- Each `TerminalCard` shows agent name, status badge, working directory, last few lines
- Clicking a card expands it to full TerminalOutput view
- TerminalTabs at top for quick switching
- New Terminal button spawns a session

Terminal sessions have fields: id, agent, status (`idle|working|...`), dir, story (which story is being worked), output (string[] of lines). The `ansi-to-html` dependency is present to render ANSI escape codes from actual CLI output.

---

## TaskOrchestrator (Bob Orchestration View)

The most complex component (47KB source). Features:
- Natural language task input box
- Plan approval flow: orchestrator proposes a plan, user approves or modifies before execution
- Per-agent output cards with streaming text
- WorkflowCanvas — visual node graph of agent handoffs (using separate `workflow/` components)
- Visual mode toggle — switches from list to canvas view
- Zoom controls for the canvas
- `PhaseProgress` widget — step-by-step phase indicator
- `LiveMetrics` widget — tokens, duration, steps in real-time
- `SquadCard` — which squad/agents are involved
- Task history panel (past orchestrations, filterable)
- SSE-based streaming — uses `EventSource` to consume the engine's `/stream/agent` endpoint

---

## Anti-patterns Observed

1. **Mock data leakage** — Multiple views seed mock/demo data when disconnected (`LiveMonitor.tsx`, `ActivityTimeline.tsx`, `TerminalsView.tsx`). This is architecturally appropriate for a demo-first tool, but means the UI always appears "alive" even when no agents are running, which can mislead.

2. **Hard-coded port assumptions** — Monitor at `:4001`, engine at `:4002`. No service discovery. If ports conflict, users must edit env files.

3. **Two separate backend processes** — Monitor server (`:4001`) and engine (`:4002`) are separate processes. The engine has fallback to the monitor, but two processes to manage increases operational burden. The architecture suggests they were built independently and not yet unified.

4. **50-event buffer cap** — MonitorStore keeps only the last 50 events in memory. For busy agentic sessions this is a very short window, losing historical context quickly.

5. **Token usage metrics not from CLI** — The SSE stream comment says "CLI doesn't expose tokens." Token usage shown in dashboard comes from Supabase or separate API calls, not from the live stream. This creates a gap between real-time and aggregate views.

6. **React Query staleTime 5 minutes** — For an "AI development cockpit" showing active work, 5-minute cache staleness is aggressive. Agents can complete a story in under 5 minutes, meaning the dashboard may show outdated counts.

---

## SEO / Navigation Patterns

Not applicable (internal tool, no SEO). URL sync: `useUrlSync` hook provides bidirectional `currentView` ↔ browser URL sync for deep linking and browser back/forward.

Keyboard navigation:
- `⌘K` / `Ctrl+K` — opens command palette globally
- `?` key — keyboard shortcuts overlay (per storyCard)
- All toggle buttons use `aria-pressed`
- All icon-only buttons require `aria-label` (enforced by CLAUDE.md)
- Grid/list toggles use `role="region"` on container

---

## What Maestro Could Learn (Factual Observations)

The following are direct observations about patterns used in this project, presented without strategic recommendation.

### 1. Persistent global status strip
The StatusBar pattern (7 chars height, bottom of screen, always visible) aggregates the most important signals: connection, LLM health, active agent, notification count. For a CLI tool, this maps directly to a persistent terminal status line shown below the scrollable output.

### 2. Event type taxonomy
The four-type `MonitorEvent` taxonomy (`tool_call | message | error | system`) is minimal and covers the observable surface of Claude CLI sessions via `--output-format stream-json`. The agentActivityStore.ts shows exactly how to parse Claude's stream-json event types into human-readable action labels.

### 3. Three connection modes
Local (monitor process) → Engine (direct CLI wrapper) → Cloud (relay) forms a progressive architecture. The local mode just requires a WebSocket server that captures Claude CLI output. This is the simplest possible integration point.

### 4. Agent name normalization
The `normalizeAgentName` function (`"@dev (Dex)"` → `"dex"`) reveals that aiox-core uses a convention of `@role (Name)` for agent identification. The dashboard fuzzy-matches on normalized names.

### 5. Story status as workflow stages
The 7-status Kanban maps a complete AI-augmented development cycle, with `ai_review` and `human_review` as explicit separate gates. The `bobOrchestrated` boolean tracks autonomy level per story.

### 6. Demo data as specification
The demo/mock data in `ActivityTimeline.tsx` and `LiveMonitor.tsx` defines the exact shape and semantics of real events. Demo data is indistinguishable from real data by design — a forcing function for the real implementation.

### 7. WebSocket init buffer
The `init` message pattern (server sends last-50 events on connect) means the dashboard is immediately useful on reconnect without manual refresh. The client-side 50-event ring buffer is the limiting factor.

### 8. SSE for agent execution, WebSocket for monitoring
The architecture uses SSE for request-response streaming (execute an agent, stream its output) and WebSocket for persistent event feeds (monitoring all agent activity). These are used for distinct purposes, not interchangeably.

### 9. Metrics merge pattern
`MetricsPanel` merges two data sources: API (accurate, slightly stale) and WebSocket (real-time, possibly incomplete). API data takes priority. This graceful degradation means the panel always shows something useful.

### 10. Cross-store subscription without React
`agentActivityStore.ts` uses `useMonitorStore.subscribe()` outside any React component to bridge two Zustand stores. This pattern keeps the reactive data pipeline alive independently of component mount/unmount lifecycle.

---

## File Path Reference

Key files for further study:

| File | What it shows |
|---|---|
| `src/stores/monitorStore.ts` | Full WebSocket connection + 3-mode logic + event buffer |
| `src/stores/agentActivityStore.ts` | Cross-store subscription + action label extraction |
| `src/stores/storyStore.ts` | Complete Story/Kanban state model + 7-status taxonomy |
| `src/components/monitor/LiveMonitor.tsx` | Full monitor view composition |
| `src/components/monitor/ActivityTimeline.tsx` | Timeline + demo data specification |
| `src/components/dashboard/LiveMetricCard.tsx` | Animated metric card with sparkline |
| `src/components/dashboard/CockpitDashboard.tsx` | KPI grid + service health + ticker |
| `src/components/status-bar/StatusBar.tsx` | Global persistent status strip |
| `src/components/terminals/TerminalsView.tsx` | Multi-terminal session management |
| `engine/src/index.ts` | Full engine startup, routes, WebSocket, process pool |
| `engine/src/routes/stream.ts` | SSE streaming + Claude CLI spawn + stream-json mapping |
| `engine/engine.config.yaml` | Process pool config, workspace, memory budget |
| `CLAUDE.md` | Design system rules, slash commands, token constraints |

---

*Sources: GitHub API (SynkraAI/aiox-dashboard), search results for SynkraAI ecosystem.*
