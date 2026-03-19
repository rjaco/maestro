---
name: dashboard
description: "Display the real-time terminal dashboard showing milestone progress, story count, current phase, token spend by model, QA pass rate, and ETA"
argument-hint: ""
allowed-tools:
  - Read
  - Glob
---

# Maestro Dashboard

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
██████╗  █████╗ ███████╗██╗  ██╗██████╗  ██████╗  █████╗ ██████╗ ██████╗
██╔══██╗██╔══██╗██╔════╝██║  ██║██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔══██╗
██║  ██║███████║███████╗███████║██████╔╝██║   ██║███████║██████╔╝██║  ██║
██║  ██║██╔══██║╚════██║██╔══██║██╔══██╗██║   ██║██╔══██║██╔══██╗██║  ██║
██████╔╝██║  ██║███████║██║  ██║██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝
```

Renders the current session progress dashboard. Read-only display showing milestone and story progress, current phase, token spend by model, QA pass rate, and estimated time remaining.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

Read `.maestro/state.local.md`. If it does not exist or is empty:

```
[maestro] No active session found.

  Start a session with /maestro or /maestro plan to begin tracking progress.
```

## Step 2: Collect Data

Read all data sources before rendering. This skill writes nothing to disk.

| Field | Source |
|-------|--------|
| Milestone progress | `.maestro/state.local.md` — `currentMilestone`, `totalMilestones`, milestone name |
| Story progress | `.maestro/state.local.md` — `storiesCompleted`, `storiesTotal` |
| Current phase | `.maestro/state.local.md` — dev-loop phase tracker |
| Spend by model | `.maestro/logs/costs.jsonl` — aggregate per model since session start |
| QA pass rate | `.maestro/state.local.md` — QA first-pass vs. total QA review counts |
| Story timings | `.maestro/state.local.md` — timestamps for completed stories |

Read `.maestro/config.yaml` for dashboard settings:

```yaml
dashboard:
  enabled: true
  milestone_only: false
  unicode_box: auto    # auto | true | false
```

Determine box character set:
- If `unicode_box: true`, use `╔`, `═`, `╗`, `║`, `╚`, `╝`
- If `unicode_box: false`, use `+`, `-`, `|`
- If `unicode_box: auto`, check `$LANG` or `$TERM` for UTF-8 support — use Unicode if confirmed, ASCII otherwise
- Default to ASCII if uncertain to avoid broken rendering on minimal terminals

## Step 3: Render the Dashboard

### Standard view (per-story render)

```
+--------------------------------------------------+
| Maestro — Milestone <M>/<T>: <Milestone Name>    |
+--------------------------------------------------+
| Stories   <progress bar> <completed>/<total> (<pct>%)  |
| Phase     <current phase>                        |
| Spend     ~$<total> (<model>: $<amt>, ...)       |
| QA Rate   <N>% first-pass                        |
| ETA       ~<N> min remaining                     |
+--------------------------------------------------+
```

### Milestone complete view

When all stories in the current milestone are done (`storiesCompleted == storiesTotal`):

```
+--------------------------------------------------+
| Maestro — Milestone <M>/<T>: <Milestone Name>    |
+--------------------------------------------------+
| Stories   ████████████████ <total>/<total> (100%) |
| Phase     Milestone complete                      |
| Spend     ~$<session> session (~$<total> total)   |
|            <model>: $<amt>, <model>: $<amt>       |
| QA Rate   <N>% first-pass (<pass>/<total> stories)|
| ETA       complete                                |
+--------------------------------------------------+
```

### Progress bar rules

- Total width: 16 characters
- Filled character: `█`
- Empty character: `░`
- Formula: `filled = round(percentage / 100 * 16)`
- Always follow with count and percentage: `<completed>/<total> (<pct>%)`

Examples:
- 0/6 (0%):   `░░░░░░░░░░░░░░░░`
- 2/6 (33%):  `█████░░░░░░░░░░░`
- 4/6 (67%):  `██████████░░░░░░`
- 6/6 (100%): `████████████████`

### Spend line rules

Read `.maestro/logs/costs.jsonl`. Aggregate spend per model across all entries since session start. Do not re-calculate independently — use only what is in `costs.jsonl`.

Format: `~$X.XX (<model>: $X.XX, <model>: $X.XX, ...)`

- Round total and per-model values to 2 decimal places
- Only include models with nonzero spend
- If the spend string exceeds the box width (50 chars), wrap to the next line with 4-space indent
- If `costs.jsonl` is absent or empty, display `~$0.00 (no spend recorded)`

### QA rate rules

- Count stories where QA passed on the first dispatch (no rework loop triggered)
- Formula: `round(first_pass_count / total_qa_reviews * 100)`
- Display: `<N>% first-pass`
- At milestone complete view, also show raw counts: `<N>% first-pass (<pass>/<total> stories)`
- If fewer than 2 stories have completed QA, display: `n/a (insufficient data)`

### ETA rules

- Compute average seconds per story from completed stories this session
- ETA = `ceil(avg_seconds_per_story * remaining_stories / 60)` minutes
- Display: `~<N> min remaining`
- If no completed stories yet: `estimating...`
- If all stories are done: `complete`

## Step 4: Handle Edge Cases

### No milestones defined

```
+--------------------------------------------------+
| Maestro — No active milestone                    |
+--------------------------------------------------+
| Stories   ░░░░░░░░░░░░░░░░ 0/0 (0%)              |
| Phase     Idle                                   |
| Spend     ~$0.00 (no spend recorded)             |
| QA Rate   n/a (insufficient data)                |
| ETA       estimating...                          |
+--------------------------------------------------+

  (i) Start a new session with /maestro or /maestro plan
```

### Config disables dashboard

If `dashboard.enabled` is `false`, the dashboard is suppressed during automated runs. However, an explicit `/maestro dashboard` command always renders it regardless of config.

### Missing state fields

If any field is absent from `state.local.md`, render it as `--` rather than crashing.

## Data Contract

This command is read-only. It reads from:
- `.maestro/config.yaml`
- `.maestro/state.local.md`
- `.maestro/logs/costs.jsonl`

It writes nothing. All persistent state is owned by dev-loop, checkpoint, and cost-dashboard skills.

## Integration Notes

The dashboard is also rendered automatically by other skills — you do not need to run it manually during a dev-loop session:

- **dev-loop/SKILL.md** — renders after every CHECKPOINT phase
- **checkpoint/SKILL.md** — renders at each milestone boundary with the milestone complete view
- **cost-dashboard/SKILL.md** — provides the per-model cost data read from `costs.jsonl`
- **token-ledger/SKILL.md** — secondary source for session totals when `costs.jsonl` is unavailable
