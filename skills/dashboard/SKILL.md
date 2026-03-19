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

---

## Opus Progress Display

When a Magnum Opus session is active, the dashboard renders an enhanced progress box that surfaces wave-level, milestone-level, and story-level state simultaneously.

### When to Show

- After each story completes inside `opus-loop` (replaces the standard story-completion render)
- When the user runs `/maestro status` during an active Opus session
- At milestone boundaries — both before (upcoming milestone header) and after (milestone summary)
- In Cowork or Dispatch mode, substitute the compact single-line format instead of the full box

### Full Progress Box (Terminal Mode)

Rendered when `unicode_box: true` or `unicode_box: auto` and the terminal is detected as UTF-8 capable.

```
╔══════════════════════════════════════════════════════╗
║  MAGNUM OPUS — [Wave Name]                           ║
╠══════════════════════════════════════════════════════╣
║  Milestone [N]/[M]: [milestone name]                 ║
║  Story [N]/[M]: [story name]                         ║
║  Phase: [VALIDATE|DELEGATE|IMPLEMENT|QA|GIT|CHECK]   ║
║  ████████░░░░░░░░░░ [N]% complete                    ║
╠──────────────────────────────────────────────────────╣
║  Stories: ✓✓✓▶○○ ([done] done, [remaining] left)    ║
║  Cost: ~$[spent] spent | ~$[remaining] remaining     ║
║  Time: [elapsed] elapsed | ~[eta] ETA               ║
║  QA Pass Rate: [rate]% ([passed]/[total] first-pass) ║
╚══════════════════════════════════════════════════════╝
```

Box width: 54 characters (inner content: 52). The double-rule separator (`╠══╣`) divides the identity/phase section from the metrics section. The thin-rule separator (`╠──╣`) is used only inside the metrics section when a sub-section break aids readability.

Fall back to ASCII (`+`, `-`, `|`) when `unicode_box: false` or when the terminal cannot be confirmed as UTF-8.

### Story Status Indicators

Each completed, active, or pending story within the current milestone is represented by a single character in the Stories line:

| Character | Meaning |
|-----------|---------|
| `✓` | Completed and passed QA |
| `✗` | Failed QA — scheduled for retry |
| `▶` | Currently executing |
| `○` | Pending (not yet started) |

Indicators are rendered left-to-right in story order. When the milestone has more than 20 stories, truncate the indicator string to 19 characters and append `…` to signal overflow.

### Progress Bar

```
████████░░░░░░░░░░░░ 40% complete
```

- Width: 20 characters total
- Filled segment: `█` — `filled = round(pct / 100 * 20)`
- Empty segment: `░` — `empty = 20 - filled`
- Percentage: `(completed_stories / total_stories) × 100`, rounded to nearest integer
- Label: `[N]% complete` where N is the rounded percentage
- Counts are shown on the Story line, not on the bar line itself

### Phase Field

Display the current phase of the story-in-progress using the canonical phase names from the dev-loop:

```
VALIDATE | DELEGATE | IMPLEMENT | QA | GIT | CHECK
```

When rendering at a milestone boundary rather than mid-story, display `Milestone complete` (after) or `Milestone [N] starting` (before).

### Metrics Section

#### Cost Display

Read all cost data from `.maestro/logs/costs.jsonl` (same source as the standard dashboard). Do not re-derive costs independently.

- **Spent**: sum of all story costs recorded since the Opus session started
- **Remaining**: `avg_cost_per_story × remaining_stories`, where `avg_cost_per_story = total_spent / completed_stories`
- If no stories are completed yet, display `remaining: estimating...`
- Format: `~$X.XX spent | ~$X.XX remaining`
- Round all dollar amounts to two decimal places

#### Time / ETA Display

- **Elapsed**: wall-clock time since the Opus session started, formatted as `Xh Ym` (omit hours if under 60 min, e.g. `14m`)
- **ETA**: `avg_time_per_story × remaining_stories`
  - `avg_time = total_elapsed / completed_stories`
  - Format result as `~Xh Ym` or `~Ym`
  - If no stories completed yet: `~estimating`
  - If all stories done: display `complete` for both fields
- Format: `[elapsed] elapsed | ~[eta] ETA`

#### QA Pass Rate

- **Rate**: `first_pass_count / total_qa_reviews × 100`, rounded to nearest integer
- **First-pass**: a story passes on its first QA dispatch with no rework loop triggered
- Format: `[rate]% ([passed]/[total] first-pass)`
- If fewer than 2 stories have completed QA, display `n/a (insufficient data)` for the rate

### Compact Format (Cowork / Dispatch Mode)

When Maestro is operating in Cowork or Dispatch mode, the full box is suppressed to avoid overwhelming conversation context. Instead, emit a single line after each story completion:

```
**Maestro** | M[N]/[M] S[N]/[M] | [PHASE] | $[spent] | [elapsed]
```

Example:

```
**Maestro** | M2/5 S3/8 | IMPLEMENT | $6.40 | 42m
```

Fields:
- `M[N]/[M]` — current milestone number / total milestones
- `S[N]/[M]` — current story number within the milestone / total stories in milestone
- `[PHASE]` — current dev-loop phase (abbreviated, uppercase)
- `$[spent]` — total spent so far, no decimals if under $10 (`$6` not `$6.00`), two decimals otherwise
- `[elapsed]` — session wall-clock time (`14m` or `1h 6m`)

### Trigger Points in Opus Loop

The following events in `opus-loop` trigger a dashboard render:

| Event | Format |
|-------|--------|
| Story delegation sent | Compact (Cowork) or none (Terminal) |
| Story CHECKPOINT complete | Full box (Terminal) or Compact (Cowork) |
| Milestone all-stories complete | Full box with `Milestone complete` phase |
| `/maestro status` command | Full box regardless of mode |
| Wave complete | Full box with summary totals, all stories `✓` or `✗` |

### Data Sources for Opus Fields

| Field | Source |
|-------|--------|
| Wave name | `.maestro/state.local.md` — `opusWaveName` |
| Milestone N/M | `.maestro/state.local.md` — `currentMilestone`, `totalMilestones` |
| Story N/M | `.maestro/state.local.md` — `storiesCompleted`, `storiesTotal` (within milestone) |
| Story indicators | `.maestro/state.local.md` — `storyStatuses[]` array |
| Current phase | Dev-loop phase tracker in state |
| Cost (spent) | `.maestro/logs/costs.jsonl` — session aggregate |
| Cost (remaining) | Derived: `avg × remaining` |
| Elapsed time | Session start timestamp in `.maestro/state.local.md` — `opusSessionStart` |
| QA pass rate | `.maestro/state.local.md` — `qaFirstPassCount`, `qaTotalReviews` |

### Configuration

The existing `dashboard` config block in `.maestro/config.yaml` governs Opus display as well. No new keys are required. The `unicode_box` setting controls whether the full Unicode box or the ASCII fallback is used for the Opus progress box.

```yaml
dashboard:
  enabled: true           # also controls Opus progress display
  milestone_only: false   # if true, suppress per-story renders inside opus-loop
  unicode_box: auto       # auto | true | false
```

### Integration Points

- **opus-loop/SKILL.md** — calls dashboard render at each story CHECKPOINT and at each milestone boundary
- **dev-loop/SKILL.md** — unchanged; continues to call the standard dashboard render outside Opus sessions
- **token-ledger/SKILL.md** — session start timestamp used for elapsed-time calculation; read `opusSessionStart` field
- **cowork/SKILL.md** — signals compact-format mode; dashboard checks active mode before choosing render path
