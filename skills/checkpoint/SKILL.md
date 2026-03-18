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

Run /maestro opus --resume to continue from this point.
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

## State Schema

```yaml
checkpoint_on_qa_pass: false   # true = auto-checkpoint after each QA pass
checkpoints:
  - name: pre-auth-refactor
    tag: maestro/cp/d8a3f1/pre-auth-refactor
    commit: a1b2c3d
    timestamp: 2026-03-18T14:32:00Z
```
