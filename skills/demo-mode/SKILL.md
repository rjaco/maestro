---
name: demo-mode
description: "Populates all Maestro displays with realistic sample data when /maestro demo runs, and provides a fallback pattern for any command when real data sources are unavailable (no state file, no telemetry, no trust.yaml)."
---

# Demo Mode

Provides a demo execution path for Maestro: either as an explicit showcase (`/maestro demo`) or as a silent fallback when real data is missing. Every display command (dashboard, viz, status, history) checks for demo mode before erroring on absent data.

## Activation

### Explicit Demo

```
/maestro demo
```

Sets `MAESTRO_DEMO=true` in the current session context and populates all displays with the sample data from `templates/demo-data.yaml`.

### Silent Fallback

Any display command activates demo fallback automatically when its required data source is unavailable:

| Command | Required Source | Fallback Trigger |
|---------|----------------|-----------------|
| `/maestro dashboard` | `.maestro/state.local.md` | File absent or `active: false` |
| `/maestro viz` | `.maestro/logs/costs.jsonl` | File absent or empty |
| `/maestro status` | `.maestro/state.local.md` | File absent |
| `/maestro history` | `.maestro/logs/audit.jsonl` | File absent or empty |

When fallback triggers, prefix the display with a single line:

```
[demo] No live data — showing sample project (SaaS analytics dashboard)
```

Do not error. Do not explain at length. Render the demo display and move on.

## Demo Data Source

All demo data lives in `templates/demo-data.yaml`. Read that file to populate displays — do not hardcode values in skill logic.

```yaml
# How to read demo data
demo_data_file: templates/demo-data.yaml
```

## Display Behavior

### Dashboard (demo)

Render the standard dashboard format (see `skills/dashboard/SKILL.md`) using demo data:

```
[demo] No live data — showing sample project (SaaS analytics dashboard)
+--------------------------------------------------+
| Maestro — Milestone 3/5: Core Features           |
+--------------------------------------------------+
| Stories   ████████████░░░░ 4/6 (67%)             |
| Phase     QA Review                               |
| Spend     ~$6.20 (haiku: $0.80, sonnet: $4.40,   |
|            opus: $1.00)                            |
| QA Rate   75% first-pass                          |
| ETA       ~18 min remaining                       |
+--------------------------------------------------+
```

### Status (demo)

Render a status summary using demo session, milestone, and story data from `templates/demo-data.yaml`.

### History (demo)

Show the demo agent dispatch history (last 5 dispatches) from `templates/demo-data.yaml`.

### Viz (demo)

Render cost and token charts using demo breakdown data from `templates/demo-data.yaml`.

## Demo Data Coverage

`templates/demo-data.yaml` provides data for:

- A 5-milestone project at milestone 3 of 5
- Milestone 3 has 6 stories; 4 are complete
- Cost breakdown by model across the session
- QA pass/fail history for the 4 completed stories
- Agent dispatch history (last 5 dispatches with model, role, cost, outcome)
- Trust scores (if `trust.yaml` integration is active)

## Integration Points

- **dashboard/SKILL.md** — checks `MAESTRO_DEMO` or absent state before rendering
- **viz/SKILL.md** — checks `MAESTRO_DEMO` or absent costs before rendering
- **token-ledger/SKILL.md** — demo data provides fallback token totals
- **audit-log/SKILL.md** — demo data provides fallback dispatch history
- **prompt-inject/SKILL.md** — when demo mode is active, inject demo session context

## Output Contract

```yaml
output_contract:
  writes: none
  reads:
    - templates/demo-data.yaml
  side_effects: terminal output only
  sets_env: MAESTRO_DEMO=true (session scope, explicit demo only)
```

## Error Handling

If `templates/demo-data.yaml` is itself missing:

1. Emit: `[demo] Demo data file not found at templates/demo-data.yaml`
2. Show a hardcoded one-line fallback: `Maestro — M3/5 | Story 4/6 | Phase: QA Review | Spend: ~$6.20`
3. Do not crash.

The hardcoded fallback exists only as a last resort. The demo data file should always be present in any Maestro installation.
