---
name: token-budget
description: "Enforce token budgets per skill invocation. Calculates estimated dispatch cost, warns when approaching session budget limits, and feeds actuals to the forecast skill."
effort: low
maxTurns: 2
disallowedTools:
  - Write
  - Edit
  - Bash
---

# Token Budget

Guards every agent dispatch against the session's remaining budget. Before any dispatch fires, Token Budget calculates the expected cost, compares it to the session's remaining allowance, and intervenes when the dispatch would consume an unsafe share of what's left. After dispatch, it records actuals and feeds them to the forecast skill for better future estimates.

## Configuration

Read `.maestro/config.yaml`:

```yaml
cost_tracking:
  budget:
    enabled: true          # set false to disable all budget enforcement
    session_limit: 5.00    # USD cap per session (default: no cap if absent)
    warn_threshold: 0.90   # warn when dispatch would use >90% of remaining budget
```

If `cost_tracking.budget.enabled` is `false`, skip all enforcement and return immediately. The skill is dormant.

If `session_limit` is absent, enforcement still runs but uses a soft-warn-only mode (no hard blocks, only informational notices).

## Model Pricing

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|-----------------------|------------------------|
| Haiku | $0.25 | $1.25 |
| Sonnet | $3.00 | $15.00 |
| Opus | $15.00 | $75.00 |

Assume a 60/40 input/output token split unless the caller provides a different ratio.

> Note: Haiku pricing above reflects the story's specified rates ($0.25/1M input). The token-ledger and forecast skills use $0.80/1M (likely blended or cached rates). Use the rates specified here for budget enforcement; use token-ledger rates for cost reporting.

## Operations

### `pre-dispatch` — Check Budget Before Firing

Called by the delegation skill before every agent dispatch.

**Input:**
```yaml
context_tokens: 4200       # estimated tokens in the dispatch context
model: "sonnet"            # selected model
story: "03-api-routes"     # for logging
phase: "implement"         # implement | qa-review | delegate | fix
```

**Process:**

#### 1. Calculate Estimated Cost

```
effective_rate = (0.60 * input_price_per_1M + 0.40 * output_price_per_1M) / 1_000_000
estimated_cost = context_tokens * effective_rate
```

Example for Sonnet with 4,200 tokens:
```
effective_rate = (0.60 * 3.00 + 0.40 * 15.00) / 1_000_000 = 7.80 / 1_000_000
estimated_cost = 4200 * 0.0000078 = $0.033
```

#### 2. Load Session Budget State

Read `.maestro/state.local.md` for:
```yaml
budget:
  session_limit: 5.00       # from config (copied here for convenience)
  spent_to_date: 1.42       # sum of all completed dispatch costs this session
  estimated_remaining: 3.58 # session_limit - spent_to_date
```

If `spent_to_date` is absent, treat as 0.

If `session_limit` is absent (no cap configured), skip the threshold check and proceed to logging only.

#### 3. Evaluate Threshold

```
remaining_budget = session_limit - spent_to_date
share_of_remaining = estimated_cost / remaining_budget
```

If `share_of_remaining > warn_threshold` (default 0.90):

**Warn the user:**

```
+---------------------------------------------+
| Budget Warning                              |
+---------------------------------------------+

  Story:     [story]  Phase: [phase]
  Model:     [model]

  This dispatch would cost ~$[estimated_cost].
  That's [share_of_remaining * 100]% of your remaining budget ($[remaining_budget]).

  Session budget:  $[session_limit]
  Spent so far:    $[spent_to_date]
  After dispatch:  ~$[spent_to_date + estimated_cost] spent / $[remaining_budget - estimated_cost] left
```

Use AskUserQuestion:
- Question: "This dispatch (~$[estimated_cost]) would use [share_of_remaining * 100, rounded]% of remaining budget ($[remaining_budget]). Proceed?"
- Header: "Budget Warning"
- Options:
  1. label: "Proceed anyway", description: "Dispatch this agent and continue"
  2. label: "Switch to a cheaper model", description: "Downgrade to the next tier (saves ~[savings estimate])"
  3. label: "Skip this story", description: "Mark story as SKIPPED and continue with others"
  4. label: "Pause session", description: "Stop here and review remaining work"

If user selects "Switch to a cheaper model":
- Downgrade model one tier: opus → sonnet → haiku
- Recalculate `estimated_cost` with the new model
- Return updated dispatch parameters to the delegation skill

If user selects "Skip this story":
- Return `SKIP` signal to delegation skill
- Delegation marks the story as `SKIPPED` in state

If user selects "Pause session":
- Return `PAUSE` signal to delegation skill
- Delegation surfaces a session summary

#### 4. If Under Threshold — Proceed Silently

No user interaction. Log the pending dispatch internally and return `PROCEED` to the delegation skill.

#### 5. Log Pre-Dispatch Entry

Append to `.maestro/state.local.md` under `budget.pending`:

```yaml
budget:
  pending:
    story: "03-api-routes"
    phase: "implement"
    model: "sonnet"
    context_tokens: 4200
    estimated_cost: 0.033
    dispatched_at: "2026-03-18T10:14:00Z"
```

---

### `post-dispatch` — Record Actuals After Completion

Called by the delegation skill after an agent completes (or fails).

**Input:**
```yaml
story: "03-api-routes"
phase: "implement"
model: "sonnet"
actual_tokens: 5100        # from agent task completion notification
status: "DONE"             # DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED | FAILED
```

**Process:**

#### 1. Calculate Actual Cost

```
actual_cost = actual_tokens * effective_rate_for_model
```

#### 2. Update Session Totals

Update `.maestro/state.local.md`:

```yaml
budget:
  spent_to_date: [previous + actual_cost]
  last_updated: "2026-03-18T10:18:00Z"
  dispatches:
    - story: "03-api-routes"
      phase: "implement"
      model: "sonnet"
      estimated_tokens: 4200
      actual_tokens: 5100
      estimated_cost: 0.033
      actual_cost: 0.040
      variance_pct: +21%
      status: "DONE"
```

#### 3. Feed Actuals to Forecast Skill

Call `forecast` skill's `record-actual` operation with:
```yaml
story_type: "[derived from story name]"
complexity: "[simple|medium|complex]"
model: "sonnet"
actual_tokens: 5100
estimated_tokens: 4200
variance_pct: +21%
```

The forecast skill uses this to calibrate future estimates.

#### 4. Check Post-Dispatch Budget Health

After recording actuals, compute the updated remaining budget. If remaining budget is low, proactively notify:

| Remaining | Notice |
|-----------|--------|
| < 20% of session limit | `(!) Budget at 20%. Consider switching remaining stories to cheaper models.` |
| < 10% of session limit | `(!) Budget at 10%. Recommend pausing before next dispatch.` |
| $0 or negative | `(!) Session budget exhausted. Dispatch blocked until limit is raised or session ends.` |

If budget is exhausted, return `BLOCK` signal to delegation skill. Delegation stops dispatching and surfaces the situation to the user.

---

### `summary` — Budget Status at Any Point

Called by the `/maestro status` command to include budget info in the status display.

**Output:**

```
  Budget:
    Limit:     $[session_limit]   (or "No cap" if unset)
    Spent:     $[spent_to_date]   ([N] dispatches)
    Remaining: $[remaining]       ([remaining_pct]%)

    Breakdown by model:
      Haiku    [N] dispatches   ~$[total]
      Sonnet   [N] dispatches   ~$[total]
      Opus     [N] dispatches   ~$[total]

    Estimate accuracy:
      Avg variance: [+/-N]%   ([N] data points)
```

If no budget cap is configured:

```
  Budget:
    No session cap configured.
    Spent this session: $[spent_to_date] across [N] dispatches.
    Set a cap in .maestro/config.yaml under cost_tracking.budget.session_limit.
```

## State Schema

All budget state lives in `.maestro/state.local.md` under the `budget` key:

```yaml
budget:
  session_limit: 5.00
  spent_to_date: 1.42
  last_updated: "2026-03-18T10:18:00Z"
  dispatches:
    - story: "03-api-routes"
      phase: "implement"
      model: "sonnet"
      estimated_tokens: 4200
      actual_tokens: 5100
      estimated_cost: 0.033
      actual_cost: 0.040
      variance_pct: +21%
      status: "DONE"
      dispatched_at: "2026-03-18T10:14:00Z"
      completed_at: "2026-03-18T10:18:00Z"
```

## Integration Points

| Caller | When | Operation |
|--------|------|-----------|
| `skills/delegation` | Before every dispatch | `pre-dispatch` |
| `skills/delegation` | After every agent completes | `post-dispatch` |
| `commands/status.md` | On `/maestro status` | `summary` |
| `skills/forecast` | Receives actual data | `record-actual` |
| `skills/retrospective` | End of session | reads `dispatches` array for variance analysis |

## Error Handling

| Condition | Action |
|-----------|--------|
| `state.local.md` missing | Treat `spent_to_date` as 0, proceed |
| `actual_tokens` not available from agent | Estimate from response length (~1.3 tokens per word) |
| Forecast skill unavailable | Log actuals locally, skip forecast feed |
| Config missing `budget` key | Default to `enabled: false`, no enforcement |

## Output Contract

```yaml
output_contract:
  pre_dispatch:
    returns: "PROCEED | SKIP | PAUSE | BLOCK | updated_model"
    state_written: ".maestro/state.local.md (budget section)"
  post_dispatch:
    returns: void
    state_written: ".maestro/state.local.md (budget.dispatches)"
    downstream: "forecast skill record-actual"
  summary:
    returns: "formatted budget block for status display"
    side_effects: none
```
