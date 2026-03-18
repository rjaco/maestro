---
name: output-format
description: "Maestro output formatting standard. Referenced by all commands and skills for consistent, readable terminal output."
---

# Output Format Standard

All Maestro commands and skills MUST follow these formatting conventions for consistent, readable output.

## Prefix

All Maestro messages start with the `[maestro]` prefix:

```
[maestro] Message text here
```

## Section Boxes

Use box-drawing characters for major status blocks. Inner width is 47 characters:

```
+---------------------------------------------+
| Section Title                               |
+---------------------------------------------+
  Key          Value
  Key          Value
```

## Status Indicators

Use text-based indicators (never emoji):

| Indicator | Meaning | Example |
|-----------|---------|---------|
| `(ok)` | Pass/success | `(ok) Tests passing` |
| `(!)` | Warning | `(!) Stale session detected` |
| `(x)` | Error/failure | `(x) Config file missing` |
| `(i)` | Informational | `(i) First run detected` |
| `--` | Neutral/separator | `-- 3 stories remaining` |

## User Decisions

Always use numbered options. Never use bullet points for decisions:

```
  [1] Continue to next story
  [2] Review changes before continuing
  [3] Change mode for remaining stories
  [4] Abort execution
```

## Progress Indicators

### Phase Progress (dev-loop)

Show all phases on one line. Active phase in CAPS with brackets:

```
  validate > delegate > [IMPLEMENT] > self-heal > qa > git > checkpoint
```

Completed phases are lowercase. Upcoming phases are lowercase. Active phase is `[UPPERCASE]`.

### Story Progress Bar

ASCII progress bar with count:

```
  [======>       ] 4/10 stories
```

Width: 16 characters between brackets. `=` for completed. `>` for current position. Spaces for remaining.

### One-Line Status

Between phases, show a compact one-liner:

```
[maestro] Story 3/7: API Routes | [IMPLEMENT] | 2m 14s | ~12K tokens
```

## Data Tables

Use 2-space indent with aligned columns:

```
  Task Type     Model      Used For
  ----------    -------    ----------------------------------------
  planning      opus       Decomposition, architecture, roadmaps
  execution     sonnet     Story implementation, code writing
```

## Story Checkpoint Summary (checkpoint mode)

```
+---------------------------------------------+
| Story 3/7 complete: API Routes              |
+---------------------------------------------+
  Phase     QA approved (first attempt)
  Files     4 created, 2 modified
  Tests     8 new, all passing
  Commit    feat(api): add user routes
  Tokens    34,200 (story) / 127,800 (total)
  Time      2m 14s (story) / 8m 41s (total)

  [1] Continue to next story
  [2] Review changes (git diff)
  [3] Change mode for remaining stories
  [4] Abort execution
```

## Feature Completion Summary

```
+---------------------------------------------+
| Feature complete                            |
+---------------------------------------------+
  Feature   Add user authentication
  Stories   5 completed, 0 skipped
  QA rate   80% first-pass
  Tokens    ~187K
  Cost      ~$4.20
  Time      14m 32s
  Commits   5

  Trust     Apprentice (12 stories, 75% QA rate)

  [1] Ship (create PR)
  [2] Review all changes
  [3] Run final verification
```

## Error Display (at PAUSE)

```
+---------------------------------------------+
| Paused: self-heal failed (3/3 attempts)     |
+---------------------------------------------+
  Error     TypeError: Cannot read property 'id' of undefined
  File      src/routes/users.ts:47

  Attempted fixes:
    1. Added null check — still failing
    2. Changed query to include relation — still failing
    3. Added default value — still failing

  Suggested action:
    Check that the User model includes the 'profile' relation
    in the Prisma schema.

  [1] I fixed it manually, continue
  [2] Skip this story
  [3] Abort execution
```

## Forecast Display

```
+---------------------------------------------+
| Forecast                                    |
+---------------------------------------------+
  Stories    ~5 (2 backend, 2 frontend, 1 test)
  Tokens     ~145K
  Cost       ~$3.20
  Models     70% Sonnet / 30% Opus
  Mode       checkpoint

  (i) Tip: --yolo saves ~15% tokens

  Proceed? [Y/n]
```

## Integration Status (in doctor/status)

```
  Integrations:
    (ok) Playwright      available
    (ok) GitHub CLI       v2.45.0
    (x)  Asana           not detected
    (x)  Linear          not detected
    (ok) Obsidian CLI    v1.12.3
    (x)  Notion MCP      not detected
```

## Rules

1. Never use emoji in output. Text indicators only.
2. Always use 2-space indent for content within sections.
3. Box width is consistent at 47 inner characters.
4. Numbered options for ALL user decisions.
5. One blank line between sections, no blank lines within sections.
6. Keep lines under 60 characters when possible for terminal readability.
7. Use `[maestro]` prefix for standalone messages, boxes for structured data.
