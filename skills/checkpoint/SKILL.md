---
name: checkpoint
description: "Named project-state snapshots during long autonomous runs. Create, list, revert, and clean up checkpoints. Inspired by Windsurf Cascade checkpoints."
---

# Checkpoint

Named snapshots of project state during long autonomous runs. Each checkpoint captures the git commit and Maestro state, enabling safe revert to any earlier point.

## When to Use

- Before each milestone starts (opus mode — automatic)
- Before any destructive operation (file delete, major refactor — automatic)
- After each successful QA review (optional, configurable via `checkpoint_on_qa_pass`)
- On explicit user request: `/maestro checkpoint <name>`

## Creating a Checkpoint

### Step 1: Resolve Session ID

Read `session_id` from `.maestro/state.local.md`. Use the first 6 characters.

### Step 2: Create Git Tag

```bash
git tag maestro/cp/{session_id_short}/{name}
```

Example: `maestro/cp/d8a3f1/pre-auth-refactor`

Name must be slug-safe: lowercase, hyphens only. If the tag exists, append `-2`, `-3`, etc.

### Step 3: Save Maestro State Snapshot

```bash
mkdir -p .maestro/checkpoints/{name}
cp .maestro/state.local.md .maestro/checkpoints/{name}/state.md
cp -r .maestro/memory/ .maestro/checkpoints/{name}/memory/
```

Append a row to `.maestro/checkpoints/index.md`:

```
| {name} | {timestamp} | {short_commit} | {description} |
```

## Auto-Checkpoint Triggers

| Trigger | When | Name Pattern |
|---------|------|--------------|
| Milestone start | Before each milestone in opus mode | `pre-m{N}-{milestone-slug}` |
| Destructive operation | Before file delete or major refactor | `pre-{operation-slug}` |
| User request | `/maestro checkpoint <name>` | `{user-supplied-name}` |
| QA pass | After QA approves a story (if `checkpoint_on_qa_pass: true`) | `qa-{story-slug}` |

`checkpoint_on_qa_pass` defaults to `false`. Set it in `.maestro/state.local.md` to enable.

## Listing Checkpoints

Command: `/maestro checkpoint list`

```
Session Checkpoints:
  1. pre-auth (2h ago)       — before M2 started
  2. after-api (1h ago)      — M2-S3 complete, API routes working
  3. pre-refactor (30m ago)  — about to restructure auth flow
```

Show at most the 5 most recent. If more exist, append: `(+N older, use --all to list)`.

## Reverting to a Checkpoint

Command: `/maestro checkpoint revert <name>`

**Safety first** — always checkpoint current state before reverting:

```
Creating safety checkpoint of current state...
Checkpoint created: pre-revert-{timestamp}
```

Then:

1. Resolve the tag: `maestro/cp/{session_id_short}/{name}`
2. Reset to the tagged commit: `git reset --hard {commit}`
3. Restore state: `cp .maestro/checkpoints/{name}/state.md .maestro/state.local.md`
4. Restore memory: `cp -r .maestro/checkpoints/{name}/memory/ .maestro/memory/`
5. Confirm:

```
Reverted to checkpoint: {name}
  Commit: {short_commit}
  State restored from: .maestro/checkpoints/{name}/
  Safety checkpoint: pre-revert-{timestamp}

Run /maestro magnum-opus --resume to continue from this point.
```

## Cleanup

**Keep last 5 per session.** After creating a checkpoint, if the session count exceeds 5, delete the oldest tag and its state directory.

**7-day auto-expiry.** On each Maestro session start, scan `maestro/cp/*` tags and delete any older than 7 days along with their `.maestro/checkpoints/{name}/` directories.

**Ship cleanup.** When `/maestro ship` completes, delete all session checkpoint tags and remove `.maestro/checkpoints/`.

## Integration Points

| Skill | Integration |
|-------|-------------|
| `opus-loop` | Checkpoint before each milestone (`pre-m{N}-{slug}`) |
| `dev-loop` | Checkpoint after QA pass if `checkpoint_on_qa_pass: true` |
| `rollback` | Use checkpoint tags as rollback targets |
| `ship` | Delete all session checkpoint tags and state dirs on ship |

## HANDOFF.md

Every checkpoint writes a HANDOFF.md to `.maestro/HANDOFF.md`. This file is the primary mechanism for session state transfer — a new agent or a resumed session reads it as T1 context before doing anything else.

### Format (Community-Standard Schema)

This format aligns with the convergent HANDOFF.md standard emerging across Claude Code community tools (Ralph Loop, ClaudeCTX, OpenClaw). Using a shared schema ensures cross-tool compatibility.

```markdown
# HANDOFF — [Feature Name]

**Session:** [session_id] | **Date:** [ISO timestamp] | **Branch:** [git branch]
**Maestro Version:** [version] | **Mode:** [checkpoint|yolo|careful] | **Layer:** [execution|opus]

## Current State
- Milestone: [N/M] — [milestone name]
- Story: [N/M] — [story name]
- Phase: [current phase]
- Trust Level: [novice|apprentice|journeyman|expert]

## Decisions Made
- [Decision 1 with rationale]
- [Decision 2 with rationale]

## Files Modified
- [file1.ts] — [what changed]
- [file2.ts] — [what changed]

## Next Steps
1. [Immediate next action]
2. [Following action]

## Open Questions
- [Unresolved question needing user input]

## Context to Preserve
- [Key fact that shouldn't be lost across session boundary]

## Cost Summary
- Tokens used this session: [N]K
- Cost this session: ~$[N.NN]
- Stories completed: [N]/[total]
- QA first-pass rate: [N]%

## Environment
- Model: [primary model used]
- Active MCP servers: [list if relevant]
- Active worktrees: [count]
```

### Writing HANDOFF.md

At every checkpoint, write `.maestro/HANDOFF.md` with the current session state:

1. Read `session_id`, current milestone/story progress, and phase from `.maestro/state.local.md`
2. Read the git branch: `git branch --show-current`
3. Read the list of files changed since the last checkpoint: `git diff --name-only HEAD~1 HEAD` (or since the session-start commit if available)
4. Populate all 6 sections:
   - **Current State** — milestone N/M, story N/M, current phase
   - **Decisions Made** — architectural or approach decisions made during the session; pull from state or memory if available
   - **Files Modified** — one line per changed file with a brief description of what changed
   - **Next Steps** — the immediate action queue (what would happen next if the session continued)
   - **Open Questions** — any unresolved items that need user input before proceeding
   - **Context to Preserve** — facts that should survive a session boundary (model choices, constraint reasons, workaround explanations)
5. Write the file, overwriting any previous HANDOFF.md

Before overwriting, archive the previous file (see Archive Behavior below).

### Archive Behavior

Before writing a new HANDOFF.md, if `.maestro/HANDOFF.md` already exists:

```bash
mkdir -p .maestro/handoffs/
cp .maestro/HANDOFF.md .maestro/handoffs/handoff-{previous_timestamp}.md
```

Where `{previous_timestamp}` is read from the `**Date:**` line of the existing HANDOFF.md (or derived from the file's mtime). This preserves a complete chain of session handoffs for debugging and retrospective review.

### Session Resume

When a Maestro session starts (any `/maestro` command after a gap), check for `.maestro/HANDOFF.md`:

1. If the file exists, inject its content as T1 context before composing the agent prompt
2. Log: `[memory] HANDOFF.md injected — resuming from [Feature Name] at [phase]`
3. The HANDOFF.md is NOT deleted on resume — it remains until the next checkpoint overwrites it

This ensures that even if episodic memory has decayed, the last-known session state is immediately available to the resumed agent.

### HANDOFF.md Lifecycle

| Event | HANDOFF.md action |
|-------|------------------|
| Checkpoint created | Archive existing → write new |
| Session resumed | Read and inject as T1 context |
| `/maestro ship` | Archive final → remove `.maestro/HANDOFF.md` |
| Workspace switch | Write new HANDOFF.md in the switched workspace; archive in source workspace |

## State Schema

```yaml
checkpoint_on_qa_pass: false   # true = auto-checkpoint after each QA pass
checkpoints:
  - name: pre-auth-refactor
    tag: maestro/cp/d8a3f1/pre-auth-refactor
    commit: a1b2c3d
    timestamp: 2026-03-18T14:32:00Z
```
