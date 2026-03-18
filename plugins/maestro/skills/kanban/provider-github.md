---
name: kanban-provider-github
description: "GitHub Issues provider for kanban integration. Uses gh CLI for issue and milestone management."
---

# Kanban Provider: GitHub Issues

Maps Maestro concepts to GitHub Issues using the `gh` CLI. This is the simplest provider and the default fallback when no dedicated kanban tool is configured.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` returns success)
- Current directory is a git repo with a GitHub remote

## Concept Mapping

| Maestro | GitHub |
|---------|--------|
| Feature | Milestone |
| Story | Issue |
| Status | Labels (maestro:pending, maestro:in-progress, maestro:in-review, maestro:done, maestro:skipped) |
| Story type | Labels (type:backend, type:frontend, type:fullstack, type:infra, type:test) |
| Acceptance criteria | Issue body with checklist |

## Label Setup

On first use, create the required labels if they don't exist:

```bash
# Status labels
gh label create "maestro:pending" --color "EDEDED" --description "Maestro: waiting to start" --force
gh label create "maestro:in-progress" --color "0075CA" --description "Maestro: being implemented" --force
gh label create "maestro:in-review" --color "D876E3" --description "Maestro: QA review" --force
gh label create "maestro:done" --color "0E8A16" --description "Maestro: completed" --force
gh label create "maestro:skipped" --color "E4E669" --description "Maestro: skipped" --force

# Type labels
gh label create "type:backend" --color "1D76DB" --force
gh label create "type:frontend" --color "5319E7" --force
gh label create "type:fullstack" --color "006B75" --force
gh label create "type:infra" --color "B60205" --force
gh label create "type:test" --color "FBCA04" --force
```

## Operations

### create_feature(name, description)

Create a GitHub Milestone:

```bash
gh api repos/{owner}/{repo}/milestones \
  --method POST \
  -f title="[maestro] {name}" \
  -f description="{description}" \
  -f state="open"
```

Extract and return the milestone `number` as the feature ID.

### create_stories(feature_id, stories[])

For each story, create a GitHub Issue:

```bash
gh issue create \
  --title "[maestro:{story_id}] {story_title}" \
  --body "{acceptance_criteria_as_checklist}" \
  --label "maestro:pending,type:{story_type}" \
  --milestone "{feature_milestone_number}"
```

The issue body should format acceptance criteria as a GitHub checklist:

```markdown
## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Dependencies

Depends on: #issue_number_1, #issue_number_2

## Context

{context_for_implementer}

---
*Managed by Maestro. Story ID: {story_id}*
```

Store the issue number in the story frontmatter as `kanban_id`.

### update_story_status(story_id, status)

Update labels on the issue:

```bash
# Remove all maestro status labels
gh issue edit {issue_number} --remove-label "maestro:pending,maestro:in-progress,maestro:in-review,maestro:done,maestro:skipped"

# Add new status label
gh issue edit {issue_number} --add-label "maestro:{status}"
```

If status is `done`, also close the issue:

```bash
gh issue close {issue_number}
```

If status is `skipped`, close with "not planned" reason:

```bash
gh issue close {issue_number} --reason "not planned"
```

### sync_from_kanban()

Check for user-initiated changes:

```bash
# List all issues in the milestone
gh issue list --milestone "{milestone_title}" --state all --json number,title,state,labels,body --limit 100
```

Compare each issue's state and labels against Maestro's story files:

1. If issue was closed by user (not by Maestro) → mark story as `skipped`
2. If issue labels changed (status label removed/changed) → flag for review
3. If issue body was edited (checklist items checked/changed) → flag for review
4. If new issues were added to the milestone → flag as potential new stories

### get_board_view()

Fetch all issues and group by status label:

```bash
gh issue list --milestone "{milestone_title}" --state all --json number,title,labels --limit 100
```

Group issues by their `maestro:*` label and format as columns.

### close_feature(feature_id)

Close the milestone:

```bash
gh api repos/{owner}/{repo}/milestones/{milestone_number} \
  --method PATCH \
  -f state="closed"
```

## Error Handling

- If `gh` is not authenticated: report error with `gh auth login` instructions
- If repo has no GitHub remote: report error, suggest adding one
- If label creation fails (permissions): warn and continue without labels
- If issue creation fails: log error, continue with remaining stories
