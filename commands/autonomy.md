---
name: autonomy
description: "Configure autonomy mode, spending limits, and view action approval status"
argument-hint: "[full-auto|tiered|manual|status|limits]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Autonomy

Configure how Maestro handles autonomous actions — which tiers require approval, and what spending limits apply.

## Step 1: Read Config

Read `.maestro/config.yaml`. Extract the `autonomy` section:

```yaml
autonomy:
  mode: tiered              # full-auto | tiered | manual
  spending:
    per_action: 50
    per_session: 500
    per_day: 1000
  notification_level: all
```

If the `autonomy` section is absent, use these defaults and write them to the file:
- mode: `tiered`
- per_action: `50`
- per_session: `500`
- per_day: `1000`
- notification_level: `all`

## Step 2: Read Spending Log

Read `.maestro/spending-log.yaml`. If the file does not exist, treat all totals as 0 and today's action count as 0.

Extract:
- `session_total`
- `day_total`
- `last_reset`
- `actions` list

If `last_reset` is not today's date, reset `day_total` to 0 before displaying.

Count today's actions from the `actions` list where `timestamp` matches today's date:
- Auto-approved: entries where `approved_by: auto`
- User-approved: entries where `approved_by: user`
- Denied: entries where `approved_by: denied` (if any)

Find the most recent action entry for "Last action" display.

## Step 3: Handle Arguments

Check `$ARGUMENTS` for a subcommand.

---

### No arguments — Show dashboard

Display:

```
Autonomy Mode: [mode]
───────────────────────────────
Spending Limits:
  Per-action:  $[per_action].00
  Per-session: $[per_session].00 ($[session_total] used — [pct]%)
  Per-day:     $[per_day].00 ($[day_total] used — [pct]%)

Today's Actions: [count]
  Auto-approved: [n] (T1/T2)
  User-approved: [n] (T2/T3)
  Denied: [n]

Last action: [service] — [action] ($[amount]) — [relative time]
```

Format percentages as whole numbers. Format dollar amounts with 2 decimal places. Use "No actions today" if count is 0.

For relative time: "just now" (<1 min), "N min ago", "N hr ago", "N days ago".

After the display, use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Autonomy Settings"
- Options:
  1. label: "Switch mode", description: "Change to full-auto, tiered, or manual"
  2. label: "Edit limits", description: "Adjust per-action, per-session, or per-day spending limits"
  3. label: "View full status", description: "See detailed spending breakdown"
  4. label: "Done", description: "Close this menu"

If "Switch mode": proceed as `mode` subcommand (show mode options).
If "Edit limits": proceed as `limits` subcommand.
If "View full status": proceed as `status` subcommand.
If "Done": exit.

---

### `full-auto` — Switch to full autonomy

1. Read the current mode. If already `full-auto`:
   ```
   Autonomy mode is already full-auto.
   ```
   Stop here.

2. Warn the user:

   Use AskUserQuestion:
   - Question: "Full-auto mode allows Maestro to execute ALL actions — including irreversible ones like domain purchases, email sends, and cloud resource deletions — without asking for approval. Are you sure?"
   - Header: "Confirm Full-Auto Mode"
   - Options:
     1. label: "Yes, enable full-auto", description: "Maestro will act autonomously on all tiers"
     2. label: "Cancel", description: "Keep current mode"

3. If confirmed:
   - Edit `.maestro/config.yaml` to set `autonomy.mode: full-auto`
   - Display:
     ```
     Autonomy mode set to: full-auto

     Maestro will now execute all actions automatically, including
     irreversible ones. Spending limits still apply as hard stops.

     To revert: /maestro autonomy tiered
     ```

4. If cancelled: display "Mode unchanged." and stop.

---

### `tiered` — Switch to tiered approval

1. If already `tiered`: display "Autonomy mode is already tiered." and stop.

2. Edit `.maestro/config.yaml` to set `autonomy.mode: tiered`

3. Display:
   ```
   Autonomy mode set to: tiered

   T1 (read-only):        auto-approve
   T2 (reversible-paid):  auto under $[per_action] per action
   T3 (irreversible):     always ask for approval

   Spending limits:
     Per-action:  $[per_action]
     Per-session: $[per_session]
     Per-day:     $[per_day]
   ```

---

### `manual` — Switch to manual approval

1. If already `manual`: display "Autonomy mode is already manual." and stop.

2. Edit `.maestro/config.yaml` to set `autonomy.mode: manual`

3. Display:
   ```
   Autonomy mode set to: manual

   T1 (read-only):        auto-approve
   T2 (reversible-paid):  always ask for approval
   T3 (irreversible):     always ask for approval

   Maestro will pause before any non-read-only action.
   ```

---

### `status` — Detailed spending breakdown

Display the full spending report:

```
Autonomy Status
───────────────────────────────────────────────────
Mode:             [mode]
Notification:     [notification_level]

Spending Limits:
  Per-action:   $[per_action].00
  Per-session:  $[per_session].00
  Per-day:      $[per_day].00

Session Spending: $[session_total] / $[per_session] ([pct]%)
  [===========           ] [pct]%

Daily Spending:   $[day_total] / $[per_day] ([pct]%)
  [====                  ] [pct]%

Today's Action Log ([date]):
  Total:         [count] actions
  Auto-approved: [n]
  User-approved: [n]
  Denied:        [n]
  Total cost:    $[day_total]

Recent Actions (last 10):
  [timestamp]  [service]  [action]  $[amount]  [approved_by]
  ...

───────────────────────────────────────────────────
```

For the progress bar, scale to 22 characters. Use `=` for used, space for remaining. Cap display at 100% even if over limit.

If no actions have been recorded, show: "No actions recorded this session."

---

### `limits` — View or edit spending limits

1. Display current limits:

   ```
   Spending Limits (tiered mode — T2 auto-approve thresholds):

     Per-action:   $[per_action].00  (max cost of a single auto-approved T2 action)
     Per-session:  $[per_session].00 (pause when session total reaches this)
     Per-day:      $[per_day].00     (hard stop when daily total reaches this)
   ```

2. Use AskUserQuestion:
   - Question: "Which limit would you like to edit?"
   - Header: "Spending Limits"
   - Options:
     1. label: "Per-action limit ($[per_action])", description: "Max cost of a single auto-approved T2 action"
     2. label: "Per-session limit ($[per_session])", description: "Pause when session spending reaches this"
     3. label: "Per-day limit ($[per_day])", description: "Hard stop when daily spending reaches this"
     4. label: "Done", description: "Close without changes"

3. If a limit is selected, use AskUserQuestion again:
   - Question: "Enter new [limit name] limit in dollars (current: $[value]):"
   - Accept a numeric value.

4. Validate the input:
   - Must be a positive number.
   - per_action must be <= per_session.
   - per_session must be <= per_day.
   - If invalid, show the error and return to the selection menu.

5. Edit `.maestro/config.yaml` to update the chosen limit.

6. Display:
   ```
   [limit name] set to $[new_value].00
   ```

   Then return to the limit selection menu to allow editing more limits. Exit when "Done" is selected.

## Important Notes

- Changes to mode and limits take effect immediately for the next action — they do not affect actions already in progress.
- Spending totals in `.maestro/spending-log.yaml` are always cumulative for the session and the day. They are not reset by changing the mode or limits.
- The `per_day` limit is a hard stop — Maestro cannot override it, even in `full-auto` mode.
- In `full-auto` mode, T3 actions are still logged and the user can review them with `/maestro autonomy status`.
- `notification_level` controls which events trigger external notifications:
  - `all`: every auto-approved and user-approved action
  - `important`: only T2 and T3 actions
  - `critical`: only T3 actions and limit alerts
  - `none`: no notifications (approval UI still appears for T3 in non-full-auto modes)
