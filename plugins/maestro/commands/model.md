---
name: model
description: "View and edit model assignments per task type — interactive menu"
argument-hint: "[show]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Model — Interactive Model Manager

View and edit which AI model is used for each task type in the Maestro pipeline. Uses interactive menus for all changes.

## Step 1: Read Current Config

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

Stop here.

Look for the `models` section. If it does not exist, use these defaults:

```yaml
models:
  planning: opus
  execution: sonnet
  review: opus
  simple: haiku
  research: sonnet
```

Also read `.maestro/trust.yaml` for `model_performance` data if it exists.

## Step 2: Display Current Assignments

Always show the current state first:

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

  Cost reference (per million tokens):
    Haiku    $0.80 in / $4.00 out    (cheapest)
    Sonnet   $3.00 in / $15.00 out   (balanced)
    Opus     $15.00 in / $75.00 out  (most capable)
```

If `model_performance` data exists in trust.yaml, add:

```
  Performance (this project):
    sonnet   83% QA first-pass, 0.4 avg self-heal
    opus     100% QA first-pass, 0.0 avg self-heal
```

## Step 3: Interactive Menu

Use AskUserQuestion to present the action menu:

**Question:** "What would you like to change?"

**Options:**
1. **Change a task's model** — "Pick which task type to reassign to a different model"
2. **Apply a preset** — "Quick presets: Budget, Balanced, Quality, Max Performance"
3. **No changes** — "Keep current assignments"

### If "Change a task's model":

Use AskUserQuestion to ask which task type:

**Question:** "Which task type do you want to change?"

**Options** (show current model in description):
1. **planning** — "Currently: [model]. Used for decomposition, architecture, roadmaps"
2. **execution** — "Currently: [model]. Used for story implementation, code writing"
3. **review** — "Currently: [model]. Used for QA review, milestone eval, quality gates"
4. **simple** — "Currently: [model]. Used for fix agents, config, boilerplate"

(Note: AskUserQuestion supports max 4 options. If user selects "Other", they can type "research".)

Then use AskUserQuestion to ask which model, with previews showing the cost impact:

**Question:** "Which model for [task type]?"

**Options** (with preview showing cost comparison):
1. **Haiku** — "Fastest, cheapest. Best for simple/mechanical tasks"
   Preview: cost calculation for this task type with Haiku
2. **Sonnet** — "Balanced speed, quality, and cost. Good default"
   Preview: cost calculation for this task type with Sonnet
3. **Opus** — "Most capable. Best for complex reasoning"
   Preview: cost calculation for this task type with Opus

Preview format for each option:
```
Cost estimate for [task type]:

  [task] uses ~[N]K tokens per feature
  Current ([old model]): ~$[X.XX] per feature
  This option ([new model]): ~$[Y.YY] per feature
  Change: [+/-]$[Z.ZZ] ([+/-]N%)
```

Use these token estimates:
- planning: ~10K tokens per feature
- execution: ~30K tokens per story
- review: ~8K tokens per story
- simple: ~3K tokens per fix
- research: ~15K tokens per research sprint

Cost calculation: tokens * (input_price + output_price) / 2 / 1_000_000
- Haiku: tokens * 2.40 / 1_000_000
- Sonnet: tokens * 9.00 / 1_000_000
- Opus: tokens * 45.00 / 1_000_000

After selection, update `.maestro/config.yaml` and confirm:

```
[maestro] Updated: [task] model changed from [old] to [new]
```

Then loop back to Step 3 (ask if they want to change anything else).

### If "Apply a preset":

Use AskUserQuestion with previews showing each preset's full model mapping:

**Question:** "Which preset?"

**Options with previews:**

1. **Budget** — "Minimize cost. Sonnet for execution, Haiku for everything else"
   Preview:
   ```
   Budget Preset:
     planning:   haiku    (was: opus)
     execution:  sonnet   (unchanged)
     review:     haiku    (was: opus)
     simple:     haiku    (unchanged)
     research:   haiku    (was: sonnet)

   Estimated savings: ~60% vs default
   ```

2. **Balanced (default)** — "Good mix of quality and cost"
   Preview:
   ```
   Balanced Preset:
     planning:   opus     (default)
     execution:  sonnet   (default)
     review:     opus     (default)
     simple:     haiku    (default)
     research:   sonnet   (default)
   ```

3. **Quality** — "Opus for planning and review, Sonnet for execution"
   Preview:
   ```
   Quality Preset:
     planning:   opus     (unchanged)
     execution:  sonnet   (unchanged)
     review:     opus     (unchanged)
     simple:     sonnet   (was: haiku)
     research:   opus     (was: sonnet)

   Estimated increase: ~40% vs default
   ```

4. **Max Performance** — "Opus for everything. Maximum quality, maximum cost"
   Preview:
   ```
   Max Performance Preset:
     planning:   opus     (unchanged)
     execution:  opus     (was: sonnet)
     review:     opus     (unchanged)
     simple:     opus     (was: haiku)
     research:   opus     (was: sonnet)

   Estimated increase: ~200% vs default
   ```

After selection, apply the preset to `.maestro/config.yaml` and confirm:

```
[maestro] Applied "[preset]" preset.

  planning:   [model]
  execution:  [model]
  review:     [model]
  simple:     [model]
  research:   [model]
```

### If "No changes":

```
[maestro] No changes made.
```

Stop here.

## Step 4: Write Config

When updating `.maestro/config.yaml`:

1. If a `models` section exists, update the relevant key(s)
2. If no `models` section exists, add the full section with all 5 task types
3. Keep all other config sections unchanged

```yaml
models:
  planning: [model]
  execution: [model]
  review: [model]
  simple: [model]
  research: [model]
```

## Guidelines

When the user asks for advice or selects "Other" with a question, provide these guidelines:

| Scenario | Recommendation |
|----------|----------------|
| Well-understood codebase, clear patterns | execution: sonnet |
| Novel architecture, complex logic | execution: opus |
| Tight budget, many small stories | Budget preset |
| Quality-critical (fintech, healthcare) | Quality or Max Performance preset |
| Rapid prototyping, exploration | Balanced preset |
| First time using Maestro on a project | Balanced preset (learn trust levels first) |
