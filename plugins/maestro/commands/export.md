---
name: export
description: "Export session data as JSON, CSV, or Markdown report — includes stories, costs, QA iterations, model usage, and time per phase"
argument-hint: "[session-id] [--format json|csv|md]"
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
  - Write
  - Skill
---

# Maestro Export

Export session data for analysis and team sharing.

## Usage

```
/maestro export                           # Export current session as markdown
/maestro export --format json             # Export as JSON
/maestro export --format csv              # Export as CSV
/maestro export [session-id]              # Export a specific session
/maestro export --output report.md        # Write to specific file
```

## Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `session-id` | current | Session to export (from build-log) |
| `--format` | `md` | Output format: `json`, `csv`, or `md` |
| `--output` | stdout | Write to file instead of displaying |
| `--include-diffs` | false | Include git diffs for each story |

## Execution Steps

### Step 1: Gather Session Data

Read from these sources:
- `.maestro/state.local.md` — session metadata, story statuses
- `.maestro/logs/build-log.jsonl` — build events and timings
- `.maestro/logs/model-decisions.jsonl` — model usage per story
- `.maestro/logs/daemon-history.jsonl` — iteration history (if daemon session)
- `.maestro/trust.yaml` — QA pass rates and trust metrics

### Step 2: Compute Analytics

For each story:
- Total tokens used (from token ledger or build log)
- Time from start to completion
- Number of QA iterations
- Model used (initial and final if escalated)
- Self-heal iterations
- Files changed count

Session-level:
- Total stories completed / skipped / failed
- Total tokens across all stories
- Estimated cost (using provider pricing)
- Average time per story
- QA first-pass rate for this session
- Model distribution (% haiku / sonnet / opus)

### Step 3: Format Output

#### Markdown Format (default)

```markdown
# Maestro Session Report

**Feature:** Dashboard with budget tracking
**Session ID:** abc-123
**Date:** 2026-03-19
**Duration:** 2h 15m
**Branch:** feat/dashboard

## Summary

| Metric | Value |
|--------|-------|
| Stories | 7 completed, 0 skipped, 0 failed |
| Total Tokens | 247,800 |
| Estimated Cost | $4.82 |
| Avg Time/Story | 19m 17s |
| QA First-Pass | 71% (5/7) |

## Stories

| # | Story | Status | Tokens | Time | QA | Model |
|---|-------|--------|--------|------|----|-------|
| 1 | Data schema | Done | 18.2K | 8m | 1x | haiku |
| 2 | API routes | Done | 34.1K | 15m | 2x | sonnet |
| 3 | Frontend UI | Done | 48.0K | 22m | 3x | opus |
| ... | ... | ... | ... | ... | ... | ... |

## Model Usage

| Model | Dispatches | Tokens | Cost |
|-------|-----------|--------|------|
| haiku | 3 (43%) | 42.1K | $0.06 |
| sonnet | 3 (43%) | 98.4K | $0.44 |
| opus | 1 (14%) | 107.3K | $4.32 |

## Timeline

(Mermaid gantt diagram if --include-diffs not set)
```

#### JSON Format

```json
{
  "session_id": "abc-123",
  "feature": "Dashboard with budget tracking",
  "started_at": "2026-03-19T10:30:00Z",
  "completed_at": "2026-03-19T12:45:00Z",
  "stories": [...],
  "metrics": {...},
  "model_usage": {...}
}
```

#### CSV Format

One row per story:
```csv
story_id,title,status,tokens,time_seconds,qa_iterations,model,cost_estimate
01-data-schema,Data schema,done,18200,480,1,haiku,0.02
```

### Step 4: Output

- If `--output` specified: write to file and confirm
- Otherwise: display to user

## Error Handling

| Condition | Action |
|-----------|--------|
| No active session and no session-id | Show: "No session data found. Run /maestro to start a session." |
| Session-id not found in build-log | Show: "Session [id] not found. Use /maestro history to list sessions." |
| Missing data source files | Export with available data, note "(partial — missing [source])" |
| Write permission denied | Fall back to stdout |

## See Also

- `/maestro history` — List past sessions
- `/maestro dashboard` — Real-time session view
- `/maestro retro` — Retrospective analysis
