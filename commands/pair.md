---
name: pair
description: "Activate pair programming mode — AI proposes diffs one step at a time, human approves each change before it is applied"
argument-hint: "[start [--file <path>]|stop]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
  - AskUserQuestion
---

# Maestro Pair

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Human-AI pair programming. The AI proposes one change at a time — a test, then an implementation, then a refactor. You approve, modify, or take over at every step. You are always the pilot.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments — Show pair session status

Read `.maestro/state.local.md` to check whether a pair session is active.

```
+---------------------------------------------+
| Pair Programming                            |
+---------------------------------------------+

  Status: active | inactive
  Target: <file or "general"> | none

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Pair Programming"
- Options:
  1. label: "Start a pair session", description: "Begin working together on a task or file"
  2. label: "Stop current session", description: "End the active pair session and run the learning loop"

### `start` — Begin a pair session

Optionally accepts `--file <path>` to focus the session on a specific file.

1. Check `.maestro/state.local.md` — if a session is already active:

   Use AskUserQuestion:
   - Question: "A pair session is already active. What would you like to do?"
   - Header: "Session Already Active"
   - Options:
     1. label: "Continue the existing session", description: "Keep pairing where you left off"
     2. label: "End it and start fresh", description: "Stop the current session and begin a new one"

2. If `--file <path>` is provided, verify the file exists. If not:
   ```
   [maestro] File not found: <path>
   ```

3. Ask what the user wants to work on:

   Use AskUserQuestion:
   - Question: "What would you like to work on together?"
   - Header: "Pair Programming — Intent"
   - Options:
     1. label: "Fix a bug", description: "Track down and fix a specific failure"
     2. label: "Add a feature", description: "Implement new behavior step by step"
     3. label: "Refactor", description: "Improve code quality without changing behavior"
     4. label: "Write tests", description: "Add or improve test coverage"
     5. label: "I'll describe it", description: "Free-form — describe the intent in your own words"

4. Write to `.maestro/state.local.md`:
   ```yaml
   pair_session:
     active: true
     started_at: <ISO-8601>
     target_file: <path or null>
     intent: <selected intent>
   ```

5. Display the session header:

   ```
   +---------------------------------------------+
   | Pair Session Started                        |
   +---------------------------------------------+

     Target:  <file or "general">
     Intent:  <intent>
     Mode:    TDD (test-first)

     (i) I will propose one change at a time.
     (i) Nothing is applied without your approval.
     (i) Say "let me do this" at any point to take over.
     (i) Say "I've made my changes" to hand back.
   ```

6. Immediately begin the pair workflow defined in `skills/pair-programming/SKILL.md`:
   - Step 1: Frame the Intent
   - Step 2: Write the Test First
   - Step 3: Run the Test (Red)
   - Step 4: Propose the Implementation
   - Step 5: Run the Test (Green)
   - Step 6: Refactor
   - Step 7: Commit Checkpoint

   At each step, present a diff or plan and use AskUserQuestion before applying any change.

### `stop` — End a pair session

1. Read `.maestro/state.local.md`. If no pair session is active:
   ```
   [maestro] No active pair session.
   ```

2. Ask for confirmation:

   Use AskUserQuestion:
   - Question: "End the pair session?"
   - Header: "End Session"
   - Options:
     1. label: "Yes, end session", description: "Stop pairing and run the learning loop"
     2. label: "Cancel", description: "Keep the session going"

3. On confirmation:
   - Remove `pair_session` from `.maestro/state.local.md`.
   - Run the learning loop to process any corrections recorded during the session.

4. Display session summary:

   ```
   +---------------------------------------------+
   | Pair Session Ended                          |
   +---------------------------------------------+

     Duration:    <elapsed time>
     Corrections: <N> learning signals recorded
     Commits:     <N> checkpoint commits made

     (i) Learning loop has processed session corrections.
     (i) Run /maestro pair start to begin a new session.
   ```

---

## Human Takeover

At any point during an active session the user can say:
- `let me do this` — AI steps aside and observes. No further proposals are made.
- `I've made my changes` — AI re-reads modified files, diffs against the last known state, and resumes.

When the user returns control the AI displays:

```
Reading your changes...

You modified: <file(s)>
Changes detected:
  <summary of what changed>

Incorporating your changes into context.
Continue? [yes / re-plan / end session]
```

---

## Flags

| Flag | Effect |
|------|--------|
| `--file <path>` | Focus the session on a specific file |
| `--pause` | Suspend the session and save state |
| `--resume` | Resume from a suspended state |
| `--end` | Alias for `stop` — end session and run learning loop |
| `--yolo` | Switch to autonomous mode for the remaining work in this session |
