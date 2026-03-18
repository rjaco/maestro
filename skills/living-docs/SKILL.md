---
name: living-docs
description: "Update Maestro's living documentation (.maestro/state.md, roadmap.md) after story completion or milestone changes."
---

# living-docs

## Purpose

The project's documentation should always reflect reality. After each meaningful change, the living docs are updated so any agent — or human — can understand the current state without archaeology.

## When to Update

| Trigger | What to update |
|---------|---------------|
| Story completed | `.maestro/state.md` — what works, what's new, current focus |
| Milestone completed (Magnum Opus) | `roadmap.md` — milestone status, completion date |
| Feature shipped | `trust.yaml` — metrics (qa_first_pass_rate, test_coverage, etc.) |

## state.md Format

Concise bullet points. No prose. Three sections:

```markdown
## What Works
- Feature X: brief description of current capability

## What's Broken / Known Issues
- Issue Y: what fails and under what conditions

## Current Focus
- Next story or milestone in progress
```

## Update Rules

- **Read before writing.** Always read the previous state.md to maintain continuity.
- **Never overwrite.** Append new items or update existing entries in place.
- **Remove resolved issues.** When a "What's Broken" item is fixed, remove it — don't leave stale entries.
- **Timestamp milestones.** When updating roadmap.md, include the completion date.
- **Keep it scannable.** One line per item. No nested bullets deeper than two levels.

## trust.yaml Updates

After each feature, update the relevant metrics:

```yaml
metrics:
  qa_first_pass_rate: 0.85    # stories approved on first QA review
  test_coverage: 0.92         # percentage of acceptance criteria with tests
  stories_completed: 14       # running count
  stories_rejected: 2         # running count of QA rejections
```

## Continuity

Living docs are the project's memory. They bridge sessions and agent instances. Write them as if the next reader has zero context about what just happened.

## Documents Managed

| Document | Updated When | What Changes |
|----------|-------------|--------------|
| `.maestro/state.md` | After each feature | Features completed, current focus |
| `.maestro/roadmap.md` | After each milestone (Opus) | Milestone status, completion dates |
| `.maestro/trust.yaml` | After each story | QA rate, trust level, commit scores |
| `.maestro/token-ledger.md` | After each story | Token usage, cost data |

## Rules

1. Read before writing — never overwrite, always append/update in place
2. Remove resolved issues from state
3. Timestamp all milestone completions
4. Never delete history — mark as completed, not removed
5. Keep file sizes manageable — archive old sessions if > 500 lines

## Integration

- Called by dev-loop at CHECKPOINT phase
- Called by ship skill after PR creation
- Called by retrospective after analysis
- Called by opus-loop between milestones

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/state.md"
  required_sections:
    - "## Features Completed"
    - "## Current Session"
    - "## History"
```
