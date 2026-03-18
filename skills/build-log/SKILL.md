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

## Export Modes

Build logs can be exported in four structured formats for sharing, publishing, or programmatic consumption. Exports are saved to `.maestro/exports/`.

### Triggering an Export

**Manual export via orchestrator command:**
```
/maestro history --export html
/maestro history --export blog
/maestro history --export summary
/maestro history --export json
```

**Auto-export on feature completion** (if configured in `.maestro/config.yml`):
```yaml
build_log:
  auto_export: [summary, html]
```

When `auto_export` is set, the listed formats are generated automatically each time a feature completes. If not configured, no auto-export occurs.

---

### Format A: HTML Report (`--export html`)

Saved to: `.maestro/exports/build-report-{date}-{slug}.html`

A self-contained HTML file suitable for sharing via link or attaching to a PR/issue. No external dependencies — all CSS is inline.

**Structure:**
```
<html>
  <head>
    <!-- Inline CSS: dark/light mode via @media (prefers-color-scheme) -->
    <!-- Print-friendly styles via @media print -->
  </head>
  <body>
    <header>
      Feature name, date, duration, total cost
    </header>

    <nav>
      Table of contents — one link per ## section in the log
    </nav>

    <section id="stories">
      Story table with color-coded status badges:
        green  = approved first pass
        yellow = approved after QA iteration
        red    = required self-heal
    </section>

    <section id="cost">
      Cost breakdown as a CSS bar chart (no JavaScript):
        Each phase rendered as a <div> with width proportional to token count
        Percentages labeled inline
    </section>

    <section id="journey">
      Implementation Journey — each story in a collapsible <details> element
        Summary line: story title + outcome
        Body: approach, QA feedback, self-heal notes
    </section>

    <section id="retrospective">
      Retrospective Notes — plain prose
    </section>

    <footer>
      Generated by Maestro build-log at {timestamp}
    </footer>
  </body>
</html>
```

**Design constraints:**
- Works in any browser without JavaScript
- Print-friendly (collapse open by default when printing)
- Responds to `prefers-color-scheme: dark` and `prefers-color-scheme: light`
- No external fonts, icons, or scripts

---

### Format B: Blog Post (`--export blog`)

Saved to: `.maestro/exports/blog-{date}-{slug}.md`

A narrative markdown file written as "How we built X". Suitable for publishing on a team blog, Dev.to, or internal wiki.

**Structure:**
```markdown
---
title: "How We Built [feature name]"
date: [YYYY-MM-DD]
tags: [engineering, build-log, maestro]
---

## Introduction
[One paragraph: what the feature is and why it was built]

## The Approach
[Architecture decisions rewritten as prose — the "why" behind the design]

## The Journey
[Implementation Journey section rewritten as a narrative story arc:
  - What was attempted first
  - Where friction appeared (QA rejections, self-heal cycles)
  - How it was resolved]

## Key Code Changes
[Up to 3 representative code snippets from commits — the most illustrative diffs]

## Lessons Learned
[Retrospective Notes reformatted as prose takeaways]

## By the Numbers
| Metric | Value |
|--------|-------|
| Stories shipped | [N] |
| Total time | [N]m |
| QA first-pass rate | [N]% |
| Total cost | $[N] |
```

**Generation rules:**
- Strip raw cost tables and QA iteration counts (keep aggregated metrics only)
- Rewrite bullet-point sections as flowing prose
- Frontmatter must be valid YAML

---

### Format C: Summary (`--export summary`)

Saved to: `.maestro/exports/summary-{date}-{slug}.md`

A one-page executive summary designed for pasting into Slack, Discord, or a standup message.

**Structure:**
```markdown
# [Feature Name] — Build Summary

**Shipped:** [YYYY-MM-DD] | **Duration:** [N]m | **Cost:** ~$[N]

## What Was Built
[2–3 sentences from the feature description]

## Key Decisions
- [Decision 1 from Architecture section]
- [Decision 2]
- [Decision 3, max]

## Metrics
- Stories: [N] shipped, [N]% approved first pass
- Self-heal cycles: [N]
- Total tokens: [N]K

## Commits
[Commit list — hash + message, one per line]
```

**Generation rules:**
- Hard limit: fits in a single screen (aim for under 40 lines)
- No collapsible sections — everything visible at a glance
- Omit Implementation Journey details entirely
- Keep commit list complete

---

### Format D: JSON (`--export json`)

Saved to: `.maestro/exports/data-{date}-{slug}.json`

Machine-readable structured data for dashboards, analytics pipelines, or cross-feature aggregation.

**Schema:**
```json
{
  "feature": "string",
  "date": "YYYY-MM-DD",
  "session_id": "string",
  "duration_minutes": "number",
  "mode": "yolo | checkpoint | careful",
  "cost": {
    "total_usd": "number",
    "total_tokens_k": "number",
    "breakdown": {
      "research": { "tokens_k": "number", "cost_usd": "number" },
      "decompose": { "tokens_k": "number", "cost_usd": "number" },
      "implement": { "tokens_k": "number", "cost_usd": "number" },
      "self_heal": { "tokens_k": "number", "cost_usd": "number" },
      "qa_review": { "tokens_k": "number", "cost_usd": "number" },
      "git_craft":  { "tokens_k": "number", "cost_usd": "number" }
    }
  },
  "stories": [
    {
      "index": "number",
      "title": "string",
      "model": "string",
      "tokens_k": "number",
      "qa_rounds": "number",
      "time_minutes": "number",
      "outcome": "approved | approved_after_qa | self_healed"
    }
  ],
  "qa_summary": {
    "first_pass_rate_pct": "number",
    "total_iterations": "number",
    "self_heal_success_rate_pct": "number"
  },
  "commits": [
    { "hash": "string", "message": "string" }
  ],
  "files_changed": {
    "created": ["string"],
    "modified": ["string"]
  },
  "retrospective": {
    "went_well": ["string"],
    "could_improve": ["string"],
    "lessons": ["string"]
  },
  "exported_at": "ISO8601 timestamp"
}
```

**Generation rules:**
- All numeric fields must be numbers, not strings
- Missing data uses `null`, not empty string or `0`
- `exported_at` reflects when the export was generated, not when the build ran

## Aggregation

If `.maestro/logs/` contains multiple logs, the build-log skill can generate a summary:

```markdown
# Build History

| Date | Feature | Stories | Cost | QA Rate | Time |
|------|---------|---------|------|---------|------|
| [date] | [name] | [N] | $[N] | [N]% | [N]m |
```

This summary is useful for tracking project velocity and cost trends over time.

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/logs/{session-id}.md"
  required_sections:
    - "## Session Info"
    - "## Story Log"
  required_frontmatter:
    session_id: string
    feature: string
    started_at: date
```
