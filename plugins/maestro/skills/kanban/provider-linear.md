---
name: kanban-provider-linear
description: "Linear provider for kanban integration. Uses Linear MCP Server for issue and project management."
---

# Kanban Provider: Linear

Maps Maestro concepts to Linear issues, projects, and cycles using the Linear MCP Server.

## Prerequisites

- Linear MCP Server installed and configured
- MCP tools with `mcp__linear__` prefix available
- Team identifier configured (auto-detected or set via `/maestro config`)

## Concept Mapping

| Maestro | Linear |
|---------|--------|
| Feature | Project |
| Story | Issue (sub-issue of project) |
| Status | Workflow state (Backlog, In Progress, In Review, Done, Cancelled) |
| Story type | Label |
| Acceptance criteria | Issue description with checklist |
| Milestone (Opus) | Cycle |
| Priority | Priority (Urgent, High, Medium, Low) |

## Operations

### create_feature(name, description)

Create a Linear project:

```
mcp__linear__create_project
  name: "[maestro] {feature_name}"
  description: "{description}"
  team_id: {configured_team_id}
```

Return the project ID as feature ID.

### create_stories(feature_id, stories[])

For each story, create a Linear issue:

```
mcp__linear__create_issue
  title: "{story_title}"
  description: |
    ## Acceptance Criteria

    - [ ] {criterion_1}
    - [ ] {criterion_2}

    ## Dependencies
    {depends_on}

    ## Context
    {context}

    ---
    *Managed by Maestro | Story: {story_id} | Type: {story_type}*
  project_id: {feature_project_id}
  team_id: {configured_team_id}
  state: "Backlog"
  labels: ["{story_type}"]
```

Store the issue ID in the story frontmatter as `kanban_id`.

### update_story_status(story_id, status)

Update the issue's workflow state:

```
mcp__linear__update_issue
  issue_id: {kanban_id}
  state: "{mapped_workflow_state}"
```

Status mapping:
- `pending` → Backlog
- `in_progress` → In Progress
- `in_review` → In Review
- `done` → Done
- `skipped` → Cancelled

### sync_from_kanban()

Read all issues in the project:

```
mcp__linear__list_issues
  project_id: {feature_project_id}
```

Compare issue states with Maestro story states. Detect:
1. State changes (user moved issue on board)
2. Issue cancellation
3. New issues added by user
4. Description edits

Return delta report.

### get_board_view()

Fetch all project issues grouped by workflow state. Format as text columns.

### close_feature(feature_id)

Mark the project as completed:

```
mcp__linear__update_project
  project_id: {feature_project_id}
  state: "completed"
```

## Error Handling

- If Linear MCP not available: report with setup instructions
- If team_id not configured: list available teams, ask user to choose
- All operations non-blocking — failure does not stop the dev-loop
