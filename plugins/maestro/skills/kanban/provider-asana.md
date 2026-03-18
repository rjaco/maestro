---
name: kanban-provider-asana
description: "Asana provider for kanban integration. Uses Asana MCP Server for task and project management."
---

# Kanban Provider: Asana

Maps Maestro concepts to Asana tasks and sections using the Asana MCP Server.

## Prerequisites

- Asana MCP Server installed and configured
- MCP tools with `mcp__asana__` prefix available
- `integrations.kanban.project_id` set in `.maestro/config.yaml` (Asana project GID)

## Concept Mapping

| Maestro | Asana |
|---------|-------|
| Feature | Section within project |
| Story | Task within section |
| Status | Section (Backlog, In Progress, In Review, Done, Skipped) |
| Story type | Tag |
| Acceptance criteria | Task description with checklist |
| Milestone (Opus) | Section group or separate project |

## Section Setup

On first use for a project, verify these sections exist (create if missing):

| Section | Purpose |
|---------|---------|
| Backlog | Stories not yet started |
| In Progress | Story being implemented |
| In Review | Story in QA review |
| Done | Story completed |
| Skipped | Story skipped or cancelled |

Use Asana MCP tools to list sections and create missing ones:

```
mcp__asana__search_projects  → find project by ID
mcp__asana__get_sections     → list existing sections
mcp__asana__create_section   → create missing sections
```

## Operations

### create_feature(name, description)

Create a section in the configured Asana project:

```
mcp__asana__create_section
  project_id: {config.integrations.kanban.project_id}
  name: "[maestro] {feature_name}"
```

Return the section GID as feature ID.

Then create sub-sections or use existing Backlog/In Progress/Done sections for status tracking.

### create_stories(feature_id, stories[])

For each story, create an Asana task:

```
mcp__asana__create_task
  project_id: {config.integrations.kanban.project_id}
  name: "{story_title}"
  notes: |
    ## Acceptance Criteria

    {criteria_as_checklist}

    ## Dependencies
    {depends_on_list}

    ## Context
    {context_for_implementer}

    ---
    Managed by Maestro | Story: {story_id} | Type: {story_type}
  section: {backlog_section_gid}
```

If available, add subtasks for each acceptance criterion:

```
mcp__asana__create_subtask
  parent_task_id: {task_gid}
  name: "{criterion_text}"
```

Store the task GID in the story frontmatter as `kanban_id`.

### update_story_status(story_id, status)

Move the task to the corresponding section:

```
mcp__asana__update_task
  task_id: {task_gid}
  section: {status_section_gid}
```

Map status to section:
- `pending` → Backlog section
- `in_progress` → In Progress section
- `in_review` → In Review section
- `done` → Done section (also mark task complete)
- `skipped` → Skipped section (also mark task complete)

If status is `done` or `skipped`, mark the task as completed:

```
mcp__asana__update_task
  task_id: {task_gid}
  completed: true
```

### sync_from_kanban()

Read all tasks in the project and compare with Maestro stories:

```
mcp__asana__get_tasks
  project_id: {config.integrations.kanban.project_id}
```

For each task:
1. Match to Maestro story by `kanban_id` in frontmatter
2. Check if section changed (user moved card)
3. Check if task was completed (user marked done)
4. Check if description was edited
5. Check for new unmatched tasks (user-created)

Return delta report.

### get_board_view()

Fetch all tasks grouped by section and format as text columns.

### close_feature(feature_id)

Mark all tasks in the feature section as complete. Optionally archive the section.

## Error Handling

- If Asana MCP not available: report with setup instructions
- If project_id not set: prompt user to set it via `/maestro config`
- If section creation fails: warn, use existing sections
- If task creation fails: log, continue with remaining stories
- All operations are non-blocking — failure does not stop the dev-loop
