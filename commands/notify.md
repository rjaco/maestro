---
name: notify
description: "Send notifications and manage notification providers"
argument-hint: "[send MESSAGE|setup|test|status]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Notify

Send ad-hoc notifications and manage notification providers.

## Step 1: Read Config

Read `.maestro/config.yaml`. Check the `notifications` section.

## Step 2: Handle Arguments

### No arguments — Show status

```
+---------------------------------------------+
| Notifications                               |
+---------------------------------------------+

  Status    [enabled|disabled]

  Providers:
    (ok) Slack       configured (webhook set)
    (x)  Discord     not configured
    (ok) Telegram    configured (bot + chat_id)

  Triggers:
    (ok) Story complete
    (ok) Feature complete
    (ok) QA rejection
    (ok) Self-heal failure
    (ok) Test regression
```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Notify"
- Options:
  1. label: "Setup a provider", description: "Configure Slack, Discord, or Telegram notifications"
  2. label: "Send a test", description: "Send a test message to all configured providers"
  3. label: "Send a message", description: "Send a custom message to all configured providers"

### `setup` — Interactive provider setup

Use AskUserQuestion:
- Question: "Which provider would you like to configure?"
- Header: "Provider"
- Options:
  1. label: "Slack", description: "Send to a Slack channel via Incoming Webhook"
  2. label: "Discord", description: "Send to a Discord channel via Webhook"
  3. label: "Telegram", description: "Send to a Telegram chat via Bot API"

**For Slack:**
1. Display setup instructions (create app, enable webhooks, select channel)
2. Ask user to paste the webhook URL
3. Write to config: `notifications.providers.slack.webhook_url`
4. Run test notification
5. Enable notifications if not already enabled

**For Discord:**
1. Display setup instructions (Channel Settings > Integrations > Webhooks)
2. Ask user to paste the webhook URL
3. Write to config
4. Run test

**For Telegram:**
1. Display setup instructions (@BotFather, get token, get chat_id)
2. Ask user for bot token
3. Help them get chat_id (curl command)
4. Write to config
5. Run test

After setup:

Use AskUserQuestion:
- Question: "Which events should trigger notifications?"
- Header: "Triggers"
- Options (multiSelect: true):
  1. label: "Story complete", description: "Notify when each story passes QA"
  2. label: "Feature complete", description: "Notify when all stories are done"
  3. label: "QA rejection", description: "Alert when QA rejects a story"
  4. label: "Failures", description: "Alert on self-heal failures and test regressions"

### `test` — Send test message

Send a test notification to all configured providers:

```bash
# For each configured provider, send:
"[Maestro] Test notification. If you see this, [provider] is configured correctly."
```

Report results:

```
[maestro] Test notifications sent:

  (ok) Slack       delivered
  (x)  Discord     not configured
  (ok) Telegram    delivered
```

### `send MESSAGE` or just a message — Send custom notification

Send the user's message to all configured providers:

```bash
# For each configured provider:
"[Maestro] ${MESSAGE}"
```

Confirm:

```
[maestro] Message sent to [N] provider(s).
```

### `disable` — Disable notifications

Set `notifications.enabled: false` in config.

### `enable` — Enable notifications

Set `notifications.enabled: true` in config.
