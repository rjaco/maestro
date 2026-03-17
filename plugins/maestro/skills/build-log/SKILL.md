---
name: build-log
description: "Session replay and build journal. Records full execution history for review and export."
---

# Build Log

Records the full journey of each feature or milestone — from research through architecture, decomposition, implementation, QA, and shipping. Serves as a session replay, cost audit trail, and exportable build narrative.

## When to Write

- After each feature completes (all stories done)
- After each milestone completes in Opus mode
- After a session is aborted (partial log)

## Log Location

`.maestro/logs/YYYY-MM-DD-feature-slug.md`

For Opus milestones: `.maestro/logs/YYYY-MM-DD-MN-milestone-slug.md`

## Log Format

```markdown
# Build Log: [feature/milestone name]

**Date:** [YYYY-MM-DD]
**Session:** [session_id, first 8 chars]
**Duration:** [start time] — [end time] ([elapsed])
**Mode:** [yolo/checkpoint/careful]
**Total cost:** ~$[N.NN] ([N]K tokens)

## Research

[If research was performed, summarize key findings and how they influenced the approach.]
[Skip this section if no research was done.]

## Architecture

[If architecture decisions were made, document the key choices and rationale.]
[Skip this section if the feature followed existing patterns.]

## Stories

| # | Title | Model | Tokens | QA Rounds | Time |
|---|-------|-------|--------|-----------|------|
| 1 | [title] | sonnet | [N]K | 1 | [N]m |
| 2 | [title] | sonnet | [N]K | 2 | [N]m |
| 3 | [title] | opus | [N]K | 1 | [N]m |
| | **Total** | | **[N]K** | **avg [N]** | **[N]m** |

## Implementation Journey

### Story 1: [title]
- Approach: [what the implementer did]
- QA feedback: [if rejected, what was the feedback]
- Self-heal: [if checks failed, what was fixed]
- Outcome: [final status]

### Story 2: [title]
[repeat for each story]

## QA Summary

- First-pass approval rate: [N]%
- Total QA iterations: [N]
- Common issues: [patterns in QA feedback]
- Self-heal success rate: [N]%

## Cost Breakdown

| Phase | Tokens | Est. Cost |
|-------|--------|-----------|
| Research | [N]K | $[N] |
| Decompose | [N]K | $[N] |
| Implement | [N]K | $[N] |
| Self-heal | [N]K | $[N] |
| QA Review | [N]K | $[N] |
| Git Craft | [N]K | $[N] |
| **Total** | **[N]K** | **$[N]** |

## Retrospective Notes

- What went well: [observations]
- What could improve: [friction points]
- Lessons: [what to carry forward]

## Commits

- `[hash]` [commit message]
- `[hash]` [commit message]

## Files Changed

- Created: [list of new files]
- Modified: [list of modified files]
```

## Export Format

The build log is designed to be readable as-is, but can also be reformatted for:

- **Blog post:** Strip the cost breakdown and QA details. Keep the journey narrative and architecture decisions. Add an introduction and conclusion.
- **Team update:** Keep the story table and QA summary. Strip implementation details.
- **Cost report:** Keep the cost breakdown. Strip everything else.

To export, read the log file and reformat based on the requested format. Do not create separate export files unless the user requests it.

## Aggregation

If `.maestro/logs/` contains multiple logs, the build-log skill can generate a summary:

```markdown
# Build History

| Date | Feature | Stories | Cost | QA Rate | Time |
|------|---------|---------|------|---------|------|
| [date] | [name] | [N] | $[N] | [N]% | [N]m |
```

This summary is useful for tracking project velocity and cost trends over time.
