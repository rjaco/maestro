---
name: model
description: "View and change which AI model is used for each task type — planning, execution, review, and research"
argument-hint: "[preset]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Model — Interactive Model Manager

## Usage

```
/maestro model [preset]
```

## Presets

| Preset | planning | execution | review | simple | research |
|--------|----------|-----------|--------|--------|----------|
| `budget` | haiku | sonnet | haiku | haiku | haiku |
| `balanced` | opus | sonnet | opus | haiku | sonnet |
| `quality` | opus | sonnet | opus | sonnet | opus |
| `max` | opus | opus | opus | opus | opus |

## Examples

```
/maestro model
/maestro model budget
/maestro model quality
/maestro model max
```

_(Without arguments, displays current assignments and opens an interactive selection form.)_

## See Also

- `/maestro config` — Full configuration editor (includes model settings)
- `/maestro help cost` — Model pricing and cost tracking details

View and edit which AI model is used for each task type. Uses a single multi-question form to configure all task types at once.

## Step 1: Read Current Config

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

Stop here.

Look for the `models` section. If it does not exist, use these defaults and note "(default)" next to each:

```yaml
models:
  planning: opus
  execution: sonnet
  review: opus
  simple: haiku
  research: sonnet
```

## Step 2: Show Current + Ask All At Once

Display the current assignments briefly:

```
+---------------------------------------------+
| Model Assignments                           |
+---------------------------------------------+
  planning   opus    |  execution  sonnet
  review     opus    |  simple     haiku
  research   sonnet  |

  Haiku $0.80/$4  Sonnet $3/$15  Opus $15/$75
```

Then use a SINGLE AskUserQuestion call with ALL 4 questions (max allowed) to let the user configure everything in one screen. Group the 5 task types into 4 questions (combine the two least-changed ones):

```
AskUserQuestion with 4 questions:

Question 1 — header: "Planning"
  "Model for planning? (decomposition, architecture, roadmaps)"
  Options:
    - "Opus (current)" or "Opus" — "Most capable. Best for complex decomposition"
    - "Sonnet" — "Balanced. Good for straightforward planning"
    - "Haiku" — "Cheapest. OK for simple task breakdowns"

Question 2 — header: "Execution"
  "Model for execution? (story implementation, code writing)"
  Options:
    - "Opus" — "Best code quality, fewer QA rejections. ~$1.35/story"
    - "Sonnet (current)" or "Sonnet" — "Balanced quality and cost. ~$0.27/story"
    - "Haiku" — "Fastest, cheapest. Risk: more QA cycles. ~$0.07/story"

Question 3 — header: "Review"
  "Model for QA review? (code review, quality gates)"
  Options:
    - "Opus (current)" or "Opus" — "Catches more issues. Best for critical code"
    - "Sonnet" — "Good review quality at lower cost"
    - "Haiku" — "Basic checks only. Not recommended"

Question 4 — header: "Other"
  "Model for simple tasks + research?"
  Options:
    - "Both Haiku" — "Cheapest for fixes and research"
    - "Haiku fixes, Sonnet research" — "Cheap fixes, better research quality"
    - "Both Sonnet" — "Higher quality across the board"
    - "Both Opus" — "Maximum quality for everything"
```

Mark the current selection with "(current)" in its label. Always list the current selection as the first option.

## Step 3: Apply Changes

Parse the 4 answers and map to config values:

- Question 1 → `models.planning`
- Question 2 → `models.execution`
- Question 3 → `models.review`
- Question 4 → `models.simple` + `models.research`:
  - "Both Haiku" → simple: haiku, research: haiku
  - "Haiku fixes, Sonnet research" → simple: haiku, research: sonnet
  - "Both Sonnet" → simple: sonnet, research: sonnet
  - "Both Opus" → simple: opus, research: opus

If any "Other" was selected, parse the custom text for a valid model name.

## Step 4: Write Config

Update `.maestro/config.yaml` with the new model assignments. If no `models` section exists, create one. Preserve all other config sections.

## Step 5: Show Summary

Only show what changed:

```
[maestro] Models updated:

  planning    opus           (unchanged)
  execution   sonnet -> opus
  review      opus           (unchanged)
  simple      haiku -> sonnet
  research    sonnet -> opus
```

If nothing changed:

```
[maestro] No changes made.
```

## Presets

If the user runs `/maestro model` and types "preset" or "budget" or "quality" or "max" as Other input, apply a preset directly:

| Preset | planning | execution | review | simple | research |
|--------|----------|-----------|--------|--------|----------|
| budget | haiku | sonnet | haiku | haiku | haiku |
| balanced | opus | sonnet | opus | haiku | sonnet |
| quality | opus | sonnet | opus | sonnet | opus |
| max | opus | opus | opus | opus | opus |

Show confirmation and the full mapping after applying.

---

## Preset Argument — Direct Application

If `$ARGUMENTS` exactly matches a preset name (`budget`, `balanced`, `quality`, `max`), skip the interactive form entirely and apply the preset directly:

1. Read `.maestro/config.yaml`. If it does not exist, show "Not initialized" and stop.
2. Apply the preset's model mapping to the `models` section.
3. Write the updated config.
4. Show confirmation:

```
[maestro] Preset applied: quality

  planning    opus
  execution   sonnet
  review      opus
  simple      sonnet
  research    opus
```

If the preset name is unrecognized (not one of the four valid presets and not empty), show:

```
[maestro] Unknown preset: "<arg>"

  Valid presets: budget, balanced, quality, max
  Run /maestro model to use the interactive form.
```

## Error Handling

| Condition | Action |
|-----------|--------|
| `.maestro/config.yaml` missing | Show "Not initialized" and stop |
| `models` section missing from config | Use defaults (shown in Step 1); note "(default)" labels |
| Config write fails | Show `(x) Cannot write config: <reason>`. Do not leave a partial write. |
| AskUserQuestion returns an unexpected option | Treat as "no change" for that question and proceed |
| Unknown model name in "Other" free-form input | Show `(x) Unknown model: "<value>". Valid models: haiku, sonnet, opus.` and re-prompt |

## Config Section Format

The `models` section written to `.maestro/config.yaml`:

```yaml
models:
  planning: opus
  execution: sonnet
  review: opus
  simple: haiku
  research: sonnet
```

When writing, preserve all other keys in the file. Only update the fields that changed. If the `models` key does not exist, insert it after the top-level `default_mode` key (or at the end of the file if that key is not present).

## Model Pricing Reference

Include pricing in the display so users can make cost-informed choices:

| Model | Input (per M tokens) | Output (per M tokens) |
|-------|----------------------|-----------------------|
| Haiku | $0.80 | $4.00 |
| Sonnet | $3.00 | $15.00 |
| Opus | $15.00 | $75.00 |

Cost estimates per story (shown during execution model selection):
- Haiku execution: ~$0.07/story
- Sonnet execution: ~$0.27/story
- Opus execution: ~$1.35/story

These are approximate and depend on story complexity and context size.

## Examples

### Example 1: Apply a preset directly

```
/maestro model budget
```

```
[maestro] Preset applied: budget

  planning    haiku
  execution   sonnet
  review      haiku
  simple      haiku
  research    haiku
```

### Example 2: Interactive — view current assignments

```
/maestro model
```

```
+---------------------------------------------+
| Model Assignments                           |
+---------------------------------------------+
  planning   opus    |  execution  sonnet
  review     opus    |  simple     haiku
  research   sonnet  |

  Haiku $0.80/$4  Sonnet $3/$15  Opus $15/$75

[interactive form opens with 4 questions]
```

### Example 3: Apply changes with summary

After the interactive form, if execution was changed from sonnet to opus:

```
[maestro] Models updated:

  planning    opus           (unchanged)
  execution   sonnet -> opus
  review      opus           (unchanged)
  simple      haiku          (unchanged)
  research    sonnet         (unchanged)
```

### Example 4: Unknown preset

```
/maestro model turbo
```

```
[maestro] Unknown preset: "turbo"

  Valid presets: budget, balanced, quality, max
  Run /maestro model to use the interactive form.
```
