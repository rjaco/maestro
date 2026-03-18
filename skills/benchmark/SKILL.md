---
name: benchmark
description: "Performance benchmarking for Maestro operations. Measures token usage, execution time, and quality metrics across stories and sessions."
---

# Benchmark

Measure and compare Maestro's performance across operations, stories, and sessions.

## Metrics Tracked

| Metric | Source | Unit |
|--------|--------|------|
| Token usage | Token ledger | tokens per story |
| Execution time | State timestamps | seconds per phase |
| QA pass rate | Trust metrics | percentage |
| Self-heal cycles | State tracking | count per story |
| Commit score | Commit-score skill | 0-100 |
| Context efficiency | Context engine logs | tokens used / tokens budgeted |

## Operations

### benchmark_story(story_id)

After a story completes, capture all metrics:

```
Story 03: API Routes
  Tokens:       28,400
  Time:         3m 22s
  QA:           passed (1st attempt)
  Self-heal:    0 cycles
  Commit score: 85 (Silver)
  Context:      4,200 / 8,000 tokens (52% efficient)
```

### benchmark_feature(feature_name)

After a feature completes, aggregate across stories:

```
Feature: User Authentication (5 stories)
  Avg tokens/story:  26,800
  Avg time/story:    2m 48s
  QA first-pass:     80%
  Total cost:        $3.82
  Avg commit score:  82 (Silver)
```

### benchmark_compare(feature_a, feature_b)

Compare two features to detect improvement trends:

```
Comparison: Auth (Mar 15) vs Dashboard (Mar 17)
  Tokens:  26.8K -> 22.1K  (-18%)
  Time:    2m48s -> 2m15s  (-20%)
  QA rate: 80% -> 100%     (+20%)
  Cost:    $3.82 -> $3.10  (-19%)
  Score:   82 -> 88        (+7%)
```

## Integration

- Called by dev-loop at CHECKPOINT phase
- Data stored in `.maestro/logs/benchmarks.md`
- Fed into retrospective for trend analysis
- Displayed in `/maestro history cost`

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/logs/benchmarks.md"
  required_sections:
    - "## Story Benchmarks"
    - "## Feature Benchmarks"
```
