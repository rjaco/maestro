---
name: cost-estimate
description: "Estimate token cost before building. Shows expected spend by model, story count, and complexity."
argument-hint: "DESCRIPTION"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Maestro Cost Estimate

Estimates token cost before building a feature. Like `terraform plan` showing infrastructure cost, this shows expected token spend broken down by model, story count, complexity, and execution mode. Helps you make informed decisions about scope and budget before a single token is spent.

## Step 1: Check Prerequisites

1. Read `.maestro/config.yaml`. If it does not exist:
   ```
   [maestro] Not initialized. Run /maestro init first.
   ```
   Stop here.

2. If `$ARGUMENTS` is empty, show usage:
   ```
   +---------------------------------------------+
   | Cost Estimate                               |
   +---------------------------------------------+

     Usage:
       /maestro cost-estimate "Add user auth"
       /maestro cost-estimate "Migrate DB to Postgres"

     Shows:
       - Expected story count and complexity
       - Token cost breakdown by model
       - Comparison across execution modes
       - Historical averages (if available)
   ```
   Stop here.

3. Read `.maestro/dna.md` to load project context (tech stack, patterns, complexity signals).

## Step 2: Parse Description and Classify Complexity

Analyze `$ARGUMENTS` as the feature description. Classify the overall complexity based on these signals:

### Simple (Score: 1-3)

Signals:
- Single concern (e.g., "add dark mode toggle", "fix broken link")
- Config or styling changes
- Clear, well-known pattern (CRUD, toggle, rename)
- Few files affected (1-3)
- No new data models
- No external integrations

Result: 2-3 stories, mostly simple stories.

### Medium (Score: 4-6)

Signals:
- Multiple concerns (e.g., "add user auth with login page")
- Frontend + backend coordination
- New routes or endpoints
- Some new logic but follows existing patterns
- 4-8 files affected
- May involve one new data model

Result: 4-5 stories, mix of simple and medium stories.

### Complex (Score: 7-10)

Signals:
- Many concerns (e.g., "real-time notifications with WebSockets")
- New architectural patterns
- Multiple new data models or schema changes
- External service integrations
- Cross-cutting concerns (auth, permissions, caching)
- 10+ files affected
- Edge cases and error handling are significant

Result: 6-8 stories, mix of medium and complex stories.

### Scoring

Assign 1 point for each signal that matches. Sum to get the complexity score.

Display the classification:

```
[maestro] Analyzing: "[DESCRIPTION]"

  Complexity:  [simple|medium|complex] (score: [N]/10)
  Signals:
    (ok) [matched signal 1]
    (ok) [matched signal 2]
    --   [unmatched signal]
```

## Step 3: Estimate Story Count and Types

Based on complexity, estimate the story breakdown:

| Complexity | Total Stories | Typical Breakdown |
|-----------|-------------|-------------------|
| Simple | 2-3 | 1 backend, 1 frontend, 0-1 test |
| Medium | 4-5 | 1 data, 1-2 backend, 1 frontend, 1 test |
| Complex | 6-8 | 1 data, 2-3 backend, 1-2 frontend, 1 integration, 1 test |

For each estimated story, assign a story-level complexity:
- Data/schema stories: simple
- Backend API stories: medium
- Frontend UI stories: medium
- Integration stories: complex
- Test stories: simple

## Step 4: Read Configuration for Model Assignments

Read `.maestro/config.yaml` and extract:
- `models.planning` (default: opus)
- `models.execution` (default: sonnet)
- `models.qa` (default: opus)
- `models.commit` (default: haiku)
- `mode` (default: checkpoint)

If model assignments are missing, use defaults.

## Step 5: Read Historical Averages

Check if `.maestro/token-ledger.md` exists. If it does:

1. Parse the ledger for completed stories.
2. Calculate historical averages:
   - Average tokens per story (by complexity)
   - Average QA tokens per story
   - Average self-heal overhead percentage
   - Average total tokens per feature
3. Use these averages to refine the estimate. If historical data is available, weight it 60% historical / 40% base estimate.

If the ledger does not exist:
```
  (i) No historical data. Using base estimates.
      Actuals will refine future forecasts.
```

## Step 6: Calculate Cost Per Model

### Base Token Estimates Per Story

| Phase | Model | Simple Story | Medium Story | Complex Story |
|-------|-------|-------------|-------------|---------------|
| Delegation | Sonnet | ~1,500 | ~2,500 | ~4,000 |
| Implementation | Config model | ~12,000 | ~25,000 | ~40,000 |
| Self-heal (avg) | Config model | ~3,000 | ~6,000 | ~10,000 |
| QA Review | Opus | ~5,000 | ~8,000 | ~12,000 |
| Git operations | Haiku | ~2,400 | ~2,400 | ~2,400 |

### Fixed Overhead (per feature)

| Phase | Model | Tokens |
|-------|-------|--------|
| Research/context | Sonnet | ~10,000 |
| Architecture | Opus | ~15,000 |
| Decomposition | Sonnet | ~8,000 |
| Final summary | Haiku | ~2,000 |

### Self-Heal Overhead Factor

Self-heal adds overhead based on complexity:
- Simple stories: +10% of implementation tokens
- Medium stories: +20% of implementation tokens
- Complex stories: +30% of implementation tokens

### Model Pricing

| Model | Input (per 1M) | Output (per 1M) |
|-------|----------------|-----------------|
| Opus | $15.00 | $75.00 |
| Sonnet | $3.00 | $15.00 |
| Haiku | $0.80 | $4.00 |

Assume 60/40 input/output token ratio.

### Calculate Totals

For each model, sum all tokens across phases and stories:

```
haiku_tokens  = (git_ops * story_count) + final_summary
sonnet_tokens = (delegation * story_count) + research + decomposition + (implementation tokens if model is sonnet)
opus_tokens   = (qa_review * story_count) + architecture + (implementation tokens if model is opus)
```

Convert to cost using pricing table and 60/40 split:
```
cost = tokens * (0.6 * input_price + 0.4 * output_price) / 1,000,000
```

## Step 7: Calculate Mode Comparison

Compare costs across the three execution modes:

### Yolo Mode
- No checkpoint pauses (saves ~5% overhead tokens)
- No preview generation (saves ~5K per checkpoint)
- Total savings: ~15% off base estimate
- Risk: no human review between stories

### Checkpoint Mode (default)
- Base estimate (no adjustment)
- Pauses between stories for review
- Preview generation at each checkpoint

### Careful Mode
- Extra validation at each story (adds ~10% overhead)
- Deeper QA review with more iterations (adds ~10% to QA)
- Total increase: ~20% above base estimate
- Benefit: higher quality, fewer post-build fixes

## Step 8: Display the Forecast

```
+---------------------------------------------+
| Cost Estimate                               |
+---------------------------------------------+

  Feature:     [DESCRIPTION]
  Complexity:  [simple|medium|complex]
  Stories:     ~[N] ([breakdown by type])

  Token Breakdown by Model:
    Haiku     ~[N] tokens    ~$[N.NN]
    Sonnet    ~[N] tokens    ~$[N.NN]
    Opus      ~[N] tokens    ~$[N.NN]

  Phase Breakdown:
    Research + Context     ~[N] tokens    ~$[N.NN]
    Architecture           ~[N] tokens    ~$[N.NN]
    Decomposition          ~[N] tokens    ~$[N.NN]
    Implementation (x[N])  ~[N] tokens    ~$[N.NN]
    Self-heal overhead     ~[N] tokens    ~$[N.NN]
    QA Reviews (x[N])      ~[N] tokens    ~$[N.NN]
    Git + Summary          ~[N] tokens    ~$[N.NN]

  ---- Total: ~[N]K tokens   ~$[N.NN] ----

  Mode Comparison:
    yolo         ~$[N.NN]   (~15% less)
    checkpoint   ~$[N.NN]   (default)
    careful      ~$[N.NN]   (~20% more)

  (i) Tip: yolo saves ~15% by skipping checkpoints.
      careful costs ~20% more but catches issues early.
```

If historical data was used:

```
  Historical Context:
    (i) Based on [N] prior stories in this project.
    (i) Avg actual cost per story: ~$[N.NN]
    (i) Estimate confidence: [low|medium|high]
```

## Step 9: Ask User to Proceed

Use AskUserQuestion:
- Question: "Estimated cost: ~$[total] ([token_count] tokens, [story_count] stories). Proceed?"
- Header: "Estimate"
- Options:
  1. label: "Build now (Recommended)", description: "Start /maestro with checkpoint mode"
  2. label: "Build with mode selection", description: "Choose yolo, checkpoint, or careful first"
  3. label: "Adjust scope", description: "Reduce stories or change models to lower cost"
  4. label: "Cancel", description: "Don't build, keep the estimate for reference"

### If "Build now"

```
[maestro] Starting build with checkpoint mode.

  Estimated: ~$[total] across ~[N] stories.
  Run /maestro status to monitor progress.
```

Transition to `/maestro` with the description.

### If "Build with mode selection"

Use AskUserQuestion:
- Question: "Select execution mode:"
- Header: "Mode"
- Options:
  1. label: "yolo (~$[yolo_cost])", description: "Auto-approve everything. Fastest, cheapest."
  2. label: "checkpoint (~$[checkpoint_cost]) (Recommended)", description: "Pause between stories for review."
  3. label: "careful (~$[careful_cost])", description: "Extra validation. Highest quality."

Then transition to `/maestro` with the selected mode.

### If "Adjust scope"

Show scope reduction suggestions:

```
  Scope Reduction Options:
    1. Downgrade [N] stories from Opus to Sonnet
       Saves: ~$[N.NN]

    2. Skip [story type] stories (defer to later)
       Saves: ~$[N.NN]

    3. Use yolo mode
       Saves: ~$[N.NN]

    4. Simplify: reduce to [N] core stories only
       Saves: ~$[N.NN]
```

Use AskUserQuestion:
- Question: "Which adjustment?"
- Header: "Adjust"
- Options generated from the reduction options above.

After adjustment, recalculate and show the updated estimate.

### If "Cancel"

```
[maestro] Estimate saved for reference.

  (i) Re-run with: /maestro cost-estimate "[DESCRIPTION]"
  (i) Build anytime with: /maestro "[DESCRIPTION]"
```

## Integration Points

- **Token Ledger**: reads `.maestro/token-ledger.md` for historical averages
- **Config**: reads `.maestro/config.yaml` for model assignments and mode
- **Forecast Skill**: shares estimation logic with the forecast skill
- **Plan Command**: `/maestro plan` can invoke cost-estimate inline
- **History Command**: `/maestro history cost` shows actual vs estimated

## Error Handling

| Error | Action |
|-------|--------|
| No config file | Prompt to run `/maestro init` |
| No description provided | Show usage help |
| Ledger file malformed | Fall back to base estimates, warn user |
| Model not recognized | Use Sonnet pricing as default, warn user |

## Output Contract

```yaml
output_contract:
  display:
    format: "box-drawing"
    sections:
      - "Cost Estimate header"
      - "Token Breakdown by Model"
      - "Phase Breakdown"
      - "Mode Comparison"
      - "Total line"
  user_decision:
    tool: "AskUserQuestion"
    options: ["Build now", "Build with mode selection", "Adjust scope", "Cancel"]
  data_read:
    - ".maestro/config.yaml"
    - ".maestro/dna.md"
    - ".maestro/token-ledger.md (optional)"
```
