---
name: cost-dashboard
description: "Comprehensive cost tracking and visualization dashboard. Aggregates per-dispatch cost data, renders ASCII charts, manages budgets, and emits optimization recommendations."
---

# Cost Dashboard

Tracks every dollar spent during a Maestro session. Reads raw cost data from the SDK and token-ledger, renders an ASCII dashboard, enforces budget thresholds, and surfaces optimization signals to delegation and model routing.

## Data Sources

### 1. SDK ResultMessage (per dispatch)
Read `ResultMessage.total_cost_usd` from each completed agent dispatch. Also read:
- `modelUsage` — per-model token and cost breakdown (input tokens, output tokens, cost by model)
- `cache_read_input_tokens` — cache hits (prompt tokens served from cache)
- `cache_creation_input_tokens` — cache creation (new cache entries written)

### 2. Token-Ledger
Read `.maestro/token-ledger.md` for accumulated session and feature totals. The ledger is the authoritative source for historical per-story cost data. See `skills/token-ledger/SKILL.md`.

### 3. Build Logs
Read `.maestro/logs/*.md` for historical feature cost data (the `## Cost Breakdown` section in each log). Used to populate the TREND block in the dashboard.

### 4. State
Read `maxBudgetUsd` from `.maestro/state.local.md` for the current feature budget ceiling.

## Cost Tracking Storage

Append one line per dispatch to `.maestro/logs/costs.jsonl`:

```
{"timestamp":"2026-03-18T14:23:01Z","story":"story-03","phase":"implement","model":"sonnet","tokens_in":18400,"tokens_out":4200,"cost_usd":0.12,"cache_read":9100,"cache_create":3200}
```

Fields:
- `timestamp` — ISO 8601 UTC
- `story` — story ID (e.g., `story-03`) or phase label for non-story dispatches (e.g., `decompose`)
- `phase` — one of: `research`, `decompose`, `implement`, `self-heal`, `qa-review`, `git-craft`
- `model` — `opus`, `sonnet`, or `haiku`
- `tokens_in` — total input tokens (including cache reads)
- `tokens_out` — output tokens
- `cost_usd` — actual cost from `ResultMessage.total_cost_usd`
- `cache_read` — tokens served from cache (`cache_read_input_tokens`)
- `cache_create` — tokens written to cache (`cache_creation_input_tokens`)

Append-only. Never modify existing lines.

## Dashboard Format

Render on demand (e.g., when the user runs `/maestro cost`) or after each story completes if `cost_tracking.dashboard` is `true` in config.

```
╔══════════════════════════════════════════╗
║  MAESTRO COST DASHBOARD                  ║
║  Feature: Add User Auth | Session: d8a3  ║
╚══════════════════════════════════════════╝

CURRENT SESSION:
  Total: $2.47 (87.2K tokens)
  Budget: $5.00 (49% used)

BY MODEL:
  opus   $1.85  74%  ████████████████████░░░░░  2 dispatches
  sonnet $0.52  21%  █████░░░░░░░░░░░░░░░░░░░░  4 dispatches
  haiku  $0.10   4%  █░░░░░░░░░░░░░░░░░░░░░░░░  3 dispatches

BY PHASE:
  Research     $0.00   0%
  Decompose    $0.15   6%
  Implement    $1.42  57%
  Self-heal    $0.35  14%
  QA Review    $0.45  18%
  Git Craft    $0.10   4%

CACHE EFFICIENCY:
  Cache hits: 67% (saves ~$0.82)
  Creation: 23.1K tokens | Reads: 64.1K tokens

TREND (last 5 features):
  Auth system    $3.20  8 stories
  API endpoints  $1.85  5 stories
  Dashboard UI   $4.10  12 stories
  → Avg: $2.38/feature, $0.46/story

SAVINGS FROM ROUTING:
  Auto-downgrade saved: $0.65 (3 stories routed haiku instead of sonnet)
```

### Bar Chart Rules

Each bar is 25 characters wide. Fill proportionally:
- `████` = filled blocks (percentage of total cost)
- `░░░░` = empty blocks (remainder)
- Round to the nearest whole block

Cache savings estimate: multiply cache_read tokens by the model's input price rate, then subtract the cached rate (approximately 10% of standard input price).

## Budget Management

Read `maxBudgetUsd` from state. If not set, there is no ceiling — display "No budget set" and skip threshold checks.

| Threshold | Action |
|-----------|--------|
| 75% of budget | Print warning line in dashboard: `[WARN] Budget 75% consumed — $X.XX remaining` |
| 90% of budget | Print alert line: `[ALERT] Budget 90% consumed — consider pausing` |
| 100% of budget | Enforce `budget_exceeded_policy` from config (default: `warn`) |

`budget_exceeded_policy` options:
- `warn` (default) — print `[BUDGET EXCEEDED]` and continue
- `pause` — halt execution, surface to user: "Budget ceiling reached. Approve continuation or raise limit."

Log each threshold crossing to `.maestro/state.local.md`:
```
[Budget] 75% threshold crossed at $3.75 / $5.00 (story-06, implement phase)
```

## Optimization Recommendations

Evaluate after every 3 completed stories or on dashboard render. Append recommendations to the dashboard output when triggered.

| Condition | Recommendation |
|-----------|---------------|
| Opus usage > 50% of session cost | "Opus is consuming most of the budget. Review model assignments in delegation — are these stories genuinely novel or architecturally complex?" |
| Cache hit rate < 30% | "Low cache hit rate. Improve context reuse by standardizing system prompts and reusing context packages across similar stories." |
| Avg story cost > $1.00 | "Stories are averaging over $1 each. Consider breaking large stories into smaller, more targeted units to reduce per-story overhead." |
| Auto-downgrade savings > $0 | "Auto-downgrade saved $X.XX this session. Review which models are flagged to confirm quality was not impacted." |

Only emit a recommendation when its condition is first met, then suppress it until the condition clears and re-triggers. Do not repeat the same recommendation on every dashboard render.

## Configuration

Check `.maestro/config.yaml`:

```yaml
cost_tracking:
  dashboard: true        # render dashboard after each story
  ledger: true           # enable costs.jsonl append (requires token-ledger)
  budget_exceeded_policy: warn   # warn | pause
```

If `cost_tracking` is absent or `dashboard` is `false`, only render on explicit user command.

## Integration Points

- **token-ledger/SKILL.md** — feeds raw per-dispatch cost data; cost-dashboard reads the ledger for session totals
- **delegation/SKILL.md** — receives `maxBudgetUsd` budget constraints; delegation checks budget thresholds before each dispatch and reads cost-dashboard's optimization signals to adjust model assignments
- **model-router/SKILL.md** — receives optimization feedback when opus usage or cache efficiency recommendations fire; model-router uses this to recalibrate default model assignments
- **status/ command** — include a one-line cost summary in status output: `Cost: $2.47 / $5.00 (49%)`
- **build-log/SKILL.md** — include cost-dashboard's BY PHASE table in the `## Cost Breakdown` section of each build log

## SDK modelUsage Integration (v0.1.0+)

The Agent SDK's `ResultMessage.modelUsage` provides per-model cost breakdowns that the cost dashboard should consume directly:

```typescript
// From SDK ResultMessage
modelUsage: {
  "claude-sonnet-4-6": {
    costUSD: 0.52,
    inputTokens: 18400,
    outputTokens: 4200,
    cacheReadInputTokens: 9100,
    cacheCreationInputTokens: 3200
  },
  "claude-opus-4-6": {
    costUSD: 1.85,
    inputTokens: 8200,
    outputTokens: 1800,
    cacheReadInputTokens: 4100,
    cacheCreationInputTokens: 0
  }
}
```

When available, prefer `modelUsage` over manual token-to-cost calculations. The SDK tracks actual billing amounts including cache discount rates, which manual calculations approximate.

### Per-Agent Cost Attribution

When `parent_tool_use_id` is set on a message, costs belong to that subagent. Track costs per agent type:

```
BY AGENT:
  implementer  $1.42  57%  (4 dispatches, avg $0.36)
  qa-reviewer  $0.45  18%  (4 dispatches, avg $0.11)
  fixer        $0.35  14%  (2 dispatches, avg $0.18)
  orchestrator $0.25  10%  (overhead)
```

### Plugin Data Fast Cache

When `${CLAUDE_PLUGIN_DATA}` is available (v2.1.78+), store running cost totals for instant dashboard rendering without re-parsing the full costs.jsonl:

```
Key: maestro_cost_session_total    → "2.47"
Key: maestro_cost_session_stories  → "5"
Key: maestro_cost_budget_used_pct  → "49"
Key: maestro_cost_model_opus       → "1.85"
Key: maestro_cost_model_sonnet     → "0.52"
Key: maestro_cost_model_haiku      → "0.10"
```

This enables sub-second dashboard renders for the status command instead of scanning the full JSONL log.

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/logs/costs.jsonl"
  format: append-only JSONL
  required_fields:
    - timestamp
    - story
    - phase
    - model
    - tokens_in
    - tokens_out
    - cost_usd
    - cache_read
    - cache_create
```
