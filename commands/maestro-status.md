---
description: "View Maestro progress, resume paused work, abort, or pause"
argument-hint: "[resume|abort|pause]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
---

# Maestro Status — Progress, Resume, Abort, Pause

You manage the lifecycle of a Maestro session: view progress, resume paused work, abort a session, or pause a running one.

## Step 1: Read Session State

Read `.maestro/state.local.md`.

If the file does not exist or cannot be read:

```
No active Maestro session.

To start a new session:
  /maestro "describe your feature here"

To initialize Maestro for this project:
  /maestro-init
```

Stop here.

## Step 2: Parse State

Extract all fields from the YAML frontmatter of `.maestro/state.local.md`:

- `active` — whether a session is running
- `feature` — the feature being built
- `mode` — yolo, checkpoint, or careful
- `layer` — execution or opus
- `current_story` / `total_stories` — progress
- `phase` — current phase (validate, delegate, implement, self_heal, qa_review, git_craft, checkpoint, paused, completed, aborted, decompose, research)
- `qa_iteration` / `max_qa_iterations`
- `self_heal_iteration` / `max_self_heal`
- `started_at` / `last_updated` — timestamps
- `token_spend` / `estimated_remaining`
- `session_id`
- `model_override`

If `layer` is `opus`, also extract:
- `opus_mode` — full_auto, milestone_pause, budget_cap, time_cap, until_pause
- `current_milestone` / `total_milestones`
- `milestones` — status map of all milestones
- `token_budget` / `time_budget_hours`
- `fix_cycle` / `max_fix_cycles`
- `consecutive_failures` / `max_consecutive_failures`

## Step 3: Handle Subcommands

Check `$ARGUMENTS` for a subcommand.

### No arguments — show status

Read `.maestro/trust.yaml` for trust metrics.

Calculate time elapsed from `started_at` to now.

Display comprehensive status:

```
====================================
  Maestro Session Status
====================================

  Feature: [feature name]
  Session: [session_id, first 8 chars]
  Mode:    [mode]
  Started: [started_at, human-readable]
  Elapsed: [Nh Nm]

  Progress:
    Story:   [current_story] / [total_stories]
    Phase:   [phase]
    QA:      iteration [qa_iteration] / [max_qa_iterations]
    Heal:    iteration [self_heal_iteration] / [max_self_heal]

  Cost:
    Spent:     ~[token_spend] tokens
    Remaining: ~[estimated_remaining] tokens (estimated)

  Trust:
    Level:          [trust_level]
    Total stories:  [total_stories from trust.yaml]
    QA first-pass:  [qa_first_pass_rate]%
    Avg QA rounds:  [average_qa_iterations]

====================================
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

If the session is paused, show:

```
  Session is PAUSED.
  Resume with: /maestro-status resume
  Abort with:  /maestro-status abort
```

If the session is completed, show:

```
  Session COMPLETED.
  Start a new session with: /maestro "next feature"
```

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

### `abort` — Abort session

1. Ask for confirmation:
   ```
   Abort current Maestro session?

   Feature: [feature]
   Progress: story [current]/[total], phase: [phase]
   This will:
     - Mark the session as aborted
     - NOT revert any committed changes
     - Uncommitted changes for the current story will remain in the working tree

   Confirm abort? [Y/n]
   ```

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

### `pause` — Pause running session

1. Read current state. If `phase` is already `paused`:
   ```
   Session is already paused.
   Resume with: /maestro-status resume
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
   Resume with: /maestro-status resume
   ```

5. Display:
   ```
   Session paused.

   Feature: [feature]
   Progress: story [current]/[total]
   Paused during: [original phase]

   Resume with: /maestro-status resume
   Abort with:  /maestro-status abort
   ```

## Important Notes

- The state file `.maestro/state.local.md` is the single source of truth for session state. Never rely on in-memory state across sessions.
- When resuming, always re-read `.maestro/dna.md` to ensure project context is fresh.
- The `trust.yaml` file is cumulative across all sessions — never reset it on abort or pause.
- When displaying token spend, format large numbers with commas (e.g., 145,230 tokens).
- Time elapsed should be calculated from `started_at` to the current time, not `last_updated`.
- If the state file exists but has corrupted or missing frontmatter fields, report the issue clearly and suggest running `/maestro-init` to reset.
