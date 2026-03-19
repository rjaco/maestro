---
name: session-export
description: "Export session data as JSON, CSV, or Markdown. Gathers from build-log, token-ledger, model-decisions, and trust metrics."
---

# Session Export

Aggregates session data from multiple Maestro log sources and formats it for export.

## Data Sources

| Source | Path | Contains |
|--------|------|----------|
| State | `.maestro/state.local.md` | Session metadata, story list |
| Build Log | `.maestro/logs/build-log.jsonl` | Event timeline, phase durations |
| Model Decisions | `.maestro/logs/model-decisions.jsonl` | Model selection per dispatch |
| Token Ledger | `.maestro/logs/token-ledger.jsonl` | Per-story token usage |
| Trust | `.maestro/trust.yaml` | QA pass rates |
| Daemon History | `.maestro/logs/daemon-history.jsonl` | Iteration history |

## Aggregation Logic

### Per-Story Metrics

For each story in state.local.md:
1. Find all build-log entries with matching story ID
2. Sum token usage from token-ledger entries
3. Count QA iterations (entries with phase=qa_review)
4. Determine time span (first validate → last checkpoint)
5. Get model from model-decisions (use final_model)

### Session Metrics

Aggregate across all stories:
- `total_tokens`: sum of all story tokens
- `estimated_cost`: compute using provider pricing from `providers/[name].md`
- `avg_time_per_story`: total duration / completed stories
- `qa_first_pass_rate`: stories with qa_iterations=1 / total completed
- `model_distribution`: count dispatches per model

## Output Contract

```yaml
output_contract:
  formats: [json, csv, md]
  required_fields:
    - session_id
    - feature
    - started_at
    - stories (array)
    - metrics (object)
  writes:
    - "{output_path}" (if --output specified)
```

## Integration

- Invoked by `/maestro export` command
- Data shared with `/maestro retro` for retrospective analysis
- JSON format consumed by external tools and dashboards
