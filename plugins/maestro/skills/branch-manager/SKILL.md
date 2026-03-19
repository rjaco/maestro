---
name: branch-manager
description: "Manage per-instance git branches for parallel Maestro sessions. Creates, tracks, and merges feature branches."
---

# Branch Manager

This skill manages isolated git branches for each Maestro instance working on a story. It ensures parallel sessions do not interfere with each other by giving every instance its own branch, tracked in a central registry.

## Branch Naming Convention

Each instance branch follows the pattern:

```
maestro/{session_id}/{story_slug}
```

Examples:
- `maestro/a9ebf0e0/s6-branch-manager`
- `maestro/3f2c1d99/s7-merge-coordinator`

The `story_slug` is derived from the story ID and title: lowercase, hyphens replacing spaces, non-alphanumeric characters stripped.

## Branch Creation

When a Maestro instance starts work on a story, it must create its working branch before making any changes:

```bash
SESSION_ID="<current session id>"
STORY_SLUG="<story-id-story-title>"
BRANCH="maestro/${SESSION_ID}/${STORY_SLUG}"

git checkout development
git pull origin development
git checkout -b "$BRANCH"
```

The branch is always cut from the latest `development`. Never cut from `main`.

## Worktree Integration

When using `isolation: "worktree"` in the Claude Code execution context, each story automatically runs in its own worktree. Worktrees already provide filesystem isolation but still share the git object store. The branch created above is the worktree's tracking branch.

To create a worktree with its branch in one step:

```bash
git worktree add ".claude/worktrees/${SESSION_ID}" -b "maestro/${SESSION_ID}/${STORY_SLUG}" development
```

## Branch Tracking

After creating a branch, register it in the instance state file:

**File:** `.maestro/instances/{session_id}.json`

```json
{
  "session_id": "<session_id>",
  "story": "<story_slug>",
  "branch": "maestro/<session_id>/<story_slug>",
  "started_at": "<ISO 8601 timestamp>",
  "status": "active"
}
```

Update `status` to `"merged"` or `"abandoned"` when the story concludes.

## Branch Cleanup

After a story branch has been successfully merged to `development`, delete the temporary branch to keep the repository clean:

```bash
# Delete local branch
git branch -d "maestro/${SESSION_ID}/${STORY_SLUG}"

# Delete remote branch (if pushed)
git push origin --delete "maestro/${SESSION_ID}/${STORY_SLUG}" 2>/dev/null || true

# Remove the worktree if one was used
git worktree remove ".claude/worktrees/${SESSION_ID}" --force 2>/dev/null || true
```

Update the instance state file status to `"merged"` before deleting.

## Rules

- Never commit directly to `main` or `development` during story work.
- Always create the instance branch before the first file change.
- Always register the branch in `.maestro/instances/{session_id}.json` immediately after creation.
- Always clean up branches after a successful merge.
- If a branch already exists for this session+story, reuse it — do not create a duplicate.
