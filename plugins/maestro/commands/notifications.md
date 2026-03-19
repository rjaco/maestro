---
name: notifications
description: "Configure notification levels, test channels, and view recent action receipts"
argument-hint: "[levels|test|receipts|mute|unmute]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Notifications

View and configure Maestro notification settings. Manage per-channel levels, send test notifications, and review recent action receipts.

## No Arguments — Show Current Config

Read `.maestro/config.yaml` and display a summary of the notification configuration:

```
+---------------------------------------------+
| Maestro Notifications                       |
+---------------------------------------------+

  Status:   ENABLED  (muted: no)

  Default level:  all

  Channels:
    telegram      CONFIGURED   level: all
    slack         CONFIGURED   level: important
    discord       not set
    pagerduty     not set

  Triggers:
    on_story_complete       true
    on_feature_complete     true
    on_qa_rejection         true
    on_self_heal_failure    true
    on_test_regression      true

  (i) Use /maestro notifications levels   to change per-channel levels
  (i) Use /maestro notifications test     to send a test to all channels
  (i) Use /maestro notifications receipts to view recent action receipts
```

If `notifications.enabled` is false:

```
[maestro] Notifications are DISABLED.
  Enable with: /maestro config set notifications.enabled true
```

If `.maestro/config.yaml` does not exist:

```
[maestro] Config not found. Run /maestro init first.
```

## `levels` — Interactive Level Editor

Present an interactive menu to set the notification level for each configured channel.

First, use AskUserQuestion:

**Question:** "Which channel do you want to configure?"

**Options:** One option per configured provider, plus a "Set default level" option and a "Done" option. For each channel, show the current level in the description.

Example:
1. **telegram** — "Currently: all — receives every event"
2. **slack** — "Currently: important — spending, errors, completions"
3. **Set default level** — "Currently: all — applies to unconfigured channels"
4. **Done** — "Save and exit"

When a channel is selected, use AskUserQuestion:

**Question:** "Notification level for [channel]?"

**Options:**
1. **all** — "Every action, status update, and notification"
2. **important** — "Spending, errors, completions, milestones, approvals needed"
3. **critical** — "Failures, over-budget, security alerts only"
4. **none** — "Silent — actions are still logged locally"

Update `.maestro/config.yaml` under `notifications.per_channel.[channel].level`.

After each change confirm:

```
[maestro] Updated: notifications.per_channel.slack.level = important
```

Then loop back to the channel picker until "Done" is selected.

### Level Quick-Reference

| Level | What you receive |
|-------|-----------------|
| `all` | Everything — verbose, good for personal channels |
| `important` | Spending, errors, completions, approvals — good for work channels |
| `critical` | Only failures, over-budget, and security alerts |
| `none` | Nothing (local log still written) |

## `test` — Send Test Notification to All Channels

Send a test message to every configured and enabled channel. Reports success or failure per channel.

Steps:
1. Read configured providers from `.maestro/config.yaml`
2. For each configured provider with a non-null URL/token:
   - Dispatch a test message using the provider's test format (see provider sub-files)
   - Check the response

Report results:

```
[maestro] Sending test notifications...

  telegram    (ok) Message delivered
  slack       (ok) Message delivered
  discord     skipped — not configured
  pagerduty   skipped — not configured

  2 channels tested, 2 succeeded, 0 failed.
```

If a channel fails:

```
  slack       (!) Failed — HTTP 403 (webhook revoked or invalid)
```

Test message content sent to each channel:

```
[Maestro] Test notification — if you see this, the channel is configured correctly.
Project: [project name] | Time: [HH:MM]
```

## `receipts` — Show Last 20 Action Receipts

Read `.maestro/logs/action-receipts.log` and display the last 20 entries in a formatted table:

```
+---------------------------------------------+
| Recent Action Receipts (last 20)            |
+---------------------------------------------+

  14:05  [AUTO]     Vercel        Deploy to production             $0
  14:10  [APPROVED] Namecheap     Purchase domain myapp.com        $12.99
  14:12  [DENIED]   Mailgun       Send email to clients            blocked by user
  14:15  [FAILED]   AWS EC2       Launch t3.medium instance        InsufficientCapacity
  14:20  [BATCH]    9 actions     7 auto, 1 approved, 1 failed     $0.50

  Total shown: 5 entries  |  Log: .maestro/logs/action-receipts.log
```

If the log does not exist:

```
[maestro] No action receipts yet.
  Receipts are recorded when Maestro takes external actions during a session.
```

## `mute` — Temporarily Mute All Notifications

Suppress all outbound notifications without changing the configuration. The mute state persists across commands within the session but resets when a new session starts.

Set `notifications.muted: true` in `.maestro/config.yaml`.

```
[maestro] Notifications MUTED.
  All channels are silenced. Actions are still logged to .maestro/logs/.
  Resume with: /maestro notifications unmute
```

If already muted:

```
[maestro] Notifications are already muted.
  Resume with: /maestro notifications unmute
```

## `unmute` — Resume Notifications

Clear the mute state.

Set `notifications.muted: false` in `.maestro/config.yaml`.

```
[maestro] Notifications RESUMED.
  All configured channels are now active.
```

If not currently muted:

```
[maestro] Notifications are not muted — nothing to do.
```

## Interactive Mode (no arguments, after showing config)

After displaying the current config, use AskUserQuestion to offer a quick-action menu:

**Question:** "What would you like to do?"

**Options:**
1. **Configure levels** — "Set per-channel notification levels"
2. **Send test** — "Verify all configured channels are working"
3. **View receipts** — "See the last 20 action receipts"
4. **Mute / Unmute** — "Temporarily silence all notifications (currently: [muted/active])"
5. **Done** — "Exit"

## Error Handling

- Config file missing → prompt to run `/maestro init`
- Log file missing → display "No receipts yet" without error
- Channel test fails → display error per channel, continue testing others
- Invalid level value in config → warn and treat as `all`
