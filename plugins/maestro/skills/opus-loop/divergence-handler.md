# Divergence Handler — Project Pivots Mid-Flight

Handles situations where the user fundamentally changes direction during an active Opus session. Offers structured options to preserve completed work while accommodating the new direction.

## When to Invoke

The conversation-channel classifies a message as `redirect` when it fundamentally changes the product direction, not just adjusts a detail. Examples:

- "Actually, let's build a mobile app instead of a web app"
- "Forget the marketplace — make it a SaaS tool"
- "We need to pivot to B2B instead of B2C"
- "Scrap everything after M2 and go in a different direction"

Minor adjustments (reordering milestones, skipping a feature, changing a design detail) are handled by the opus-loop directly, not by this handler.

## Divergence Protocol

### Step 1: Acknowledge and Clarify

```
I hear you — that is a significant direction change.

Let me make sure I understand:

  Current direction: [summary of current vision]
  New direction:     [summary of what the user is asking for]

  Completed work:
    Milestones done: [list completed milestones]
    Current milestone: M[N] — [name] ([stories done]/[total] stories)
    Total tokens spent: ~[N]K (~$[cost])

Is this accurate? [Y/clarify]
```

Wait for confirmation before proceeding.

### Step 2: Present Options

```
Three ways to handle this:

  [1] Full restart
      Archive everything. New vision interview. New research.
      New roadmap from scratch.
      Completed code stays on this branch as reference.

  [2] Pivot in place
      Keep the foundation (M1-M[last completed]).
      Replace all future milestones with new ones.
      Update vision.md to reflect the new direction.
      No new interview — I will ask targeted follow-up questions.

  [3] Branch
      Keep current progress on a separate git branch.
      Start a new Opus session for the new direction.
      You can merge useful code later.

Which approach? [1/2/3]
```

### Step 3: Execute the Chosen Option

#### Option 1: Full Restart

1. Archive current session:
   - Move `.maestro/vision.md` to `.maestro/archive/vision-[session_id].md`
   - Move `.maestro/roadmap.md` to `.maestro/archive/roadmap-[session_id].md`
   - Move `.maestro/milestones/` to `.maestro/archive/milestones-[session_id]/`
   - Move `.maestro/research/` to `.maestro/archive/research-[session_id]/`
   - Move `.maestro/stories/` to `.maestro/archive/stories-[session_id]/`
2. Update state: `active: false`, `phase: archived`
3. Log the pivot to `.maestro/state.md` with timestamp and reason
4. Invoke `/maestro magnum-opus` with the new vision description to start fresh

#### Option 2: Pivot in Place

1. Archive future milestones (those with status `pending`):
   - Move to `.maestro/archive/milestones-pivot-[timestamp]/`
2. Read the current vision and ask 2-4 targeted follow-up questions about the new direction:
   - "What specifically changes about the target audience?"
   - "Which completed features still apply?"
   - "What new capabilities are needed?"
3. Update `.maestro/vision.md` with the pivot:
   - Add a "Pivot History" section documenting the change
   - Update scope, audience, and success criteria
4. Generate new milestones from the updated vision
   - New milestones start numbering after the last completed milestone
   - Research files are reused where still relevant
5. Update `.maestro/roadmap.md` with the new milestone sequence
6. Present the updated roadmap for approval
7. Continue execution from the first new milestone

#### Option 3: Branch

1. Create a git branch for the current work:
   ```bash
   git checkout -b opus-[session_id]-archive
   git checkout -  # return to previous branch
   ```
2. Archive the current session state (same as Option 1)
3. Start a new Opus session on the original branch
4. Note the archive branch name in `.maestro/state.md` for future reference

### Step 4: Confirm and Continue

After executing the chosen option, confirm the new state:

```
Pivot complete.

  Previous: [old vision summary]
  New:      [new vision summary]
  Preserved: [what was kept]
  Archived:  [what was archived and where]

Continuing with the new direction.
```

## Safety

- Never delete completed work. Always archive.
- Never force-push or rewrite git history.
- Always confirm the user's intent before executing a pivot.
- Log every pivot with timestamp, reason, and what was preserved in `.maestro/state.md`.
