---
name: token-ledger
description: "Track token usage and costs per story, feature, and session. Optional — disable with --no-cost-tracking. Use to log costs after each story completion."
---

# token-ledger

## Purpose

Understand where tokens go. Identify expensive patterns. Forecast costs for upcoming work. All optional — if the team doesn't care about costs, disable it and this skill stays dormant.

## Configuration

Check `.maestro/config.yaml` before doing anything:

```yaml
cost_tracking:
  ledger: true      # enable/disable the ledger entirely
  forecast: true    # estimate costs before features start
```

If `cost_tracking.ledger` is `false`, skip all operations. Do nothing. Return immediately.

## Ledger Format

After each story completion, append a row to `.maestro/token-ledger.md`:

```markdown
| Date | Feature | Story | Tokens | Est. Cost | Model | Phase |
|------|---------|-------|--------|-----------|-------|-------|
| 2026-03-17 | auth | story-03 | 8,200 | $0.12 | sonnet | implement |
| 2026-03-17 | auth | story-03 | 3,100 | $0.23 | opus | qa-review |
```

After each feature is complete, add a summary row:

```markdown
| | **auth total** | | **42,500** | **$1.87** | | |
```

Include a grand total at the bottom of the file.

## Cost Estimation

Approximate per-model pricing (input / output per million tokens):

| Model | Input | Output |
|-------|-------|--------|
| Sonnet | $3.00 | $15.00 |
| Opus | $15.00 | $75.00 |
| Haiku | $0.80 | $4.00 |

These are estimates. Actual pricing may vary. Use a 60/40 input/output split as a default assumption when exact breakdowns are unavailable.

## Forecasting

If `cost_tracking.forecast` is `true`, before a feature starts:

1. Count the number of stories in the feature.
2. Estimate tokens per story based on complexity (simple: ~20K, medium: ~35K, complex: ~50K).
3. Add QA review overhead (roughly 30% of implementation tokens, at Opus pricing).
4. Log the forecast in the ledger as a `forecast` phase row.

## Data Source

Token counts come from agent task completion notifications. Look for the `total_tokens` field in the task output. If unavailable, estimate from response length (roughly 1.3 tokens per word for English text).

## Ledger Format

```markdown
# Token Ledger

## Session: [session_id]
Feature: [name]
Date: [date]

| Story | Phase | Model | Tokens | Cost |
|-------|-------|-------|--------|------|
| 01-schema | delegate | sonnet | 4,200 | $0.04 |
| 01-schema | implement | sonnet | 28,400 | $0.26 |
| 01-schema | qa_review | opus | 8,100 | $0.36 |
| **Total** | | | **40,700** | **$0.66** |

## Grand Total
| Sessions | Stories | Tokens | Cost |
|----------|---------|--------|------|
| 3 | 10 | 187,400 | $8.15 |
```

## Per-Story Cost Tracking

After each agent dispatch, log a detailed row capturing every token category. This enables post-hoc analysis of which story phases are most expensive and where cache utilization is paying off.

Append to `.maestro/token-ledger.md` immediately after the agent returns:

```markdown
| Story | Model | Input | Output | Cache Read | Cache Create | Total Cost |
|-------|-------|-------|--------|------------|-------------|------------|
| M2-05 | sonnet | 12K | 3K | 8K | 4K | $0.08 |
| M2-06 | sonnet | 9K | 2K | 14K | 0 | $0.04 |
| M2-07 | opus | 6K | 4K | 11K | 2K | $0.51 |
```

**Column definitions:**

| Column | Source | Notes |
|--------|--------|-------|
| Story | Story ID from dispatch | e.g. M2-05 |
| Model | Model used for this dispatch | sonnet / opus / haiku |
| Input | Input tokens (excluding cache) | Raw tokens sent |
| Output | Output tokens generated | Completion tokens |
| Cache Read | Tokens served from cache | Reduces cost by ~90% vs input |
| Cache Create | Tokens written into cache | Charged at 1.25× input rate |
| Total Cost | Computed from all columns | See pricing table above |

**Cost computation formula:**

```
cost = (input × input_rate)
     + (output × output_rate)
     + (cache_read × input_rate × 0.10)
     + (cache_create × input_rate × 1.25)
```

Apply rates from the Cost Estimation table. If cache breakdown is unavailable, record `—` in those columns and use the 60/40 input/output split.

**Phase column:** Add a `Phase` column when a story dispatches more than one agent (e.g., implement + qa-review). This lets the ledger distinguish which phase drove the cost.

```markdown
| Story | Phase | Model | Input | Output | Cache Read | Cache Create | Total Cost |
|-------|-------|-------|-------|--------|------------|-------------|------------|
| M2-05 | implement | sonnet | 12K | 3K | 8K | 4K | $0.08 |
| M2-05 | qa-review | opus | 4K | 1K | 6K | 0 | $0.23 |
```

## Cost-per-LOC Metric

Track the efficiency of each story dispatch as tokens consumed per line of code produced. This metric normalizes cost across stories of different sizes and reveals whether the team is improving, plateauing, or regressing over time.

**Formula:**

```
cost_per_loc = total_tokens / lines_changed
```

Where `lines_changed` = lines added + lines deleted in the story's final diff (from `git diff --stat`).

**Recording format** — append a `Cost/LOC` column to the per-story table:

```markdown
| Story | Model | Input | Output | Cache Read | Cache Create | Total Cost | Lines Changed | Cost/LOC |
|-------|-------|-------|--------|------------|-------------|------------|---------------|----------|
| M2-05 | sonnet | 12K | 3K | 8K | 4K | $0.08 | 87 | 172 tok/LOC |
| M2-06 | sonnet | 9K | 2K | 14K | 0 | $0.04 | 34 | 324 tok/LOC |
| M2-07 | opus | 6K | 4K | 11K | 2K | $0.51 | 210 | 100 tok/LOC |
```

**Baseline targets** (adjust per project as history accumulates):

| Story complexity | Target Cost/LOC |
|-----------------|----------------|
| Simple (< 50 LOC) | ≤ 400 tok/LOC |
| Medium (50–200 LOC) | ≤ 250 tok/LOC |
| Complex (> 200 LOC) | ≤ 150 tok/LOC |

**Trend tracking** — at the end of each milestone, compute a rolling average:

```
milestone_avg_cost_per_loc = sum(total_tokens for all stories) / sum(lines_changed for all stories)
```

Log this in the Grand Total block:

```markdown
## Grand Total
| Sessions | Stories | Tokens | Cost | Total LOC | Avg Cost/LOC |
|----------|---------|--------|------|-----------|--------------|
| 3 | 10 | 187,400 | $8.15 | 1,240 | 151 tok/LOC |
```

**When `lines_changed` is unavailable** (e.g., the story only modified config or docs): record `N/A` in the Cost/LOC column and exclude it from trend calculations.

## Budget Forecasting

At the start of each milestone, and again after every 3 stories complete, compute a remaining-cost forecast based on observed story costs.

**Formula:**

```
remaining_cost = avg_cost_per_story × remaining_stories
```

Where:
- `avg_cost_per_story` = total cost so far in this milestone / stories completed so far
- `remaining_stories` = total stories in milestone - stories completed

**Recording format** — append a forecast block to the ledger after each checkpoint:

```markdown
## Forecast — Milestone M2 (updated 2026-03-18)
| Metric | Value |
|--------|-------|
| Stories completed | 5 of 12 |
| Total cost so far | $1.23 |
| Avg cost per story | $0.246 |
| Remaining stories | 7 |
| Projected remaining cost | $1.72 |
| Projected milestone total | $2.95 |
```

**Confidence interval:** When fewer than 3 stories have completed, label the forecast as `LOW CONFIDENCE`. The sample is too small to be reliable. After 5+ stories, the forecast is considered `STABLE`.

**Model mix adjustment:** If the completed stories used a different model mix than the remaining stories are expected to use (e.g., a QA-heavy second half), adjust the forecast:

```
adjusted_forecast = (remaining_implement_stories × avg_implement_cost)
                  + (remaining_qa_stories × avg_qa_cost)
```

Log any model mix adjustment as a note in the forecast block:

```markdown
Note: Remaining stories include 3 QA-heavy reviews (opus). Forecast adjusted upward from $1.72 to $2.41.
```

**Trigger conditions for re-forecasting:**
1. Every 3 stories completed.
2. When any single story costs more than 2× the current average (cost spike detected).
3. When the model assignment for a story changes from the default (e.g., escalated to opus due to complexity).

## Integration

- Updated by dev-loop at CHECKPOINT phase
- Read by forecast skill for cost estimation
- Read by history command for cost analysis
- Read by retrospective for spending patterns
- Read by benchmark for efficiency tracking

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/token-ledger.md"
  required_sections:
    - "## Grand Total"
    - "## Forecast"
```
