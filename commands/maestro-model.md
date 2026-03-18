---
description: "View and edit model assignments per task type"
argument-hint: "[show|set TASK MODEL]"
allowed-tools: Read Write Edit Bash
---

# Maestro Model — Model Assignment Manager

View and edit which AI model is used for each task type in the Maestro pipeline.

## Step 1: Read Current Config

Read `.maestro/config.yaml`. If it does not exist:

```
Maestro is not initialized. Run /maestro-init first.
```

Stop here.

Look for the `models` section. If it does not exist, use these defaults:

```yaml
models:
  planning: opus         # Decomposition, architecture, roadmap generation
  execution: sonnet      # Story implementation, code writing
  review: opus           # QA review, milestone evaluation, Opus quality gate
  simple: haiku          # Fix agents, config changes, boilerplate
  research: sonnet       # Web research, competitive analysis
```

## Step 2: Handle Arguments

### No arguments or `show` — Display current assignments

Read `.maestro/trust.yaml` and check for a `model_performance` section. This section contains per-model stats like `qa_first_pass_rate` and `avg_self_heal_cycles`.

```
+---------------------------------------------+
| Model Assignments                           |
+---------------------------------------------+

  Task Type     Model      Used For
  ----------    -------    ----------------------------------------
  planning      opus       Decomposition, architecture, roadmaps
  execution     sonnet     Story implementation, code writing
  review        opus       QA review, milestone eval, quality gates
  simple        haiku      Fix agents, config, boilerplate
  research      sonnet     Web research, competitive analysis

  Performance (this project):
    (If `.maestro/trust.yaml` has `model_performance` data, show each model:)
    sonnet   [qa_first_pass_rate]% QA first-pass, [avg_self_heal_cycles] avg self-heal cycles
    opus     [qa_first_pass_rate]% QA first-pass, [avg_self_heal_cycles] avg self-heal cycles
    haiku    [qa_first_pass_rate]% QA first-pass, [avg_self_heal_cycles] avg self-heal cycles
    (Only show models that have performance data recorded.
     If no `model_performance` data exists, show:)
    No performance data yet.

+---------------------------------------------+

Cost reference (per million tokens):
  Haiku:   $0.80 input / $4.00 output
  Sonnet:  $3.00 input / $15.00 output
  Opus:    $15.00 input / $75.00 output

To change: /maestro-model set <task> <model>
Example:   /maestro-model set execution opus
```

### `set TASK MODEL` — Update a model assignment

Validate the task type is one of: `planning`, `execution`, `review`, `simple`, `research`.

Validate the model is one of: `haiku`, `sonnet`, `opus`.

If valid, update `.maestro/config.yaml`:

```
Updated: [task] model changed from [old] to [new]

Note: This affects all future Maestro sessions.
Higher-capability models produce better results but cost more.
```

If invalid task type:
```
Unknown task type: [input]
Valid types: planning, execution, review, simple, research
```

If invalid model:
```
Unknown model: [input]
Valid models: haiku, sonnet, opus
```

### Cost Impact Preview

When changing a model assignment, show the estimated cost impact:

```
+---------------------------------------------+
| Cost Impact Preview                         |
+---------------------------------------------+

  Changing [task] from [old] to [new]:

  [task] typically uses ~[N]K tokens per feature.
  Old cost: ~$[N] per feature
  New cost: ~$[N] per feature
  Change:   [+/-]$[N] per feature ([+/-]N%)

+---------------------------------------------+

Proceed? [Y/n]
```

Estimates are based on historical data from `.maestro/token-ledger.md` if available, otherwise use defaults:
- planning: ~10K tokens per feature
- execution: ~30K tokens per story (largest consumer)
- review: ~8K tokens per story
- simple: ~3K tokens per fix
- research: ~15K tokens per research sprint

## Model Selection Guidelines

Display these guidelines when the user asks for advice:

| Scenario | Recommended Model |
|----------|-------------------|
| Well-understood codebase, clear patterns | execution: sonnet |
| Novel architecture, complex logic | execution: opus |
| Tight budget, many small stories | execution: sonnet, simple: haiku |
| Quality-critical (fintech, healthcare) | review: opus, execution: opus |
| Rapid prototyping, exploration | execution: sonnet, review: sonnet |
| Cost optimization | review: sonnet, simple: haiku |
