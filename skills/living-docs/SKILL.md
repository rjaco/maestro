---
name: living-docs
description: "Update Maestro's living documentation (.maestro/state.md, roadmap.md, trust.yaml) after story completion, milestone changes, or feature ships."
effort: medium
maxTurns: 5
---

# living-docs

## Purpose

The project's documentation should always reflect reality. After each meaningful change, the living docs are updated so any agent — or human — can understand the current state without archaeology. Living docs are the project's persistent memory. They bridge sessions and agent instances.

## Update Triggers

| Trigger | Documents to Update | Notes |
|---------|--------------------|----|
| Story completed | `state.md`, `trust.yaml`, `token-ledger.md` | Every story, no exceptions |
| Milestone completed (Magnum Opus) | `roadmap.md`, `state.md`, `trust.yaml` | Timestamp the completion date |
| Feature shipped (PR merged) | `state.md`, `trust.yaml` | Mark feature as live, not just completed |
| Story rejected by QA | `trust.yaml` | Increment `stories_rejected`, record reason |
| Architecture decision made | `architecture.md` (if exists), `state.md` | Add to "What Works" with design rationale |
| Known issue discovered | `state.md` | Add to "What's Broken" immediately |
| Known issue resolved | `state.md` | Remove from "What's Broken", do not archive |
| Session starts on a stale project | `state.md` | Update "Current Focus" to reflect new goal |

## Document-Specific Update Rules

### state.md

- **What Changes:** "What Works" grows with new features. "What's Broken" gains new issues and loses resolved ones. "Current Focus" reflects the live next item.
- **What Never Changes:** Completed work in "What Works" is permanent. Do not rename or restructure past entries when adding new ones.
- **Format:** Concise bullet points only. No prose. No nested bullets deeper than two levels. One line per item.
- **Staleness Rule:** If the last update was more than 5 stories ago, do a full review before appending.

```markdown
## What Works
- Feature X: brief description of current capability
- Feature Y: what it does and any key constraints

## What's Broken / Known Issues
- Issue Z: what fails and under what conditions

## Current Focus
- Next story or milestone in progress
```

### roadmap.md

- **What Changes:** Milestone status (planned → in progress → completed), completion dates, actual vs. estimated story counts.
- **What Never Changes:** Original milestone descriptions and acceptance criteria. Record slippage as a note, not by rewriting the original plan.
- **Format:** Table or heading-per-milestone. Each milestone block must have: status, planned date, actual date (once complete), story count.
- **Staleness Rule:** Update within the same session a milestone closes. Never carry over to the next session.

```markdown
## Milestone: [Name]
Status: completed
Planned: 2026-02-01
Completed: 2026-02-14
Stories: 8 completed, 0 rejected
Notes: Delivered on time. Auth story required one QA revision.
```

### trust.yaml

- **What Changes:** Numeric metrics after every story. Trust level may change after metrics cross a threshold (see trust system docs).
- **What Never Changes:** The `created` timestamp and `project` field.
- **Format:** Update individual fields in place. Do not restructure the file.
- **Staleness Rule:** Must be updated within the same agent turn that processes a story outcome.

```yaml
metrics:
  qa_first_pass_rate: 0.85    # stories approved on first QA review
  test_coverage: 0.92         # percentage of acceptance criteria with tests
  stories_completed: 14       # running count
  stories_rejected: 2         # running count of QA rejections
  avg_story_turns: 4.3        # average turns per story
```

### token-ledger.md

- **What Changes:** Token usage and cost per story, running totals.
- **What Never Changes:** Individual session rows once written.
- **Format:** Append a new row per story. Never edit past rows.

## Conflict Resolution

When multiple stories complete in the same session and both update the same document:

1. **Process sequentially.** Update state.md after story 1 completes, then again after story 2. Do not batch.
2. **For state.md conflicts:** The later story's update wins for "Current Focus". "What Works" and "What's Broken" are additive — both changes apply.
3. **For trust.yaml conflicts:** Recompute metrics from the running totals. Do not attempt a merge of two in-flight states.
4. **For roadmap.md conflicts:** A milestone cannot be marked complete by two stories simultaneously. The last story to close the milestone writes the completion record; the prior story's update writes "N of M stories complete."
5. **For token-ledger.md conflicts:** Append both rows. Running totals recalculate from the appended row.

If a conflict cannot be resolved by these rules, preserve both changes, mark the section with `<!-- CONFLICT: review needed -->`, and report to the orchestrator.

## Archival Policy

Living docs accumulate over time. To keep files scannable:

| Document | Archive Threshold | Archive Location | What Gets Archived |
|----------|------------------|-----------------|-------------------|
| `state.md` | File exceeds 500 lines | `.maestro/archive/state-{year-month}.md` | Everything except the last 3 milestones' worth of entries |
| `roadmap.md` | More than 10 completed milestones | `.maestro/archive/roadmap-{year}.md` | Milestones completed more than 6 months ago |
| `token-ledger.md` | File exceeds 300 rows | `.maestro/archive/token-ledger-{year-q}.md` | Rows older than current quarter |
| `trust.yaml` | Never archived | — | Metrics are aggregate; no archival needed |

**Archive rules:**
- Always keep at least the last 3 milestones in roadmap.md, even if they are old.
- Archive files are append-only. Never delete archived data.
- When creating an archive file, add a header: `# Archived: {original filename} — up to {date}`.
- Update the original file's header to include: `# [Archived content in .maestro/archive/{file}]`.

## Document Templates

Use these templates when creating a document for the first time.

### state.md template

```markdown
# Project State

_Last updated: {date} after story: {story-title}_

## What Works
- (nothing yet)

## What's Broken / Known Issues
- (none)

## Current Focus
- {first story or milestone}
```

### roadmap.md template

```markdown
# Roadmap

## Milestone: {name}
Status: planned
Planned: {date}
Completed: —
Stories: 0 completed

### Acceptance Criteria
- {criterion 1}
- {criterion 2}
```

### trust.yaml template

```yaml
project: {project-name}
created: {date}
trust_level: 1
metrics:
  qa_first_pass_rate: 1.0
  test_coverage: 0.0
  stories_completed: 0
  stories_rejected: 0
  avg_story_turns: 0
```

### token-ledger.md template

```markdown
# Token Ledger

| Date | Story | Input Tokens | Output Tokens | Cost (USD) | Running Total |
|------|-------|-------------|--------------|-----------|---------------|
```

## Integration

- Called by dev-loop at CHECKPOINT phase after story close
- Called by ship skill after PR creation (marks feature as shipped)
- Called by retrospective after analysis
- Called by opus-loop between milestones

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/state.md"
  required_sections:
    - "## What Works"
    - "## What's Broken / Known Issues"
    - "## Current Focus"
```
