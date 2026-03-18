---
name: dashboard
description: "Real-time terminal dashboard showing milestone and story progress, current phase, token spend by model, QA pass rate, and ETA. Renders after each story completion and milestone checkpoint using box-drawing characters."
---

# Dashboard

Renders a polished terminal progress display after each story completes and at each milestone checkpoint. Gives the user a live picture of where the run stands without requiring a manual status command.

## When to Render

- After every story's CHECKPOINT phase completes
- After every milestone checkpoint (all stories in a milestone done)
- When the user runs `/maestro dashboard` or `/maestro status --dashboard`
- Never during IMPLEMENT or QA REVIEW — do not interrupt an agent mid-run

## Data Sources

| Field | Source |
|-------|--------|
| Milestone progress | `.maestro/state.local.md` — `currentMilestone`, `totalMilestones` |
| Story progress | `.maestro/state.local.md` — `storiesCompleted`, `storiesTotal` |
| Current phase | Dev-loop phase tracker in state |
| Spend by model | `.maestro/logs/costs.jsonl` — aggregate per model since session start |
| QA pass rate | Count stories where QA passed on first attempt vs. total QA reviews |
| ETA | Estimated from average story duration × remaining stories |

All cost data is read from `costs.jsonl` (see `skills/cost-dashboard/SKILL.md`). Do not re-calculate costs independently — aggregate from that file.

## Dashboard Format

```
+--------------------------------------------------+
| Maestro — Milestone 3/7: Core Features           |
+--------------------------------------------------+
| Stories   ████████░░░░░░░░ 4/6 (67%)             |
| Phase     QA Review                               |
| Spend     ~$4.80 (haiku: $0.40, sonnet: $3.20,   |
|            opus: $1.20)                            |
| QA Rate   83% first-pass                          |
| ETA       ~12 min remaining                       |
+--------------------------------------------------+
```

### Box-Drawing Rules

Use `+`, `-`, `|` for maximum terminal compatibility (not Unicode box-drawing). Reserve Unicode (`╔`, `═`, `╗`) only when the terminal is known to support UTF-8 (check `$LANG` or `$TERM`).

Default to ASCII box characters to avoid broken rendering on minimal terminals.

### Progress Bar

- Total width: 16 characters
- Filled: `█` — proportional to percentage complete
- Empty: `░`
- Formula: `filled = round(percentage / 100 * 16)`
- Always show count and percentage after the bar: `4/6 (67%)`

### Spend Line

Format: `~$X.XX (haiku: $X.XX, sonnet: $X.XX, opus: $X.XX)`

Wrap to the next indented line if the spend string exceeds the box width (50 chars).

Only include models that have nonzero spend. If only sonnet was used: `~$3.20 (sonnet: $3.20)`.

### QA Rate

- Count stories where QA passed on the first QA dispatch (no rework loop triggered).
- Formula: `first_pass_count / total_qa_reviews * 100`, rounded to the nearest whole number.
- Display as `N% first-pass`.
- If fewer than 2 stories have been reviewed, display `n/a (insufficient data)`.

### ETA

- Compute average seconds per story from completed stories in this session.
- ETA = `avg_seconds_per_story × remaining_stories`.
- Display as `~N min remaining` (round up to nearest minute).
- If no completed stories yet, display `estimating...`.
- If all stories are done, display `complete`.

## Milestone vs. Story View

When rendering after a **story completion**, show the current milestone's story bar and the story's phase as the last completed phase.

When rendering at a **milestone checkpoint** (all stories done), change the Phase line to `Milestone complete` and expand the spend line to show the full milestone total alongside the session total:

```
+--------------------------------------------------+
| Maestro — Milestone 3/7: Core Features           |
+--------------------------------------------------+
| Stories   ████████████████ 6/6 (100%)            |
| Phase     Milestone complete                      |
| Spend     ~$4.80 session (~$14.20 total)         |
|            haiku: $0.40, sonnet: $3.20, opus: $1.20|
| QA Rate   83% first-pass (5/6 stories)           |
| ETA       complete                                |
+--------------------------------------------------+
```

## Configuration

Read from `.maestro/config.yaml`:

```yaml
dashboard:
  enabled: true           # render after each story (default: true)
  milestone_only: false   # render only at milestone checkpoints, not each story
  unicode_box: auto       # auto | true | false — controls box character set
```

If `dashboard.enabled` is `false`, only render on explicit user command.

`milestone_only: true` suppresses per-story renders — useful for large milestones where frequent output is noisy.

## Integration Points

- **dev-loop/SKILL.md** — calls dashboard render at CHECKPOINT phase
- **checkpoint/SKILL.md** — calls dashboard render at milestone boundary
- **cost-dashboard/SKILL.md** — provides per-model cost aggregates; dashboard reads from `costs.jsonl`, not from cost-dashboard's own rendered output
- **token-ledger/SKILL.md** — secondary source for session totals when `costs.jsonl` is unavailable

## Output Contract

The dashboard writes nothing to disk. It is a read-only display. All state it reads is owned by other skills.

```yaml
output_contract:
  writes: none
  reads:
    - .maestro/state.local.md
    - .maestro/logs/costs.jsonl
  side_effects: terminal output only
```
