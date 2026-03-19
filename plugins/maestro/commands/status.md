---
name: status
description: "View Maestro session progress and manage lifecycle — resume, pause, or abort a session"
argument-hint: "[resume|abort|pause]"
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Maestro Status — Progress, Resume, Abort, Pause

## Usage

```
/maestro status [resume|abort|pause]
```

## Flags

| Subcommand | Description |
|------------|-------------|
| _(none)_ | Show session status with interactive action menu |
| `resume` | Resume a paused session from its last saved position |
| `abort` | End the session (committed work is preserved) |
| `pause` | Pause a running session for later resumption |

## Examples

```
/maestro status
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

Read `.maestro/config.yaml` and check for an `integrations` section (e.g., `github`, `linear`, `slack`). Note which integrations are configured and their status.

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

After the box, show quick-action options based on state:

If session is active (not paused, not completed, not aborted):

Use AskUserQuestion:
- Question: "Session is active. What would you like to do?"
- Header: "Action"
- Options:
  1. label: "Pause", description: "Save state and pause for later resumption"
  2. label: "Abort", description: "End the session. Committed work is preserved."

If session is paused:

Use AskUserQuestion:
- Question: "Session is paused. What would you like to do?"
- Header: "Action"
- Options:
  1. label: "Resume (Recommended)", description: "Continue from story [current]/[total]"
  2. label: "Abort", description: "End the session. Committed work is preserved."

If session is completed:

Use AskUserQuestion:
- Question: "Session completed. What's next?"
- Header: "Next"
- Options:
  1. label: "Start new session", description: "Begin a new feature with /maestro"
  2. label: "View history", description: "See past sessions and cost analysis"

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
  Resume with: /maestro status resume
  Abort with:  /maestro status abort
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

## Important Notes

- The state file `.maestro/state.local.md` is the single source of truth for session state. Never rely on in-memory state across sessions.
- When resuming, always re-read `.maestro/dna.md` to ensure project context is fresh.
- The `trust.yaml` file is cumulative across all sessions — never reset it on abort or pause.
- When displaying token spend, format large numbers with commas (e.g., 145,230 tokens).
- Time elapsed should be calculated from `started_at` to the current time, not `last_updated`.
- If the state file exists but has corrupted or missing frontmatter fields, report the issue clearly and suggest running `/maestro init` to reset.
