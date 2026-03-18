---
name: benchmark
description: "Performance benchmarking for Maestro operations. Measures token usage, execution time, and quality metrics across stories and sessions."
---

# Benchmark

Measure and compare Maestro's performance across operations, stories, and sessions. Surface regressions, confirm improvements, and give the team a ground-truth view of how the system is performing over time.

## Metrics Tracked

| Metric | Source | Unit | What It Means |
|--------|--------|------|---------------|
| Tokens/story | `.maestro/token-ledger.md` | tokens | Total tokens consumed per completed story |
| Tokens/milestone | `.maestro/token-ledger.md` | tokens | Aggregate across all stories in a milestone |
| Time/story | State timestamps in dev-loop | seconds | Wall-clock time from story start to commit |
| QA first-pass rate | `.maestro/trust.yaml` | percentage | Stories that passed QA without a self-heal cycle |
| Self-heal cycles | State tracking | count/story | Avg number of correction loops per story |
| Commit score | commit-score skill output | 0-100 | Quality of produced commits |
| Context efficiency | Context engine logs | % | Tokens used vs. tokens budgeted for the story |
| Cost/story | Derived from token-ledger | USD | Estimated dollar cost per story at current model pricing |

## Data Source

All benchmark data is pulled from two canonical sources:

1. **`.maestro/token-ledger.md`** — Token and cost data per story and phase. Read the ledger rows for the target feature/session. If the ledger is disabled (`cost_tracking.ledger: false`), tokens and cost columns are omitted from output.

2. **`.maestro/trust.yaml`** — QA pass rates, self-heal stats, and commit score history. These values are maintained live by dev-loop and commit-score.

If either file is missing or empty, emit a warning row in the output table and continue with available data.

## Operations

### benchmark_story(story_id)

After a story completes, capture all metrics and render a single-story panel:

```
+-----------------------------------------------------------+
| Story: 03-api-routes                       2026-03-17     |
+------------------+--------------------+-------------------+
| Tokens           | 28,400             | (budget: 35,000)  |
| Est. Cost        | $0.54              |                   |
| Time             | 3m 22s             |                   |
| QA               | PASS (1st attempt) |                   |
| Self-heal cycles | 0                  |                   |
| Commit score     | 85 / 100 (Silver)  |                   |
| Context use      | 52%                | (4,200 / 8,000)   |
+------------------+--------------------+-------------------+
```

Steps:
1. Read the story's rows from the token-ledger (all phases: delegate, implement, qa_review).
2. Sum tokens across phases. Derive cost using the model pricing table in token-ledger.
3. Read QA result and self-heal count from dev-loop state.
4. Read commit score from the most recent commit-score output.
5. Calculate context efficiency: `tokens_used / context_budget * 100`.
6. Render the ASCII panel above. Append to `.maestro/logs/benchmarks.md` under `## Story Benchmarks`.

### benchmark_feature(feature_name)

After a feature completes, aggregate across all its stories:

```
+-----------------------------------------------------------+
| Feature: User Authentication (5 stories)  2026-03-17     |
+----------------------+----------------+-------------------+
| Avg tokens/story     | 26,800         |                   |
| Avg cost/story       | $0.76          |                   |
| Total cost           | $3.82          |                   |
| Avg time/story       | 2m 48s         |                   |
| QA first-pass rate   | 80%            | (4 of 5 stories)  |
| Avg self-heal cycles | 0.4            |                   |
| Avg commit score     | 82 / 100       | (Silver)          |
| Avg context use      | 61%            |                   |
+----------------------+----------------+-------------------+
```

Steps:
1. Collect all story_ids belonging to the feature from the token-ledger.
2. Run benchmark_story logic for each, accumulate values.
3. Compute averages and totals.
4. Append to `.maestro/logs/benchmarks.md` under `## Feature Benchmarks`.

### benchmark_session()

Summarize the current session across all features:

```
+-----------------------------------------------------------+
| Session Summary                            2026-03-17     |
+----------------------+----------------+-------------------+
| Features completed   | 2              |                   |
| Stories completed    | 8              |                   |
| Total tokens         | 214,400        |                   |
| Total cost           | $7.92          |                   |
| Avg tokens/story     | 26,800         |                   |
| QA first-pass rate   | 87.5%          | (7 of 8)          |
| Avg commit score     | 84             | (Silver)          |
+----------------------+----------------+-------------------+
```

### benchmark_compare(target, baseline)

Compare a current feature or session against a historical baseline. `target` and `baseline` can each be a feature name or a date string (`2026-03-15`).

```
+------------------------------------------------------------+
| Comparison: Auth (Mar 15) vs Dashboard (Mar 17)            |
+----------------------+----------+----------+---------------+
| Metric               | Baseline | Current  | Delta         |
+----------------------+----------+----------+---------------+
| Avg tokens/story     | 26,800   | 22,100   | -18%  BETTER  |
| Avg cost/story       | $0.76    | $0.63    | -17%  BETTER  |
| Avg time/story       | 2m 48s   | 2m 15s   | -20%  BETTER  |
| QA first-pass rate   | 80%      | 100%     | +20%  BETTER  |
| Avg commit score     | 82       | 88       | +7%   BETTER  |
| Avg context use      | 61%      | 54%      | -7%   BETTER  |
+----------------------+----------+----------+---------------+
| Overall trend        |                     | IMPROVING     |
+----------------------+----------+----------+---------------+
```

Delta direction:
- For tokens, cost, time, context use: lower is BETTER.
- For QA pass rate, commit score: higher is BETTER.
- Mark BETTER in green (or `+` prefix in plain text), WORSE in red (or `-` prefix).
- If delta is within ±5%, mark as STABLE.

Overall trend: IMPROVING if majority of metrics improved; REGRESSING if majority worsened; MIXED otherwise.

## Thresholds and Alerts

If any metric crosses a warning threshold, prepend a `[WARN]` line to the benchmark output:

| Metric | Warning Threshold | Critical Threshold |
|--------|------------------|--------------------|
| Tokens/story | >45,000 | >60,000 |
| Cost/story | >$1.20 | >$2.00 |
| QA first-pass rate | <75% | <50% |
| Avg self-heal cycles | >1.5 | >3 |
| Commit score | <70 | <50 |
| Context use | >85% | >95% |

Example:
```
[WARN] QA first-pass rate is 60% — below 75% threshold.
       Consider reviewing prompts or splitting complex stories.
```

## Integration

- Called automatically by dev-loop at the CHECKPOINT phase after each story.
- Called by dev-loop at feature completion.
- Data appended to `.maestro/logs/benchmarks.md` (created on first write).
- Benchmark compare is triggered by `/maestro benchmark compare <a> <b>` or by retrospective skill.
- Displayed in `/maestro history cost` (cost and token columns only).
- Fed into retrospective for trend analysis and recommendations.

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/logs/benchmarks.md"
  required_sections:
    - "## Story Benchmarks"
    - "## Feature Benchmarks"
  on_missing_data: emit_warning_row
```
