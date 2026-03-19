---
name: agent-observe
description: "Real-time and historical observability dashboard for agent dispatches. Shows active/completed/failed dispatches, per-agent metrics (tokens, time, status, QA iterations), aggregated views (model distribution, cost by agent type, failure rate), and supports terminal table, JSON, and Mermaid timeline output formats."
---

# Agent Observe

Provides visibility into what agents are doing — live during an Opus session and historically across sessions. Reads dispatch telemetry and cost data without writing to disk. The orchestrator and user can invoke this at any point to get a precise picture of the current run or a past feature.

## When to Use

- **Live view** — invoked during an active session to see in-progress and recently completed dispatches
- **Historical view** — invoked after a session to analyze a past feature or milestone
- **CI mode** — invoked with `--format json` to emit structured data for downstream tooling
- **Explicit command** — `/maestro observe` or `/maestro agents`

## Data Sources

| Data | Source |
|------|--------|
| Dispatch records | `.maestro/logs/costs.jsonl` — one entry per dispatch |
| Agent status | `.maestro/state.local.md` — `currentPhase`, `storiesCompleted`, active story |
| QA iteration count | `.maestro/logs/costs.jsonl` — count entries with `phase: qa-review` per story |
| Self-heal iterations | `.maestro/logs/costs.jsonl` — count entries with `phase: self-heal` per story |
| Session boundary | `.maestro/state.local.md` — `sessionStart` timestamp |
| Historical sessions | `.maestro/logs/telemetry.jsonl` and rotations |

## Per-Agent Metrics

For each dispatch record, compute and display:

| Metric | Computation |
|--------|-------------|
| **Status** | `active` (story in-progress) / `done` (story completed) / `failed` (story BLOCKED or never resolved) |
| **Agent type** | From `phase` field in costs.jsonl (`implement` → implementer, `qa-review` → qa-reviewer, `self-heal` → fixer, etc.) |
| **Model** | From `model` field |
| **Tokens in / out** | From `tokens_in`, `tokens_out` |
| **Cost** | From `cost_usd` |
| **Time elapsed** | From `duration_ms` in telemetry.jsonl for the matching `agent_id` / `story_id` |
| **QA iterations** | Count of `qa-review` entries for that story in costs.jsonl |
| **Self-heal iterations** | Count of `self-heal` entries for that story in costs.jsonl |
| **Cache hit ratio** | `cache_read / tokens_in` — measure of prompt cache effectiveness |

## Live View

The live view shows dispatches from the current session. Session boundary is determined by `sessionStart` in `.maestro/state.local.md`. Dispatches with timestamps before `sessionStart` are excluded.

### Terminal Table Format

```
Agent Observe — Session: Milestone 3 "Core Features" — 2026-03-18 14:30
+---------------------------------------------------------------------+
| Story         | Agent       | Model   | Status  | Tokens   | Cost   |
|---------------|-------------|---------|---------|----------|--------|
| story-01      | implementer | sonnet  | done    | 18.4k/4.2k | $0.12 |
| story-01      | qa-reviewer | haiku   | done    |  3.1k/0.8k | $0.01 |
| story-02      | implementer | sonnet  | done    | 21.2k/5.1k | $0.15 |
| story-02      | implementer | sonnet  | done    | 19.8k/3.9k | $0.13 |  <- QA rework
| story-02      | qa-reviewer | haiku   | done    |  3.4k/1.1k | $0.01 |
| story-03      | implementer | opus    | ACTIVE  | 31.2k/7.4k | $0.44 |
+---------------------------------------------------------------------+
| Session total                         |          | 96.1k/22.5k | $0.86 |
+---------------------------------------------------------------------+

Per-story summary:
  story-01  done     QA: 1 pass   Self-heal: 0   Time: 4m 12s
  story-02  done     QA: 2 iters  Self-heal: 1   Time: 9m 44s
  story-03  active   QA: -        Self-heal: -   Time: 2m 31s (running)
```

Status column values:

| Value | Meaning |
|-------|---------|
| `done` | Agent completed, QA passed |
| `ACTIVE` | Agent dispatch currently running |
| `failed` | Agent reported BLOCKED or hit max retries |
| `rework` | Story re-dispatched after QA rejection |

### Aggregated View (live)

Append below the per-agent table:

```
Model distribution (this session):
  haiku  ░░░░░░░░░░░░░░░░  0/6 dispatches  (0%)
  sonnet ████████████░░░░  5/6 dispatches  (83%)
  opus   ██░░░░░░░░░░░░░░  1/6 dispatches  (17%)

Cost by agent type:
  implementer  $0.84  (98%)
  qa-reviewer  $0.02  ( 2%)
  fixer        $0.00

Failure rate: 0/3 stories failed (0%)
QA first-pass rate: 2/3 stories (67%)
Avg self-heal iterations: 0.3 per story
```

## Historical View

The historical view reads across session boundaries from `telemetry.jsonl` (including rotations). Useful for analyzing a completed feature or comparing milestones.

Invoke with: `/maestro observe --history` or `/maestro observe --milestone "Core Features"`

```
Agent Observe — Historical: Milestone 3 "Core Features" — complete
Stories: 6   Dispatches: 19   Total cost: $4.80   Duration: 47m

+-----------------------------------------------------------------------+
| Story    | Result | QA iters | Heal iters | Model(s)      | Cost      |
|----------|--------|----------|------------|---------------|-----------|
| story-01 | DONE   | 1        | 0          | sonnet        | $0.27     |
| story-02 | DONE   | 2        | 1          | sonnet        | $0.51     |
| story-03 | DONE   | 1        | 0          | opus          | $1.20     |
| story-04 | DONE   | 1        | 0          | haiku         | $0.08     |
| story-05 | DONE   | 3        | 2          | sonnet/opus   | $1.84     |
| story-06 | DONE   | 1        | 0          | haiku         | $0.09     |
+-----------------------------------------------------------------------+
| Total    |        | 9 QA     | 3 heals    |               | $3.99 impl|
|          |        |          |            |               | $0.81 qa  |
+-----------------------------------------------------------------------+

Model distribution:
  haiku  ░░░░░░░░  2/6  (33%)  avg cost/story: $0.09
  sonnet ████░░░░  3/6  (50%)  avg cost/story: $0.43
  opus   ██░░░░░░  1/6  (17%)  avg cost/story: $1.20

High-iteration stories (QA >= 2 or Self-heal >= 2):
  story-02  QA: 2, Self-heal: 1  — rework cost: $0.24
  story-05  QA: 3, Self-heal: 2  — rework cost: $1.21  <- outlier
```

### Mermaid Timeline Format

Output with `--format mermaid`. Suitable for pasting into GitHub issues or Markdown docs.

```
gantt
    title Milestone 3 — Agent Dispatches
    dateFormat HH:mm
    axisFormat %H:%M

    section story-01
    implementer (sonnet)     :done,  s01_impl, 14:00, 4m
    qa-reviewer (haiku)      :done,  s01_qa,   14:04, 1m

    section story-02
    implementer (sonnet)     :done,  s02_impl1, 14:06, 5m
    self-heal (sonnet)       :crit,  s02_heal,  14:11, 2m
    implementer (sonnet)     :done,  s02_impl2, 14:13, 4m
    qa-reviewer (haiku)      :done,  s02_qa,    14:17, 1m

    section story-03
    implementer (opus)       :active, s03_impl, 14:19, 8m
```

### JSON Format

Output with `--format json`. Intended for CI pipelines, cost assertions, and external dashboards.

```json
{
  "session": {
    "milestone": "Core Features",
    "milestone_index": 3,
    "session_start": "2026-03-18T14:00:00Z",
    "status": "active"
  },
  "summary": {
    "stories_total": 3,
    "stories_done": 2,
    "stories_active": 1,
    "stories_failed": 0,
    "total_tokens_in": 96100,
    "total_tokens_out": 22500,
    "total_cost_usd": 0.86,
    "qa_first_pass_rate": 0.67,
    "avg_self_heal_iterations": 0.33
  },
  "model_distribution": {
    "haiku":  { "dispatches": 0, "cost_usd": 0.00 },
    "sonnet": { "dispatches": 5, "cost_usd": 0.42 },
    "opus":   { "dispatches": 1, "cost_usd": 0.44 }
  },
  "dispatches": [
    {
      "story": "story-01",
      "phase": "implement",
      "agent_type": "implementer",
      "model": "sonnet",
      "status": "done",
      "tokens_in": 18400,
      "tokens_out": 4200,
      "cost_usd": 0.12,
      "duration_ms": 251200,
      "qa_iterations": 1,
      "self_heal_iterations": 0,
      "cache_hit_ratio": 0.49
    }
  ]
}
```

## Filtering

Agent observe supports filters to narrow the view:

| Flag | Effect |
|------|--------|
| `--story story-02` | Show only dispatches for one story |
| `--agent implementer` | Filter by agent type |
| `--model opus` | Filter by model |
| `--failed` | Show only failed or high-iteration dispatches |
| `--milestone "name"` | Scope to a named milestone (historical) |
| `--since 2h` | Show dispatches from the last N hours/days |

## Configuration

Read from `.maestro/config.yaml`:

```yaml
agent_observe:
  auto_render: false          # render after each story (default: false; use dashboard for that)
  default_format: terminal    # terminal | json | mermaid
  high_iteration_threshold: 2 # flag stories with QA or self-heal >= this value
```

`auto_render: true` causes agent-observe to append the per-story summary row after each story's CHECKPOINT. This is a lower-detail alternative to dashboard for users who want agent-centric (not milestone-centric) progress.

## Output Contract

Agent observe is read-only. It writes nothing to disk.

```yaml
output_contract:
  writes: none
  reads:
    - .maestro/logs/costs.jsonl
    - .maestro/logs/telemetry.jsonl
    - .maestro/state.local.md
  side_effects: terminal output or stdout (JSON/Mermaid)
```

## Integration Points

| Skill | Integration |
|-------|-------------|
| **telemetry** | Primary source for per-dispatch `duration_ms` and agent status events (`SubagentStop`). agent-observe reads `telemetry.jsonl` for timing data. |
| **cost-dashboard** | cost-dashboard owns cost accumulation and budget enforcement. agent-observe reads `costs.jsonl` (the same file cost-dashboard writes) — it does not duplicate cost accounting logic. |
| **dashboard** | dashboard shows milestone-level progress (stories done, ETA, spend). agent-observe shows agent-level granularity (per-dispatch tokens, QA iterations, model breakdown). Both can render in the same session — they read the same data sources but at different aggregation levels. |
| **token-ledger** | Secondary source for historical per-story totals when `costs.jsonl` entries are unavailable (e.g., after rotation). |
| **learning-loop** | learning-loop reads high-iteration story data from `costs.jsonl` as token efficiency signals. agent-observe's `--failed` and high-iteration flags surface the same patterns interactively. |
| **retrospective** | retrospective uses agent-observe's JSON output as one of its data inputs when generating the feature performance summary. Pass `--format json --milestone name` to retrospective's data-gather phase. |
