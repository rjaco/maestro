---
name: kanban-provider-jira
description: "Jira provider for kanban integration. Uses Atlassian Remote MCP Server for issue and board management."
---

# Kanban Provider: Jira

Maps Maestro concepts to Jira issues, epics, and boards using the Atlassian Remote MCP Server.

## Prerequisites

- Atlassian Remote MCP Server installed and configured (OAuth 2.1)
- MCP tools with `mcp__atlassian__` prefix available
- Jira project key configured in `.maestro/config.yaml` as `integrations.kanban.project_id`

## Concept Mapping

| Maestro | Jira |
|---------|------|
| Feature | Epic |
| Story | Story or Task (issue type) |
| Status | Status (To Do, In Progress, In Review, Done) |
| Story type | Issue type or label |
| Acceptance criteria | Description with checklist |
| Milestone (Opus) | Epic or Fix Version |

## Operations

### create_feature(name, description)

Create a Jira Epic:

```
mcp__atlassian__jira_create_issue
  project_key: "{config.project_id}"
  issue_type: "Epic"
  summary: "[maestro] {feature_name}"
  description: "{description}"
```

Return the Epic key (e.g., `PROJ-123`) as feature ID.

### create_stories(feature_id, stories[])

For each story, create a Jira issue linked to the Epic:

```
mcp__atlassian__jira_create_issue
  project_key: "{config.project_id}"
  issue_type: "Story"
  summary: "{story_title}"
  description: |
    h2. Acceptance Criteria

    * {criterion_1}
    * {criterion_2}

    h2. Dependencies
    {depends_on}

    h2. Context
    {context}

    ----
    _Managed by Maestro | Story: {story_id} | Type: {story_type}_
  epic_key: "{feature_epic_key}"
  labels: ["maestro", "{story_type}"]
```

Note: Jira uses wiki markup, not Markdown. Format description accordingly.

Store the issue key in the story frontmatter as `kanban_id`.

### update_story_status(story_id, status)

Transition the issue to the appropriate status:

```
mcp__atlassian__jira_transition_issue
  issue_key: "{kanban_id}"
  transition: "{target_status}"
```

Status mapping (transition names vary by project workflow):
- `pending` → "To Do" or "Backlog"
- `in_progress` → "In Progress"
- `in_review` → "In Review" (if available, otherwise "In Progress")
- `done` → "Done"
- `skipped` → "Done" with resolution "Won't Do"

Note: Jira transitions are workflow-dependent. If the exact transition is not available, list available transitions and pick the closest match.

### sync_from_kanban()

Read all issues in the Epic:

```
mcp__atlassian__jira_search
  jql: "\"Epic Link\" = {epic_key} ORDER BY rank ASC"
```

Compare issue statuses with Maestro story states. Detect changes as per the kanban SKILL.md spec.

### get_board_view()

Search for issues and group by status. Format as text columns.

### close_feature(feature_id)

Mark the Epic as Done:

```
mcp__atlassian__jira_transition_issue
  issue_key: "{epic_key}"
  transition: "Done"
```

## Error Handling

- If Atlassian MCP not available: report with setup instructions
- If project_key not set: prompt user to configure via `/maestro config`
- If transition not available: list available transitions, let user pick
- If issue creation fails (permissions): warn, continue without kanban
- All operations non-blocking
