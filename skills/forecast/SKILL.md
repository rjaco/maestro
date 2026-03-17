---
name: forecast
description: "Estimate token cost before execution. Optional — disable with --no-forecast. Analyzes task complexity and produces cost breakdown."
---

# Forecast

Estimates the token cost and time for a feature before execution begins. Helps users make informed decisions about scope, model selection, and budget. This skill is optional and controlled by configuration.

## Configuration

Check `.maestro/config.yaml` first:

```yaml
cost_tracking:
  forecast: true    # set to false to skip forecasting entirely
```

If `cost_tracking.forecast` is `false`, skip all operations and return immediately with:
> "Forecasting is disabled. Use `--forecast` to enable for this run, or set `cost_tracking.forecast: true` in config."

## Input

- Story manifest from `decompose` (story count, complexity, types, model recommendations)
- Or: `$ARGUMENTS` describing the feature for a rough pre-decomposition estimate

## Process

### Step 1: Classify Complexity

If stories already exist (post-decomposition), use their metadata directly. Otherwise, analyze the feature description and classify:

| Complexity | Story Count | Signals |
|-----------|------------|---------|
| Simple | 1-2 stories | Single concern, clear pattern, config or styling change |
| Medium | 3-5 stories | Multiple concerns, some new logic, frontend + backend |
| Complex | 6-8 stories | Many concerns, new patterns, data model changes, integrations |

### Step 2: Estimate Per-Story Tokens

Apply per-story averages based on complexity:

| Story Complexity | Implementation Tokens | QA Review Tokens | Total per Story |
|-----------------|----------------------|------------------|-----------------|
| Simple | 15,000 | 5,000 | 20,000 |
| Medium | 25,000 | 10,000 | 35,000 |
| Complex | 40,000 | 10,000 | 50,000 |

### Step 3: Estimate Model Mix

Based on story types, estimate which model handles each phase:

| Phase | Default Model | Token Share |
|-------|--------------|-------------|
| Research | Sonnet (WebSearch) | 10-20K total |
| Architecture | Opus | 15-25K total |
| Decompose | Sonnet | 10-15K total |
| Implementation (per story) | Per story recommendation | Varies |
| QA Review (per story) | Opus | ~10K per story |
| Git operations | Haiku | ~2K per story |
| Preview (per checkpoint) | Sonnet | ~5K per checkpoint |

### Step 4: Calculate Cost Breakdown

Apply model pricing:

| Model | Input (per 1M) | Output (per 1M) |
|-------|----------------|-----------------|
| Opus | $15.00 | $75.00 |
| Sonnet | $3.00 | $15.00 |
| Haiku | $0.80 | $4.00 |

Assume a 60/40 input/output token ratio unless the task is heavily generative (then 40/60).

Present the breakdown:

```
Cost Forecast: [feature name]

Phase Breakdown:
  Research:       ~[tokens] tokens  ~$[cost]  (Sonnet)
  Architecture:   ~[tokens] tokens  ~$[cost]  (Opus)
  Decompose:      ~[tokens] tokens  ~$[cost]  (Sonnet)
  Stories (x[N]):  ~[tokens] tokens  ~$[cost]  (mixed)
  QA Reviews:     ~[tokens] tokens  ~$[cost]  (Opus)
  Git + Preview:  ~[tokens] tokens  ~$[cost]  (Haiku/Sonnet)

Total:            ~[tokens] tokens  ~$[cost]
```

### Step 5: Savings Tips

Suggest concrete ways to reduce cost if the estimate is high:

- **Downgrade models** — If some stories are recommended for Opus but could work with Sonnet, note the savings.
- **Skip optional phases** — Research and preview are skippable. Note their cost share.
- **Reduce scope** — If the feature has 8 stories, suggest which stories could be deferred without breaking the core feature.
- **Use yolo mode** — Skipping QA review saves roughly 30% of total cost (with the tradeoff of less validation).

### Step 6: Confirm

Present the forecast and ask:

> **Estimated cost: ~$[total]** ([token count] tokens across [story count] stories)
>
> Proceed? You can:
> - **approve** — Start execution with this estimate
> - **reduce** — Suggest which stories or phases to cut
> - **abort** — Cancel and rethink scope

## Output

- Cost forecast displayed to user inline
- Forecast logged to `.maestro/token-ledger.md` as a `forecast` phase entry
- User confirmation before proceeding to execution
