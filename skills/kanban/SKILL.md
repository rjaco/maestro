---
name: kanban
description: "Bidirectional sync with project management tools (Asana, Jira, Linear, GitHub Issues). Maps Maestro stories to kanban cards and syncs status changes."
---

# Kanban Integration

Bidirectional sync between Maestro stories and external project management tools. Stories flow from Maestro to the kanban board during decomposition, and user edits on the board flow back into the dev process.

## Provider Architecture

This skill is provider-agnostic. It delegates to provider-specific sub-files based on the `integrations.kanban.provider` setting in `.maestro/config.yaml`.

| Provider | Sub-file | Tool Used |
|----------|----------|-----------|
| `github` | `provider-github.md` | `gh` CLI |
| `asana` | `provider-asana.md` | Asana MCP Server |
| `jira` | `provider-jira.md` | Atlassian MCP Server |
| `linear` | `provider-linear.md` | Linear MCP Server |

If no provider is configured, all kanban operations are no-ops (silently skip).

## Concept Mapping

| Maestro Concept | GitHub Issues | Asana | Jira | Linear |
|-----------------|--------------|-------|------|--------|
| Feature | Milestone | Section | Epic | Project |
| Story | Issue | Task | Story/Issue | Issue |
| Story status | Label | Section/Custom field | Status | Workflow state |
| Milestone (Opus) | Milestone | Project | Epic | Cycle |
| Acceptance criteria | Issue body checklist | Task description | Description | Description |
| Story type | Label | Tag | Issue type | Label |
| Priority | — | Priority | Priority | Priority |

## Status Mapping

| Maestro Status | Kanban Column |
|---------------|---------------|
| `pending` | Backlog / To Do |
| `in_progress` | In Progress |
| `in_review` | In Review |
| `done` | Done |
| `skipped` | Cancelled / Won't Do |
| `blocked` | Blocked (if supported) |

## Operations

### create_feature(name, description)

Called when Maestro starts a new feature session. Creates the container for stories in the kanban tool.

**Input:** Feature name and description from `/maestro` invocation.
**Output:** Feature ID (stored in `.maestro/state.local.md` as `kanban_feature_id`).

### create_stories(feature_id, stories[])

Called after decomposition (Step 9 of `/maestro`). Creates kanban cards for all stories.

**Input:** Feature ID + array of story objects (title, description, acceptance criteria, type, depends_on).
**Output:** Map of story_id → kanban_card_id (stored in each story's frontmatter as `kanban_id`).

For each story:
1. Create the card/issue/task with title and acceptance criteria as body
2. Set status to "Backlog" / "To Do"
3. Add type label (backend, frontend, fullstack, infrastructure, test)
4. Set dependency info in description if the tool supports it
5. Store the kanban card ID in the story file's frontmatter

### update_story_status(story_id, status)

Called at each CHECKPOINT phase in the dev-loop. Updates the card's status/column.

**Input:** Story ID + new status (pending, in_progress, in_review, done, skipped, blocked).
**Output:** Confirmation of update.

### sync_from_kanban()

Called before starting each story in the dev-loop. Detects user-initiated changes on the kanban board.

**Process:**
1. Read all cards under the feature container
2. Compare statuses with `.maestro/stories/*.md` frontmatter
3. Detect changes:
   - Story moved to "Cancelled" / "Won't Do" → mark as `skipped` in Maestro
   - Story reordered → flag for user review (don't auto-reorder)
   - New cards added by user → flag as potential new stories
   - Story description/criteria edited → flag for review
4. Return a delta report

**Output:**

```
+---------------------------------------------+
| Kanban Sync                                 |
+---------------------------------------------+

  Changes detected from [provider]:
    (!) Story 03 moved to "Won't Do" on board
    (!) Story 05 description edited on board
    (i) No new cards detected

  [1] Apply changes (skip story 03, review 05)
  [2] Ignore board changes
  [3] Show details
```

### get_board_view()

Called by `/maestro board`. Returns a text representation of the current board state.

**Output:**

```
BACKLOG          IN PROGRESS      IN REVIEW        DONE
-----------      -----------      -----------      -----------
04-tests         03-frontend                       01-schema
05-middleware                                       02-api-routes
```

### close_feature(feature_id)

Called when a feature is complete (Step 12 of `/maestro`). Closes the container (milestone/section/epic).

## Integration Points

### In Decompose Skill

After stories are generated, if kanban sync is enabled:

```
# After creating story files
if config.integrations.kanban.sync_enabled:
    kanban.create_feature(feature_name, feature_description)
    kanban.create_stories(feature_id, stories)
```

### In Dev-Loop Skill

At phase transitions:

```
# Before starting a story
if config.integrations.kanban.sync_enabled:
    delta = kanban.sync_from_kanban()
    if delta.has_changes:
        present changes to user, wait for decision

# At IMPLEMENT start
kanban.update_story_status(story_id, "in_progress")

# At QA REVIEW start
kanban.update_story_status(story_id, "in_review")

# At CHECKPOINT (story done)
kanban.update_story_status(story_id, "done")

# On skip
kanban.update_story_status(story_id, "skipped")
```

### In Ship Skill

When creating a PR:

```
if config.integrations.kanban.sync_enabled:
    kanban.close_feature(feature_id)
```

## Error Handling

| Error | Action |
|-------|--------|
| MCP server not responding | Warn user, continue without sync |
| Card creation fails | Log error, continue without kanban ID |
| Sync conflict (simultaneous edits) | Present both versions, let user decide |
| Rate limit hit | Back off and retry once, then warn |
| Provider not configured | Silent no-op |

All kanban operations are non-blocking — if they fail, the dev-loop continues. Kanban is an enhancement, not a dependency.

## Configuration

In `.maestro/config.yaml`:

```yaml
integrations:
  kanban:
    provider: github          # asana | jira | linear | github | null
    sync_enabled: true        # auto-sync stories with board
    project_id: null          # provider-specific project/board ID
    auto_sync_interval: checkpoint  # checkpoint | phase | manual
```
