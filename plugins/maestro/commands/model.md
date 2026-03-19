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
