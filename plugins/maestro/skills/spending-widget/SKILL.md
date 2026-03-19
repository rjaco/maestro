---
name: spending-widget
description: "Standalone spending tracker widget. Reads .maestro/config.yaml for autonomy mode and limits, and .maestro/spending-log.yaml for action receipts. Renders ASCII progress bars and recent action history."
---

# spending-widget

## Purpose

Visualize autonomous action spending against configured limits. Show mode, budget utilization with ASCII progress bars, action outcome breakdown, and a recent action log. Callable standalone or embedded in the dashboard.

## Data Sources

- `.maestro/config.yaml` — autonomy mode and per-action/session/day limits
- `.maestro/spending-log.yaml` — action receipts (outcome, description, cost, timestamp)

If `config.yaml` is missing or has no `autonomy` section, show:
```
(i) Autonomy not configured. Run /maestro autonomy <mode> to enable.
```

If `spending-log.yaml` does not exist, show spending fields as `no data`.

## Config Schema Expected

```yaml
autonomy:
  mode: tiered          # tiered | auto | manual | off
  limits:
    per_action: 50.00   # max cost per single action (USD)
    per_session: 500.00 # max total cost per session (USD)
    per_day: 1000.00    # max total cost per calendar day (USD)
```

## Spending Log Schema Expected

```yaml
actions:
  - id: act-001
    timestamp: "2026-03-19T14:10:00Z"
    description: "Vercel deploy"
    cost: 0
    outcome: auto       # auto | approved | denied
  - id: act-002
    timestamp: "2026-03-19T14:05:00Z"
    description: "Domain purchase"
    cost: 12.99
    outcome: approved
```

## Progress Bar Rendering

ASCII progress bars are 10 characters wide using `█` (U+2588) for filled and `░` (U+2591) for empty:

```
Formula: filled = floor(percentage / 10), empty = 10 - filled
```

Examples:
- 9%  → `█░░░░░░░░░`
- 12% → `█░░░░░░░░░`
- 50% → `█████░░░░░`
- 86% → `█████████░`
- 0%  → `░░░░░░░░░░`
- 100%→ `██████████`

## Standalone Output

When invoked directly (e.g., `/maestro spending`):

```
+---------------------------------------------+
| Spending Tracker                            |
+---------------------------------------------+
  Mode: tiered (auto under $50, confirm above)

  Limits:
    Per-action:   $50.00
    Per-session:  ████░░░░░░  $45.50 / $500  (9%)
    Per-day:      █░░░░░░░░░  $120 / $1,000  (12%)

  Today's Actions (14 total):
    Auto-approved:   12  ██████████████████  (86%)
    User-approved:    1  ██                  (7%)
    Denied:           1  ██                  (7%)

  Recent:
    14:10  [AUTO]     Vercel deploy         $0
    14:08  [AUTO]     DNS record update     $0
    14:05  [APPROVED] Domain purchase       $12.99
    14:02  [DENIED]   Email campaign        blocked
    14:00  [AUTO]     AWS S3 list           $0

  (i) Change mode: /maestro autonomy <mode>
  (i) Adjust limits: /maestro autonomy limits
```

## Mode Description Line

Append a parenthetical description after the mode name:

| Mode | Description |
|------|-------------|
| `tiered` | `(auto under $N, confirm above)` where N = per_action limit |
| `auto` | `(all actions auto-approved)` |
| `manual` | `(all actions require confirmation)` |
| `off` | `(autonomy disabled)` |

## Action Count Bars

The action count bars in "Today's Actions" use 18-character-wide bars (not 10). Fill proportionally to percentage of total actions:

```
filled = floor(percentage / 100 * 18)
```

## Recent Actions Table

Show the last 5 actions from `spending-log.yaml`, sorted newest first.

Column format:
- Time: `HH:MM` (local time from timestamp)
- Outcome: `[AUTO]`, `[APPROVED]`, or `[DENIED]` — padded to 10 chars
- Description: truncated at 22 chars if needed, left-aligned in 22-char field
- Cost: `$N.NN` for non-zero costs, `$0` for zero-cost actions, `blocked` for denied actions

If fewer than 5 actions exist, show only what is available.
If no actions exist, show `(no actions recorded)`.

## Percentage Calculation

```
percentage = floor(spent / limit * 100)
```

Cap display at 100% even if overspent. If overspent, show `(!)` instead of percentage:
```
    Per-session:  ██████████  $520.00 / $500  (!) OVER LIMIT
```

## Integration

- Read by the `dashboard` skill for the Autonomy & Spending section
- Invoked by `/maestro spending` command
- Invoked by `/maestro autonomy status` command
- Updated by the `autonomy-engine` skill after each action execution
