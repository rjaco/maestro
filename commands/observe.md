---
name: observe
description: "Agent observability dashboard — live and historical view of agent dispatches, per-agent metrics (tokens, cost, QA iterations), model distribution, and failure rates. Supports terminal, JSON, and Mermaid timeline output."
argument-hint: "[live|history|agents|costs|--format <terminal|json|mermaid>|--story <id>|--agent <type>|--failed]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Skill
---

# /maestro observe

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
 ██████╗ ██████╗ ███████╗███████╗██████╗ ██╗   ██╗███████╗
██╔═══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝
██║   ██║██████╔╝███████╗█████╗  ██████╔╝██║   ██║█████╗
██║   ██║██╔══██╗╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝
╚██████╔╝██████╔╝███████║███████╗██║  ██║ ╚████╔╝ ███████╗
 ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝
```

Agent observability dashboard. See exactly what agents are doing — live during an active session or historically across sessions. Per-dispatch metrics: tokens, cost, QA iterations, self-heal count, model, and status.

This command is read-only. It writes nothing to disk.

---

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

Check for data sources:
- `.maestro/logs/costs.jsonl` — dispatch records (one entry per agent dispatch)
- `.maestro/state.local.md` — current session boundary and active story
- `.maestro/logs/telemetry.jsonl` — timing data per dispatch

If no data sources exist yet:

```
[maestro] No agent dispatch data found.

  Dispatch data is collected automatically when /maestro runs stories.
  Start a session with /maestro "your feature" to begin collecting data.
```

---

## Step 2: Handle Arguments

### No arguments or `live` — Live dashboard (default)

Invoke the `agent-observe` skill from `skills/agent-observe/SKILL.md` with the live view.

Read dispatches from `.maestro/logs/costs.jsonl` scoped to the current session. Session boundary is the `sessionStart` timestamp from `.maestro/state.local.md`.

Display the per-dispatch table followed by per-story summary and aggregate stats:

```
+---------------------------------------------------------------------+
| Agent Observe — Live Session                                        |
+---------------------------------------------------------------------+

  Story         | Agent       | Model   | Status  | Tokens      | Cost
  --------------|-------------|---------|---------|-------------|------
  story-01      | implementer | sonnet  | done    | 18.4k/4.2k  | $0.12
  story-01      | qa-reviewer | haiku   | done    |  3.1k/0.8k  | $0.01
  story-02      | implementer | sonnet  | done    | 21.2k/5.1k  | $0.15
  story-02      | implementer | sonnet  | done    | 19.8k/3.9k  | $0.13  <- QA rework
  story-02      | qa-reviewer | haiku   | done    |  3.4k/1.1k  | $0.01
  story-03      | implementer | opus    | ACTIVE  | 31.2k/7.4k  | $0.44

  Session total                          96.1k/22.5k  $0.86

Per-story summary:
  story-01  done     QA: 1 pass   Self-heal: 0   Time: 4m 12s
  story-02  done     QA: 2 iters  Self-heal: 1   Time: 9m 44s
  story-03  active   QA: --       Self-heal: --  Time: 2m 31s (running)

Model distribution:
  haiku  ░░░░░░░░░░░░░░░░  0/6 dispatches  ( 0%)
  sonnet ████████████░░░░  5/6 dispatches  (83%)
  opus   ██░░░░░░░░░░░░░░  1/6 dispatches  (17%)

Cost by agent type:
  implementer  $0.84  (98%)
  qa-reviewer  $0.02  ( 2%)
  fixer        $0.00

Failure rate:      0/3 stories failed (0%)
QA first-pass:     2/3 stories (67%)
Avg self-heal:     0.3 iterations per story
```

If no active session is in progress, display the most recent session's data instead and label it accordingly.

---

### `history` — Historical view across sessions

Read `.maestro/logs/telemetry.jsonl` across all sessions. If a milestone name is provided (`history --milestone "Core Features"`), filter to that milestone.

```
+-----------------------------------------------------------------------+
| Agent Observe — Historical                                            |
+-----------------------------------------------------------------------+

  Stories: 6   Dispatches: 19   Total cost: $4.80   Duration: 47m

  Story     | Result | QA iters | Heal iters | Model(s)    | Cost
  ----------|--------|----------|------------|-------------|------
  story-01  | DONE   | 1        | 0          | sonnet      | $0.27
  story-02  | DONE   | 2        | 1          | sonnet      | $0.51
  story-03  | DONE   | 1        | 0          | opus        | $1.20
  story-04  | DONE   | 1        | 0          | haiku       | $0.08
  story-05  | DONE   | 3        | 2          | sonnet/opus | $1.84
  story-06  | DONE   | 1        | 0          | haiku       | $0.09

  Total     |        | 9 QA     | 3 heals    |             | $4.80

Model distribution:
  haiku  ░░░░░░░░  2/6  (33%)  avg cost/story: $0.09
  sonnet ████░░░░  3/6  (50%)  avg cost/story: $0.43
  opus   ██░░░░░░  1/6  (17%)  avg cost/story: $1.20

High-iteration stories (QA >= 2 or self-heal >= 2):
  story-02  QA: 2, Self-heal: 1  — rework cost: $0.24
  story-05  QA: 3, Self-heal: 2  — rework cost: $1.21  <- outlier
```

---

### `agents` — Agent-type breakdown

Show aggregate metrics grouped by agent type across the current session (or last session if idle).

```
+---------------------------------------------+
| Agent Breakdown                             |
+---------------------------------------------+

  Agent type   | Dispatches | Tokens in  | Tokens out | Total cost | Avg/dispatch
  -------------|------------|------------|------------|------------|--------------
  implementer  | 5          | 108.6k     | 24.5k      | $0.84      | $0.17
  qa-reviewer  | 3          |  9.6k      |  2.9k      | $0.03      | $0.01
  fixer        | 1          |  6.4k      |  1.8k      | $0.05      | $0.05
  researcher   | 0          | --         | --         | --         | --
  strategist   | 0          | --         | --         | --         | --
```

---

### `costs` — Cost breakdown view

Show costs sorted descending, with cache hit ratios.

```
+---------------------------------------------+
| Cost Breakdown                              |
+---------------------------------------------+

  Story     | Agent       | Model   | Cost   | Cache hit
  ----------|-------------|---------|--------|----------
  story-03  | implementer | opus    | $0.44  | 52%
  story-02  | implementer | sonnet  | $0.28  | 38%
  story-05  | implementer | opus    | $1.20  | 41%

  Session total:   $0.86
  Cache savings:   ~$0.31 (estimated, from cache hit ratios)

  (i) Cache hits reduce input token cost by ~90%.
  (i) Run /maestro cost-estimate before large builds.
```

---

## Filters

All subcommands support these flags:

| Flag | Effect |
|------|--------|
| `--story <id>` | Show only dispatches for one story |
| `--agent <type>` | Filter by agent type (implementer, qa-reviewer, fixer, etc.) |
| `--model <name>` | Filter by model (haiku, sonnet, opus) |
| `--failed` | Show only failed or high-iteration dispatches |
| `--milestone <name>` | Scope to a named milestone (historical) |
| `--since <duration>` | Show dispatches from the last N hours/days (e.g., `--since 2h`) |
| `--format <type>` | Output format: `terminal` (default), `json`, `mermaid` |

---

## Output Formats

### `--format json`

Emits structured JSON to stdout. Intended for CI pipelines, cost assertions, and external dashboards.

```json
{
  "session": {
    "status": "active",
    "session_start": "2026-03-18T14:00:00Z"
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
  "dispatches": [ ... ]
}
```

### `--format mermaid`

Emits a Gantt chart of agent dispatches over time. Suitable for pasting into GitHub issues or Markdown docs.

```
gantt
    title Milestone 3 — Agent Dispatches
    dateFormat HH:mm
    axisFormat %H:%M

    section story-01
    implementer (sonnet)  :done,   s01_impl, 14:00, 4m
    qa-reviewer (haiku)   :done,   s01_qa,   14:04, 1m

    section story-02
    implementer (sonnet)  :done,   s02_impl, 14:06, 5m
    self-heal (sonnet)    :crit,   s02_heal, 14:11, 2m
    qa-reviewer (haiku)   :done,   s02_qa,   14:13, 1m
```

---

## Configuration

Read from `.maestro/config.yaml`:

```yaml
agent_observe:
  auto_render: false          # append per-story row after each CHECKPOINT
  default_format: terminal    # terminal | json | mermaid
  high_iteration_threshold: 2 # flag stories with QA or self-heal >= this value
```

`auto_render: true` appends a compact per-story summary after each story's CHECKPOINT — useful for watching agent-centric progress without the full dashboard.

---

## Error Handling

| Error | Action |
|-------|--------|
| `costs.jsonl` does not exist | Print "no dispatch data" message and exit cleanly |
| `state.local.md` missing (session boundary unknown) | Default to all available data; label as "all sessions" |
| `telemetry.jsonl` missing (no timing data) | Show token/cost data without duration columns |
| Malformed JSON entry in `costs.jsonl` | Skip the entry, continue rendering |

---

## Integration

- **agent-observe skill**: `skills/agent-observe/SKILL.md` — implements all dispatch reading and metric computation
- **telemetry skill**: primary source for `duration_ms` and agent status events
- **cost-dashboard**: owns cost accumulation; observe reads the same `costs.jsonl` without duplicating accounting
- **dashboard**: milestone-level progress (`/maestro dashboard`); observe provides agent-level granularity
- **token-ledger**: fallback source for historical per-story totals after log rotation
- **retrospective**: uses `/maestro observe --format json --milestone <name>` as one data input
- **learning-loop**: reads high-iteration patterns from `costs.jsonl` — the same data observe surfaces interactively
