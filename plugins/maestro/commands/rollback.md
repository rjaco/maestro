---
name: rollback
description: "Revert changes from a story or feature with git + kanban sync"
argument-hint: "[COMMIT_HASH|STORY_ID|last]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Maestro Rollback

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Safely revert changes from a story, commit, or the most recent build. Uses `git revert` (not `git reset --hard`) to create a new commit that undoes the changes, preserving full git history. Syncs the rollback with kanban status and brain notes if configured.

## Step 1: Check Prerequisites

1. Read `.maestro/config.yaml`. If it does not exist:
   ```
   [maestro] Not initialized. Run /maestro init first.
   ```
   Stop here.

2. Verify the working directory is a git repository:
   ```bash
   git rev-parse --is-inside-work-tree
   ```
   If not:
   ```
   [maestro] Not a git repository. Rollback requires git.
   ```
   Stop here.

3. Check for uncommitted changes:
   ```bash
   git status --porcelain
   ```
   If there are uncommitted changes:
   ```
   [maestro] Working tree has uncommitted changes.

     (!) Rollback creates a revert commit. Please commit or stash
         your changes first.

     Options:
       git stash        Temporarily stash changes
       git commit -am   Commit all changes
   ```
   Use AskUserQuestion:
   - Question: "Working tree has uncommitted changes. How to proceed?"
   - Header: "Uncommitted"
   - Options:
     1. label: "Stash changes and continue", description: "Run git stash, proceed with rollback, then remind to unstash"
     2. label: "Cancel", description: "Abort rollback, keep working tree as-is"

   If "Stash changes and continue":
   ```bash
   git stash push -m "maestro-rollback-stash"
   ```
   Note that we need to remind the user to `git stash pop` after rollback.

4. If `$ARGUMENTS` is empty, show usage:
   ```
   +---------------------------------------------+
   | Rollback                                    |
   +---------------------------------------------+

     Usage:
       /maestro rollback last
       /maestro rollback 03-frontend
       /maestro rollback abc1234

     Arguments:
       last           Revert the most recent Maestro story
       STORY_ID       Revert a specific story (by ID or slug)
       COMMIT_HASH    Revert a specific git commit

     (i) Rollback uses git revert (safe, creates new commit).
         Original commits are preserved in history.
   ```
   Stop here.

## Step 2: Resolve the Target

Parse `$ARGUMENTS` to determine what to revert.

### Case: `last`

Find the most recent Maestro commit:

```bash
git log --oneline --grep="\[maestro\]" -1
```

If no Maestro commits found, try:

```bash
git log --oneline --grep="story" -1
```

If still not found:
```
[maestro] No recent Maestro commits found.

  (i) Use a specific commit hash instead:
      /maestro rollback abc1234
```
Stop here.

Extract the commit hash from the result.

### Case: STORY_ID

Accept multiple formats:
- Numeric: `3`, `03`
- Full slug: `03-frontend`
- Partial slug: `frontend`

1. Glob `.maestro/stories/*.md` and match the story file.
2. Read the story file to get the title and slug.
3. Search for the story's commit in git log:
   ```bash
   git log --oneline --grep="[story_slug]" --grep="story[- ]0?[story_id]" --all-match
   ```
   If no commit matches by grep, try a broader search:
   ```bash
   git log --oneline --grep="[story_title]"
   ```
4. If multiple commits match, present them for selection.
5. If no commit found:
   ```
   [maestro] No commit found for story "[STORY_ID]".

     (i) The story may not have been committed yet.
     (i) Use git log to find the commit manually:
         git log --oneline --grep="[story_slug]"
   ```
   Stop here.

### Case: COMMIT_HASH

Validate the commit exists:

```bash
git cat-file -t [COMMIT_HASH]
```

If invalid:
```
[maestro] Invalid commit: "[COMMIT_HASH]"

  (x) Commit not found in git history.
  (i) Check the hash with: git log --oneline -10
```
Stop here.

## Step 3: Analyze the Commit

Once the target commit hash is resolved, gather details:

```bash
git log --format="%H%n%s%n%an%n%ai" -1 [COMMIT_HASH]
git diff --stat [COMMIT_HASH]^..[COMMIT_HASH]
git diff --shortstat [COMMIT_HASH]^..[COMMIT_HASH]
```

Extract:
- `full_hash` — Full commit hash
- `message` — Commit message
- `author` — Author name
- `date` — Commit date
- `files_changed` — List of files affected
- `insertions` — Lines added
- `deletions` — Lines removed

Check if this commit is a merge commit:
```bash
git cat-file -p [COMMIT_HASH] | grep "^parent" | wc -l
```

If merge commit (more than 1 parent):
```
  (!) This is a merge commit. Reverting merge commits requires
      special handling.

  (i) Consider reverting individual story commits instead.
```

Use AskUserQuestion:
- Question: "This is a merge commit. Revert anyway?"
- Header: "Merge"
- Options:
  1. label: "Revert with -m 1 (mainline parent 1)", description: "Undo the merged branch changes"
  2. label: "Cancel", description: "Pick individual commits instead"

## Step 4: Show What Will Be Reverted

Display a comprehensive preview:

```
+---------------------------------------------+
| Rollback Preview                            |
+---------------------------------------------+

  Commit:   [short_hash] [first 50 chars of message]
  Author:   [author]
  Date:     [date, human-readable]

  Changes to revert:
    [file_path_1]     [+insertions/-deletions]
    [file_path_2]     [+insertions/-deletions]
    [file_path_3]     [+insertions/-deletions]
    ...

  Summary:
    [N] files changed
    [N] insertions to remove
    [N] deletions to restore

  Story:    [story_id — story_title, if identified]
  Session:  [session_id, if identified from state]
```

If the commit touches files that have been modified in subsequent commits:

```
  (!) Potential conflicts:
      [file_path] was modified in [N] later commits.
      Git revert may require manual conflict resolution.
```

## Step 5: Confirm with User

Use AskUserQuestion:
- Question: "Revert commit [short_hash]? This creates a new commit that undoes these changes."
- Header: "Confirm"
- Options:
  1. label: "Revert (Recommended)", description: "Create a revert commit. Safe, preserves history."
  2. label: "Show full diff first", description: "Display the complete diff before deciding"
  3. label: "Cancel", description: "Abort rollback, no changes made"

### If "Show full diff first"

```bash
git diff [COMMIT_HASH]^..[COMMIT_HASH]
```

Display the diff, then re-ask for confirmation:

Use AskUserQuestion:
- Question: "Proceed with revert?"
- Header: "Confirm"
- Options:
  1. label: "Revert", description: "Create a revert commit"
  2. label: "Cancel", description: "Abort rollback"

## Step 6: Execute the Revert

### 6a: Run git revert

```bash
git revert --no-edit [COMMIT_HASH]
```

If merge commit and user chose to revert:
```bash
git revert --no-edit -m 1 [COMMIT_HASH]
```

### 6b: Handle Conflicts

If the revert produces conflicts:

```
  (!) Revert has conflicts in [N] files:
      [file_path_1]
      [file_path_2]
```

Use AskUserQuestion:
- Question: "Revert has merge conflicts. How to proceed?"
- Header: "Conflicts"
- Options:
  1. label: "Abort revert", description: "Cancel the revert, restore working tree"
  2. label: "Keep conflicts for manual resolution", description: "Leave conflict markers in files for you to fix"

If "Abort revert":
```bash
git revert --abort
```
```
[maestro] Revert aborted. Working tree restored.

  (i) The commit may have been modified by later changes.
  (i) Consider reverting specific files manually:
      git checkout [COMMIT_HASH]^ -- path/to/file
```
Stop here.

If "Keep conflicts":
```
[maestro] Conflicts left in working tree for manual resolution.

  After fixing conflicts:
    git add [conflicted files]
    git commit

  To abort:
    git revert --abort
```
Stop here.

### 6c: Verify the Revert

After successful revert:

```bash
git log --oneline -1
```

Confirm the revert commit was created.

## Step 7: Update Kanban Status

Check if kanban integration is configured in `.maestro/config.yaml`:

```yaml
integrations:
  kanban:
    provider: [github|asana|jira|linear]
```

If configured and the reverted commit corresponds to a story:

1. Read the story file `.maestro/stories/[NN-slug].md`
2. Update the story status back to `pending`
3. If the story has a `kanban_id`, update the external card:

   For GitHub Issues:
   ```bash
   gh issue edit [issue_number] --remove-label "done" --add-label "pending"
   ```

   For other providers, log the status change for manual sync:
   ```
   (i) Kanban: marked story [slug] as pending on [provider].
   ```

If kanban is not configured, skip silently.

## Step 8: Update Brain

Check if brain/knowledge base integration is configured:

```yaml
integrations:
  knowledge_base:
    sync_enabled: true
```

If configured:

1. Ask for the rollback reason:

   Use AskUserQuestion:
   - Question: "Why are you rolling back? (Helps future planning)"
   - Header: "Reason"
   - Options:
     1. label: "Bug introduced", description: "The change broke something"
     2. label: "Wrong approach", description: "Need to redesign this part"
     3. label: "Scope changed", description: "Requirements shifted, this is no longer needed"
     4. label: "Skip — no note needed", description: "Don't save a brain note"

2. If a reason is selected (not "Skip"), save a brain note:

   ```
   brain.save(content, "decision", "Rollback: [story_title]")
   ```

   Content:
   ```markdown
   # Rollback: [story_title]

   **Date:** [date]
   **Commit reverted:** [short_hash]
   **Reason:** [selected reason]

   ## What was reverted
   [commit message]

   ## Files affected
   - [file list]

   ## Lesson
   [Based on reason: describe what to do differently next time]
   ```

If brain is not configured, skip silently.

## Step 9: Update State

Read `.maestro/state.md` (persistent project state). Append a rollback event:

```markdown
## Rollback Events

| Date | Commit | Story | Reason | Reverted By |
|------|--------|-------|--------|-------------|
| [date] | [short_hash] | [story_slug or "manual"] | [reason] | maestro |
```

If the "Rollback Events" section does not exist, create it.

If `.maestro/state.local.md` exists and has an active session:
- If the rolled-back story is the current story, set phase back to `pending`
- If the rolled-back story was completed, decrement the current_story counter
- Update `last_updated` timestamp

## Step 10: Display Result

```
+---------------------------------------------+
| Rollback Complete                           |
+---------------------------------------------+

  Reverted:  [short_hash] [commit message]
  Method:    git revert (new commit: [revert_hash])
  Files:     [N] files restored
  Story:     [story_slug or "N/A"]

  Status updates:
    (ok) Git revert commit created
    [ok or --] Kanban: [status or "not configured"]
    [ok or --] Brain: [status or "not configured"]
    (ok) State: rollback event recorded
```

If we stashed changes earlier:

```
  (!) Remember to restore your stashed changes:
      git stash pop
```

## Step 11: Offer Next Actions

Use AskUserQuestion:
- Question: "Rollback complete. What's next?"
- Header: "Next"
- Options:
  1. label: "Rebuild the story", description: "Re-run the story with a fresh approach"
  2. label: "View current state", description: "Show /maestro status"
  3. label: "Done", description: "Return to normal operation"

### If "Rebuild the story" and story_id is known:

```
[maestro] To rebuild with modifications:

  1. Edit the story file if needed:
     .maestro/stories/[NN-slug].md

  2. Re-run Maestro:
     /maestro status resume

  (i) The rolled-back approach is saved in your brain
      (if configured) to avoid repeating the same mistake.
```

## Multi-Story Rollback

If the user wants to roll back an entire feature (multiple stories), each story commit must be reverted in reverse order (latest first):

```
[maestro] Feature rollback: reverting [N] stories in reverse order.

  Reverting: 05-e2e-tests ... (ok)
  Reverting: 04-integration ... (ok)
  Reverting: 03-frontend ... (ok)
  Reverting: 02-api-routes ... (ok)
  Reverting: 01-schema ... (ok)

  All [N] story commits reverted.
```

To trigger this, the user can pass a feature name or session ID:
```
/maestro rollback feature:auth
/maestro rollback session:abc12345
```

The command will:
1. Find all commits associated with that feature/session
2. Order them from newest to oldest
3. Revert each one sequentially
4. Update all story statuses back to `pending`

## Integration Points

- **Git**: uses `git revert` for safe history-preserving rollback
- **Kanban Skill**: updates story status on external boards
- **Brain Skill**: saves rollback notes for future reference
- **State**: records rollback events in `.maestro/state.md`
- **Dev-Loop**: respects rolled-back story status on resume
- **History Command**: includes rollback events in session history

## Error Handling

| Error | Action |
|-------|--------|
| Not a git repo | Show clear error, stop |
| Uncommitted changes | Offer to stash, or cancel |
| Commit not found | Show helpful message with git log suggestion |
| Merge conflicts | Offer abort or manual resolution |
| Merge commit | Warn, offer -m 1 revert or cancel |
| No Maestro commits | Suggest using commit hash directly |
| Story file not found | Proceed with git revert, skip kanban/state updates |
| Kanban update fails | Warn, continue (non-blocking) |
| Brain save fails | Warn, continue (non-blocking) |

## Safety Guarantees

1. **Never uses `git reset --hard`** — All rollbacks are `git revert`, creating new commits
2. **Never force-pushes** — The revert commit is a regular commit
3. **Always confirms before executing** — AskUserQuestion required before any destructive action
4. **Preserves original commits** — The reverted commit stays in history
5. **Stash reminder** — If we stashed user changes, we remind them to pop

## Output Contract

```yaml
output_contract:
  display:
    format: "box-drawing"
    sections:
      - "Rollback Preview"
      - "Rollback Complete"
  user_decisions:
    tool: "AskUserQuestion"
    gates:
      - "Uncommitted changes handling"
      - "Revert confirmation"
      - "Merge commit handling (if applicable)"
      - "Conflict resolution (if applicable)"
      - "Rollback reason (if brain configured)"
      - "Next action"
  git_operations:
    - "git revert --no-edit COMMIT"
    - "git stash (if needed)"
    - "NEVER git reset --hard"
    - "NEVER git push --force"
  data_modified:
    - ".maestro/state.md (append rollback event)"
    - ".maestro/state.local.md (update story status)"
  data_read:
    - ".maestro/config.yaml"
    - ".maestro/stories/*.md"
    - ".maestro/state.local.md"
```
