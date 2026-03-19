---
name: status
description: "View Maestro session progress and manage lifecycle — resume, pause, or abort a session"
argument-hint: "[resume|abort|pause|--detail|--verbose|--tokens|--qa|--cost]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Maestro Status — Progress, Resume, Abort, Pause

## Usage

```
/maestro status [resume|abort|pause|--detail|--verbose|--tokens|--qa|--cost]
```

## Flags

| Subcommand / Flag | Description |
|-------------------|-------------|
| _(none)_ | Show compact 6-line status view with interactive action menu |
| `--detail` / `--verbose` | Show full 11-section status (current behavior before this change) |
| `--tokens` | Show token breakdown per model |
| `--qa` | Show QA iteration history per story |
| `--cost` | Show cost breakdown per story |
| `resume` | Resume a paused session from its last saved position |
| `abort` | End the session (committed work is preserved) |
| `pause` | Pause a running session for later resumption |

## Examples

```
/maestro status
/maestro status --detail
/maestro status --tokens
/maestro status --qa
/maestro status --cost
/maestro status resume
/maestro status pause
/maestro status abort
```

## See Also

- `/maestro board` — Visual kanban view of story progress
- `/maestro` — Start a new session

You manage the lifecycle of a Maestro session: view progress, resume paused work, abort a session, or pause a running one.

## Step 1: Read Session State

Read `.maestro/state.local.md`.

If the file does not exist or cannot be read:

```
No active Maestro session.

To start a new session:
  /maestro "describe your feature here"

To initialize Maestro for this project:
  /maestro init
```

Stop here.

## Step 2: Parse State

Extract all fields from the YAML frontmatter of `.maestro/state.local.md`:

- `active` — whether a session is running
- `feature` — the feature being built
- `mode` — yolo, checkpoint, or careful
- `layer` — execution or opus
- `current_story` / `total_stories` — progress
- `current_milestone` / `total_milestones` — opus milestone progress
- `phase` — current phase (validate, delegate, implement, self_heal, qa_review, git_craft, checkpoint, paused, completed, aborted, decompose, research)
- `qa_iteration` / `max_qa_iterations`
- `self_heal_iteration` / `max_self_heal`
- `started_at` / `last_updated` — timestamps
- `token_spend` / `estimated_remaining`
- `cost_actual` / `cost_projected` — dollar cost figures
- `session_id`
- `model_override`

If `layer` is `opus`, also extract:
- `opus_mode` — full_auto, milestone_pause, budget_cap, time_cap, until_pause
- `milestones` — status map of all milestones
- `token_budget` / `time_budget_hours`
- `fix_cycle` / `max_fix_cycles`
- `consecutive_failures` / `max_consecutive_failures`

## Step 3: Handle Subcommands

Check `$ARGUMENTS` for a subcommand or flag.

---

### No arguments — show COMPACT status (default)

Read `.maestro/trust.yaml` for trust metrics.

Calculate time elapsed from `started_at` to now (format as `Xh Ym Zs` or `Xm Zs` if under 1 hour).

Build the phase line: map current `phase` to its display name using the output-format phase mapping, show it in `[CAPS]`, all others lowercase.

Phase sequence to display:
```
validate > delegate > [IMPLEMENT] > self-heal > qa > git > checkpoint
```

For Magnum Opus sessions, also show:
```
milestone > executing > self-heal > qa > git > checkpoint
```

Calculate progress bar:
- Compute percentage: `(current_story - 1) / total_stories * 100` (or use story completion ratio)
- Build a 12-character bar: filled `█` for completed, `░` for remaining
- Example at 65%: `████████░░░░`

Display compact view (6 lines of content):

```
+---------------------------------------------+
| Maestro Status                              |
+---------------------------------------------+
  Feature:   [feature name, truncated to 35 chars if needed]
  Phase:     validate > delegate > [IMPLEMENT] > self-heal > qa > git > checkpoint
  Progress:  M[current_milestone]/[total_milestones]  S[current_story]/[total_stories]  ████████░░░░  [pct]%
  Elapsed:   [Xm Ys]
  Cost:      ~$[cost_actual] (~$[cost_projected] projected)
  Trust:     [trust_level] ([qa_first_pass_rate]% QA first-pass)
```

Notes:
- If `layer` is not `opus`, omit the `M[x]/[y]` milestone count from Progress
- If `cost_actual` or `cost_projected` is not available, show token count instead: `~[token_spend] tokens`
- If `trust.yaml` does not exist, show `Trust: unknown`
- Phase line wraps are acceptable — keep content accurate over fitting in one line

After the box, show quick-action options based on state:

If session is active (not paused, not completed, not aborted):

Use AskUserQuestion:
- Question: "Session is active. What would you like to do?"
- Header: "Action"
- Options:
  1. label: "Pause", description: "Save state and pause for later resumption"
  2. label: "Abort", description: "End the session. Committed work is preserved."
  3. label: "View details", description: "Show full 11-section status (--detail)"

If session is paused:

Use AskUserQuestion:
- Question: "Session is paused. What would you like to do?"
- Header: "Action"
- Options:
  1. label: "Resume (Recommended)", description: "Continue from story [current]/[total]"
  2. label: "Abort", description: "End the session. Committed work is preserved."
  3. label: "View details", description: "Show full 11-section status (--detail)"

If session is completed:

Use AskUserQuestion:
- Question: "Session completed. What's next?"
- Header: "Next"
- Options:
  1. label: "Start new session", description: "Begin a new feature with /maestro"
  2. label: "View history", description: "See past sessions and cost analysis"

---

### `--detail` or `--verbose` — show FULL status

Read `.maestro/trust.yaml` for trust metrics.
Read `.maestro/config.yaml` and check for an `integrations` section.

Calculate time elapsed from `started_at` to now.

Display comprehensive 11-section status:

```
+---------------------------------------------+
| Maestro Session Status                      |
+---------------------------------------------+

  Feature: [feature name]
  Session: [session_id, first 8 chars]
  Mode:    [mode]
  Started: [started_at, human-readable]
  Elapsed: [Nh Nm]

  Phase:
    validate > delegate > [IMPLEMENT] > self-heal > qa > git > checkpoint
    (Show the current phase in CAPS with brackets; others in lowercase.
     Map phase values: validate, decompose/research -> validate;
     delegate -> delegate; implement -> IMPLEMENT;
     self_heal -> self-heal; qa_review -> qa;
     git_craft -> git; checkpoint -> checkpoint.
     Completed/paused/aborted show all lowercase with a note instead.)

  Progress:
    Story:   [current_story] / [total_stories]  (ok)
    Phase:   [phase]
    QA:      iteration [qa_iteration] / [max_qa_iterations]  (ok) or (!) if qa_iteration > 1
    Heal:    iteration [self_heal_iteration] / [max_self_heal]  (ok) or (x) if at max

  Cost:
    Spent:     ~[token_spend] tokens  (ok)
    Remaining: ~[estimated_remaining] tokens (estimated)  (ok) or (!) if < 20% of budget

  Trust:
    Level:          [trust_level]  (ok) or (!) if low/probation
    Total stories:  [total_stories from trust.yaml]
    QA first-pass:  [qa_first_pass_rate]%
    Avg QA rounds:  [average_qa_iterations]

  Integrations:
    (If `.maestro/config.yaml` has an `integrations` section, list each:)
    github:  (ok) configured
    linear:  (ok) configured
    slack:   (x) not configured
    (If no integrations section exists, show:)
    No integrations configured.

+---------------------------------------------+
```

If `layer` is `opus`, add Magnum Opus section:

```
  Magnum Opus:
    Opus mode:          [opus_mode]
    Milestone:          [current_milestone] / [total_milestones]
    Milestones:
      M1: [name] — [status] ([cost])
      M2: [name] — [status] ([cost])
      ...
    Budget:             [token_spend] / [token_budget or "unlimited"]
    Time budget:        [elapsed] / [time_budget_hours or "unlimited"]
    Fix cycles:         [fix_cycle] / [max_fix_cycles]
    Consecutive fails:  [consecutive_failures] / [max_consecutive_failures]
```

If the session is paused, also show:

```
  Session is PAUSED.
  Resume with: /maestro status resume
  Abort with:  /maestro status abort
```

If the session is completed, also show:

```
  Session COMPLETED.
  Start a new session with: /maestro "next feature"
```

After the box, use AskUserQuestion for actions (same options as compact view).

---

### `--tokens` — token breakdown per model

Read `.maestro/state.local.md` for token data. If the state tracks per-model token spend, display:

```
+---------------------------------------------+
| Token Breakdown                             |
+---------------------------------------------+
  Model         Tokens     % of total
  ----------    --------   ----------
  sonnet        145,230    78%
  opus          34,500     18%
  haiku          7,200      4%
  ----------    --------   ----------
  Total         186,930    100%

  Stories:
    S1: 24,100 tokens
    S2: 31,400 tokens
    S3: 28,700 tokens
    ...
```

If per-model data is not available in state, show the total token spend and note that
per-model breakdown requires `layer: opus` or detailed logging.

---

### `--qa` — QA iteration history

Read `.maestro/state.local.md` for QA iteration data. Display:

```
+---------------------------------------------+
| QA Iteration History                        |
+---------------------------------------------+
  Story     Iterations    Result
  -------   ----------    ------
  S1        1             (ok) first-pass
  S2        2             (ok) passed on retry
  S3        3             (!) at limit, accepted
  S4        1             (ok) first-pass

  Overall QA first-pass rate: [qa_first_pass_rate]%
  Average iterations: [average_qa_iterations]
```

If no QA history is available, note that QA history accumulates as stories complete.

---

### `--cost` — cost breakdown per story

Read `.maestro/state.local.md` for cost data. Display:

```
+---------------------------------------------+
| Cost Breakdown                              |
+---------------------------------------------+
  Story     Tokens     Cost
  -------   --------   ------
  S1        24,100     ~$0.18
  S2        31,400     ~$0.24
  S3        28,700     ~$0.22
  ...
  -------   --------   ------
  Total     186,930    ~$1.24

  Projected remaining: ~$2.56
  Projected total:     ~$3.80
```

If cost data is not broken down per story, show the totals available.

---

### `resume` — Resume paused session

1. Re-read `.maestro/state.local.md` and verify `active: true` and `phase: paused`

2. If `active` is false or phase is not `paused`:
   ```
   Cannot resume: session is not paused.
   Current phase: [phase]
   ```
   Stop here.

3. Validate that the session is resumable:
   - Check that `.maestro/stories/` contains story files
   - Check that `current_story` is within range
   - Read the current story file to verify it exists

4. If Magnum Opus (`layer: opus`):
   - Check milestone state is consistent
   - Verify roadmap file exists
   - Load vision document for North Star re-injection

5. Update state:
   - Set `phase` back to the last active phase before pause (read from state or default to `validate` for current story)
   - Set `last_updated` to current timestamp
   - Keep `active: true`

6. Update the body text (after the `---` closing) to resume the dev loop:
   ```
   Continue Maestro dev-loop for story [current]/[total].
   Story: .maestro/stories/[NN-slug].md
   Phase: [phase] (resuming from pause).
   Mode: [mode].
   NORTH STAR: [feature description]
   ```

7. Display:
   ```
   Resuming Maestro session.

   Feature: [feature]
   Picking up: story [current]/[total] — "[story title]"
   Phase: [phase]
   Mode: [mode]

   Continuing...
   ```

8. The stop hook will pick up the updated state and continue the dev loop.

---

### `abort` — Abort session

1. Ask for confirmation using AskUserQuestion:

   Use AskUserQuestion:
   - Question: "Abort session? Committed work is preserved. Uncommitted changes for the current story remain in your working tree."
   - Header: "Confirm"
   - Options:
     1. label: "Yes, abort", description: "Mark session as aborted"
     2. label: "Cancel", description: "Go back, keep session active"

2. If confirmed:
   - Update `.maestro/state.local.md`:
     - Set `active: false`
     - Set `phase: aborted`
     - Set `last_updated` to current timestamp
   - Update the body text:
     ```
     Session aborted by user.
     Feature: [feature]
     Progress at abort: story [current]/[total], phase: [phase]
     ```
   - Update `.maestro/state.md` (persistent project state):
     - Log the aborted session with timestamp and progress

3. Display:
   ```
   Session aborted.

   Committed work is preserved (stories 1 through [last committed]).
   Any uncommitted changes for story [current] remain in your working tree.

   To start fresh: /maestro "new feature description"
   ```

---

### `pause` — Pause running session

1. Read current state. If `phase` is already `paused`:
   ```
   Session is already paused.
   Resume with: /maestro status resume
   ```
   Stop here.

2. If `active` is false:
   ```
   No active session to pause.
   ```
   Stop here.

3. Update `.maestro/state.local.md`:
   - Record the current phase as `paused_from: [current phase]` (store in frontmatter)
   - Set `phase: paused`
   - Set `last_updated` to current timestamp

4. Update the body text:
   ```
   Session paused by user.
   Feature: [feature]
   Story: [current]/[total]
   Paused from phase: [original phase]
   Resume with: /maestro status resume
   ```

5. Display:
   ```
   Session paused.

   Feature: [feature]
   Progress: story [current]/[total]
   Paused during: [original phase]

   Resume with: /maestro status resume
   Abort with:  /maestro status abort
   ```

---

## Important Notes

- The state file `.maestro/state.local.md` is the single source of truth for session state. Never rely on in-memory state across sessions.
- When resuming, always re-read `.maestro/dna.md` to ensure project context is fresh.
- The `trust.yaml` file is cumulative across all sessions — never reset it on abort or pause.
- When displaying token spend, format large numbers with commas (e.g., 145,230 tokens).
- Time elapsed should be calculated from `started_at` to the current time, not `last_updated`.
- If the state file exists but has corrupted or missing frontmatter fields, report the issue clearly and suggest running `/maestro init` to reset.
- Default view is COMPACT (6 lines). Use `--detail` or `--verbose` for the full view.
- Progress bar uses `████░░░░` style (█ for done, ░ for remaining). Never use `[===>  ]`.
