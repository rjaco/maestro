---
name: merge-coordinator
description: "Coordinate merges from multiple Maestro instances to the development branch. Handles rebase, conflict detection, and resolution."
---

# Merge Coordinator

This skill coordinates the merge of a completed story branch back into `development`. It serializes concurrent merges, applies file-type-aware conflict resolution, and logs every outcome for auditability.

## Pre-merge Check

Before attempting to merge, ensure the local `development` branch is up to date and identify any conflicts early:

```bash
git fetch origin development
git checkout development
git pull origin development

# Preview conflicts without committing
git checkout "maestro/${SESSION_ID}/${STORY_SLUG}"
git diff development...HEAD --name-only
```

If the diff is empty, the branch is already up to date and no merge is needed.

## Rebase Strategy

Always rebase the story branch on the latest `development` before merging. This produces a linear history and avoids merge commits in `development`.

```bash
git checkout "maestro/${SESSION_ID}/${STORY_SLUG}"
git fetch origin development
git rebase origin/development
```

After a clean rebase, fast-forward `development`:

```bash
git checkout development
git merge --ff-only "maestro/${SESSION_ID}/${STORY_SLUG}"
git push origin development
```

Never use `git merge --no-ff` for story branches. The merge commit adds noise without benefit.

## Conflict Resolution Rules

When `git rebase` stops with conflicts, apply the following rules by file type before retrying:

### `.md` files (Markdown)
Accept **both** sides — Markdown changes are almost always additive (new sections, new entries). Use a union merge:

```bash
git checkout --union -- path/to/file.md
# Then manually remove the conflict markers, keeping all content blocks
git add path/to/file.md
```

If the union result is syntactically invalid, escalate.

### `.sh` files (Shell scripts)
Attempt a 3-way merge using the common ancestor:

```bash
git mergetool --tool=emerge -- path/to/file.sh
# or
git checkout --merge -- path/to/file.sh
```

If the 3-way merge produces a clean result, stage and continue. If it leaves unresolved markers, escalate.

### `.json` files (Configuration / state)
Perform a deep key merge: if different keys were modified on each side, both changes can coexist. If the **same key** was modified on both sides, escalate.

Strategy:
1. Extract the base, ours, and theirs versions.
2. Identify changed keys in each.
3. If no key overlap: merge both sets of changes into one file, stage, and continue.
4. If key overlap exists: escalate.

### `.maestro/state*` files
Always take the **incoming** change (the rebased branch's version). These files represent the latest state of a session and must not be rolled back:

```bash
git checkout --theirs -- .maestro/state.md
git checkout --theirs -- .maestro/state.json
git add .maestro/state*
```

### All other files
Attempt the default 3-way merge. If unresolved markers remain, escalate.

## File Locking

To prevent two instances from rebasing and pushing the same file simultaneously, acquire a lock before starting the rebase:

**Lock file path:** `.maestro/locks/{filename_hash}.lock`

Where `{filename_hash}` is the MD5 (first 8 chars) of the conflicting file's repo-relative path.

```bash
LOCK_FILE=".maestro/locks/$(echo -n 'path/to/file' | md5sum | cut -c1-8).lock"
mkdir -p ".maestro/locks"

# Acquire lock (fail fast — do not wait)
if ! (set -C; echo "$$" > "$LOCK_FILE") 2>/dev/null; then
  echo "Lock held by $(cat "$LOCK_FILE"). Retry later." >&2
  exit 1
fi

# Release lock on exit
trap 'rm -f "$LOCK_FILE"' EXIT
```

Locks are process-scoped. If the holding process exits (normally or abnormally), the lock is released by the trap.

## Retry and Failure Handling

The rebase+merge sequence is retried up to **3 times** on transient failures (lock contention, network errors). On each retry, wait 5 seconds before attempting again.

If all 3 attempts fail:

1. Abort the rebase to restore the branch to its pre-rebase state:
   ```bash
   git rebase --abort
   ```

2. Create a conflict report:
   **File:** `.maestro/logs/conflicts/{story_slug}-{timestamp}.json`
   ```json
   {
     "session_id": "<session_id>",
     "story": "<story_slug>",
     "branch": "maestro/<session_id>/<story_slug>",
     "attempted_at": "<ISO 8601 timestamp>",
     "attempts": 3,
     "conflicting_files": ["<list of files with unresolved conflicts>"],
     "error": "<last error message>"
   }
   ```

3. Pause the instance and notify the operator via the notification hook.

## Success Logging

After every successful merge, append a record to the merge history log:

**File:** `.maestro/logs/merge-history.jsonl`

```jsonl
{"session_id":"<id>","story":"<slug>","branch":"maestro/<id>/<slug>","merged_at":"<ISO 8601>","files_changed":<n>,"commits":<n>}
```

One JSON object per line. The file is append-only — never truncate or overwrite it.

## Directory Bootstrap

Before writing any lock or log file, ensure the required directories exist:

```bash
mkdir -p .maestro/locks
mkdir -p .maestro/logs/conflicts
```

## Rules

- Always rebase, never merge-commit, when integrating story branches into `development`.
- Acquire file locks before rebasing if concurrent instances may touch the same files.
- Apply file-type conflict rules before escalating to manual resolution.
- Log every merge attempt (success or failure).
- After 3 failed attempts, pause the instance — do not loop indefinitely.
- Never force-push `development` or `main`.
