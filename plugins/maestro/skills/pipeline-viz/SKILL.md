---
name: pipeline-viz
description: "Render dev-loop phases as an animated vertical pipeline in the terminal. Each phase shows a status icon, ANSI color, elapsed time, and a short annotation. Updates in-place using cursor movement. Integrates as a panel in the dashboard skill."
---

# Pipeline Visualizer

Renders the seven dev-loop phases as a live vertical pipeline in the terminal. Updates each phase line in-place as execution progresses — no scrolling output, no log noise. Designed to give the user a single-glance view of where a story stands.

## Example Output

```
  ✓ VALIDATE     dependencies met
  ✓ DELEGATE     sonnet, 3.4K context
  ◐ IMPLEMENT    agent working... (45s)
  · SELF-HEAL    pending
  · QA REVIEW    pending
  · GIT CRAFT    pending
  · CHECKPOINT   pending
```

Failed phase:

```
  ✓ VALIDATE     dependencies met
  ✓ DELEGATE     sonnet, 3.4K context
  ✓ IMPLEMENT    DONE (first attempt, 28.1K tokens)
  ✗ SELF-HEAL    tsc: 2 errors in src/api/route.ts
  · QA REVIEW    pending
  · GIT CRAFT    pending
  · CHECKPOINT   pending
```

## Phase Definitions

The pipeline always contains exactly these seven phases in this order:

| # | Name | Icon when active | Done icon | Failed icon |
|---|------|-----------------|-----------|-------------|
| 1 | VALIDATE   | `◐` | `✓` | `✗` |
| 2 | DELEGATE   | `◐` | `✓` | `✗` |
| 3 | IMPLEMENT  | `◐` | `✓` | `✗` |
| 4 | SELF-HEAL  | `◐` | `✓` | `✗` |
| 5 | QA REVIEW  | `◐` | `✓` | `✗` |
| 6 | GIT CRAFT  | `◐` | `✓` | `✗` |
| 7 | CHECKPOINT | `◐` | `✓` | `✗` |

When Unicode is unavailable (see Terminal Compatibility), fall back to: active `>`, done `+`, failed `!`, pending `.`.

## ANSI Colors

| State | Color | ANSI code |
|-------|-------|-----------|
| done | green | `\033[32m` |
| active | yellow | `\033[33m` |
| pending | dim (dark gray) | `\033[2m` |
| failed | red | `\033[31m` |
| reset | — | `\033[0m` |

Apply color to both the icon and the phase name. The annotation (right of the phase name) is always rendered in dim white (`\033[2m`) regardless of state.

## Annotations

Each phase line has a short annotation — the text shown to the right of the phase name. Annotations are always dim, max 40 characters. Longer strings are truncated with `...`.

| Phase | Pending | Active | Done | Failed |
|-------|---------|--------|------|--------|
| VALIDATE | `pending` | `checking prerequisites...` | `dependencies met` | `[reason, e.g. "missing M1-S1"]` |
| DELEGATE | `pending` | `building context...` | `[model], [N]K context` | `[reason]` |
| IMPLEMENT | `pending` | `agent working... ([elapsed])` | `[status], [tokens] tokens` | `[status]` |
| SELF-HEAL | `pending` | `running checks...` | `all checks passed` | `[tool]: [short error]` |
| QA REVIEW | `pending` | `reviewing... ([elapsed])` | `APPROVED, [N] findings` | `REJECTED, [N] findings` |
| GIT CRAFT | `pending` | `committing...` | `[commit type](scope): ...` | `[reason]` |
| CHECKPOINT | `pending` | `waiting for user...` | `continued` | `aborted` |

For IMPLEMENT active state, elapsed is shown as a running clock (e.g., `45s`, `2m 14s`). Elapsed is omitted when under 5 seconds to avoid flicker.

## In-Place Updates

Use ANSI cursor movement to overwrite the previous pipeline render rather than printing new lines.

### Initial Render

When the pipeline is first shown, print all seven lines and record the cursor row:

```
\033[2m  · VALIDATE     pending\033[0m
\033[2m  · DELEGATE     pending\033[0m
\033[2m  · IMPLEMENT    pending\033[0m
\033[2m  · SELF-HEAL    pending\033[0m
\033[2m  · QA REVIEW    pending\033[0m
\033[2m  · GIT CRAFT    pending\033[0m
\033[2m  · CHECKPOINT   pending\033[0m
```

### Subsequent Updates

To update a single phase line (e.g., phase 3):

1. Move cursor up `(7 - phase_index)` lines: `\033[{N}A`
2. Clear the line: `\033[2K`
3. Print the updated line
4. Move cursor back down: `\033[{N}B`

To redraw the entire pipeline (e.g., after a terminal resize), move up 7 lines and reprint all.

### Cursor Discipline

After the pipeline, always leave the cursor on a new line below the block. Never print text after the pipeline without a `\n` — this prevents overwrite collisions with other output.

## Story Header

When rendering inside the dev-loop, print a one-line story header immediately above the pipeline:

```
  Story 3/7 — 03-frontend-ui
```

The story header is not part of the pipeline block and is NOT updated in-place. It is printed once per story and stays in the scroll buffer.

## Compact Mode

Compact mode collapses the pipeline to a single summary line. Activate when:

- Terminal width < 60 columns (`$COLUMNS < 60`)
- Explicitly configured via `pipeline_viz.compact: true` in `.maestro/config.yaml`

Compact format:

```
  [✓✓◐····]  IMPLEMENT  agent working... (45s)
```

- The bracket block shows all 7 phase icons in order
- The center label shows the active (or last-active) phase name
- The right side shows the active annotation

Compact mode still updates in-place — one line rather than seven.

## Terminal Compatibility

Check terminal capabilities before rendering:

1. **Unicode support**: Check `$LANG` contains `UTF-8` or `$TERM` is not `dumb`. If not, use ASCII fallback icons (`+`, `!`, `.`, `>`).
2. **Color support**: Check `$TERM != dumb` and `$NO_COLOR` is unset. If color is disabled, render without ANSI codes.
3. **Cursor movement**: Required for in-place updates. If `$TERM == dumb` or output is piped (`[ -t 1 ]` is false), fall back to append-only mode (print a new snapshot on each state change instead of overwriting).

Detect pipe output:

```bash
if [ ! -t 1 ]; then
  PIPELINE_VIZ_MODE=append
fi
```

In append mode, prefix each snapshot with a timestamp:

```
[10:42:15]  ✓ VALIDATE   ✓ DELEGATE   ◐ IMPLEMENT(45s)  · · · ·
```

## Integration with Dashboard Skill

The pipeline can render as one panel within the dashboard layout.

When used inside the dashboard:

- The pipeline block is rendered within the dashboard's box borders
- The story header line is replaced by the dashboard's milestone/story header
- In-place cursor updates apply within the bounded panel area
- Compact mode is forced when dashboard panel width < 40 columns

Integration call from `dev-loop/SKILL.md` during Phase 3 (IMPLEMENT active):

```
pipeline_viz.update(phase="IMPLEMENT", state="active", annotation="agent working...")
```

States flow one-way: `pending` → `active` → `done | failed`. A phase cannot revert from done to active.

## Configuration

Read from `.maestro/config.yaml`:

```yaml
pipeline_viz:
  enabled: true          # show pipeline during dev-loop (default: true)
  compact: false         # force compact mode (default: auto-detect from terminal width)
  unicode: auto          # auto | true | false — controls icon set
  colors: auto           # auto | true | false — controls ANSI color output
  elapsed_threshold: 5   # seconds before elapsed clock appears in active annotation
```

If `pipeline_viz.enabled` is `false`, the visualizer produces no output. The dev-loop proceeds silently (or with the dashboard's own display, if enabled).

## Output Contract

The pipeline visualizer writes nothing to disk. It is a pure display component.

```yaml
output_contract:
  writes: none
  reads:
    - .maestro/state.local.md   # for current phase and story metadata
    - .maestro/config.yaml      # for display configuration
  side_effects: terminal output only (ANSI escape sequences + cursor movement)
```

## Integration Points

- **dev-loop/SKILL.md** — calls `pipeline_viz.update()` at each phase transition
- **dashboard/SKILL.md** — embeds the pipeline as a vertical panel alongside the story progress bar
- **self-correct/SKILL.md** — signals SELF-HEAL phase state (active during fix attempts, failed after 3 retries)
