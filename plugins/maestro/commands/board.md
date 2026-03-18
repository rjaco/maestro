---
name: board
description: "View and manage stories as a text-based kanban board"
argument-hint: "[view|sync|move STORY_ID STATUS]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

# Maestro Board

View and manage stories as a text-based kanban board. Syncs with external kanban tools (Asana, Jira, Linear, GitHub Issues) if configured.

## Step 1: Check Prerequisites

1. Read `.maestro/config.yaml`. If it does not exist:
   ```
   [maestro] Not initialized. Run /maestro init first.
   ```

2. Read `.maestro/state.local.md`. If no active session:
   ```
   [maestro] No active session. Start one with /maestro "your feature"
   ```
   However, if there are story files in `.maestro/stories/`, show the board from the last session anyway.

3. Glob `.maestro/stories/*.md` to find all story files.

## Step 2: Handle Arguments

### No arguments or `view` — Display Board

Read all story files from `.maestro/stories/`. Parse the frontmatter for:
- `id`, `slug`, `title`
- Status: derive from `.maestro/state.local.md` (current_story, phase) and story completion state
- `kanban_id` (if synced with external tool)

Group stories by status and display as a text kanban board:

```
+---------------------------------------------+
| Board: Add user authentication              |
+---------------------------------------------+

  BACKLOG          IN PROGRESS      DONE
  -----------      -----------      -----------
  04-tests         03-frontend      01-schema
  05-middleware                      02-api-routes

  Skipped: (none)
  Blocked: (none)

  ---- 2/5 stories complete ----
```

If kanban integration is configured, show sync status:

```
  (ok) Synced with GitHub Issues (milestone #12)
  (i)  Last sync: 2 minutes ago
```

Show available actions:

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Board"
- Options:
  1. label: "Sync with [provider]", description: "Push/pull changes between Maestro and [provider]"
  2. label: "Move a story", description: "Change a story's status manually"
  3. label: "Refresh", description: "Reload the board from story files"
  4. label: "Open in [provider]", description: "Open the board in your browser"

### `sync` — Sync with External Provider

1. Check that `integrations.kanban.provider` is configured. If not:
   ```
   [maestro] No kanban provider configured.

     Set one with:
       /maestro config set integrations.kanban.provider github

     Available providers: github, asana, jira, linear
   ```

2. Invoke the kanban skill's `sync_from_kanban()` operation.

3. If changes detected, present the delta:
   ```
   +---------------------------------------------+
   | Kanban Sync                                 |
   +---------------------------------------------+

     Changes from [provider]:
       (!) Story 03 moved to "Cancelled" on board
       (!) Story 05 description updated on board
       (i) No new cards added

   Use AskUserQuestion:
   - Question: "[N] changes detected from [provider]. How to proceed?"
   - Header: "Sync"
   - Options:
     1. label: "Apply all changes", description: "Accept all board changes into Maestro"
     2. label: "Review each change", description: "See each change and decide individually"
     3. label: "Ignore all", description: "Discard board changes, keep Maestro state"

4. If "Apply all changes" or "Review each change":
   - For status changes: update Maestro story state
   - For description changes: show diff, ask user to confirm
   - For new cards: ask if they should be added as stories

5. Then push Maestro state to the kanban tool:
   - Update any stories whose status changed since last sync

### `move STORY_ID STATUS` — Move a Story

1. Validate STORY_ID exists in `.maestro/stories/`
2. Validate STATUS is one of: pending, in_progress, in_review, done, skipped
3. Update the story's status in Maestro state
4. If kanban sync is enabled, update the external card too

```
[maestro] Moved story 03-frontend to "skipped"

  (i) Updated locally and on GitHub Issues (#45)
```

### `open` — Open in External Provider

If kanban provider is configured and has a web interface:

- GitHub: `gh browse` or open milestone URL
- Asana: open project URL in browser
- Jira: open epic URL in browser
- Linear: open project URL in browser

```bash
# GitHub example
gh browse --repo
```

## Local-Only Board

If no kanban provider is configured, the board works entirely from `.maestro/stories/` files. Status is derived from:

1. Stories with IDs less than `current_story` in state → `done` (unless marked skipped)
2. Story with ID equal to `current_story`:
   - If phase is implement/self_heal → `in_progress`
   - If phase is qa_review → `in_review`
   - If phase is checkpoint/git_craft → `done`
3. Stories with IDs greater than `current_story` → `pending`
4. Stories explicitly marked as skipped in state → `skipped`

This means the board always works, even without an external kanban tool.
