---
name: token-ledger
description: "Track token usage and costs per story, feature, and session. Optional — disable with --no-cost-tracking. Use to log costs after each story completion."
effort: low
maxTurns: 3
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
```
