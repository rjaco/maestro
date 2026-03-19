---
name: notify
description: "Send notifications and manage notification providers"
argument-hint: "[send MESSAGE|setup|test|status|disable|enable]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Notify

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

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

  Rate limiting:  5 notifications / minute (per provider)
```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Notify"
- Options:
  1. label: "Setup a provider", description: "Configure Slack, Discord, or Telegram notifications"
  2. label: "Send a test", description: "Send a test message to all configured providers"
  3. label: "Send a message", description: "Send a custom message to all configured providers"

---

### `setup` — Interactive provider setup

Use AskUserQuestion:
- Question: "Which provider would you like to configure?"
- Header: "Provider"
- Options:
  1. label: "Slack", description: "Send to a Slack channel via Incoming Webhook"
  2. label: "Discord", description: "Send to a Discord channel via Webhook"
  3. label: "Telegram", description: "Send to a Telegram chat via Bot API"

---

**For Slack:**

1. Display setup instructions:
   ```
   Slack Setup
   ===========
   1. Go to https://api.slack.com/apps and click "Create New App"
   2. Choose "From scratch", name it "Maestro"
   3. Under "Features", click "Incoming Webhooks" and toggle it ON
   4. Click "Add New Webhook to Workspace" and select a channel
   5. Copy the Webhook URL (starts with https://hooks.slack.com/services/...)
   ```
2. Ask the user to paste the webhook URL
3. **Validate the URL before saving:**
   - Must start with `https://hooks.slack.com/services/`
   - Must match pattern `https://hooks.slack.com/services/[A-Z0-9]+/[A-Z0-9]+/[a-zA-Z0-9]+`
   - If invalid, show: `[maestro] Invalid Slack webhook URL. It should start with https://hooks.slack.com/services/` and re-prompt
4. Send a validation request:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" -X POST \
     -H "Content-Type: application/json" \
     -d '{"text":"[Maestro] Webhook validation ping — ignore this message."}' \
     "${WEBHOOK_URL}"
   ```
   - If HTTP 200: proceed
   - If HTTP 4xx: `[maestro] Webhook rejected (HTTP 4xx). Check the URL is correct and the app is still installed.`
   - If curl fails (no network): warn and ask to save anyway or retry
5. Write to config: `notifications.providers.slack.webhook_url`
6. Enable notifications if not already enabled
7. Proceed to trigger selection (see below)

---

**For Discord:**

1. Display setup instructions:
   ```
   Discord Setup
   =============
   1. Open Discord and navigate to the channel you want notifications in
   2. Click the gear icon (Edit Channel) → Integrations → Webhooks
   3. Click "New Webhook", name it "Maestro", copy the Webhook URL
   4. The URL starts with https://discord.com/api/webhooks/...
   ```
2. Ask the user to paste the webhook URL
3. **Validate the URL before saving:**
   - Must start with `https://discord.com/api/webhooks/`
   - Must match pattern `https://discord.com/api/webhooks/\d+/[a-zA-Z0-9_-]+`
   - If invalid, show format error and re-prompt
4. Send a validation ping:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" -X POST \
     -H "Content-Type: application/json" \
     -d '{"content":"[Maestro] Webhook validation ping — ignore this message."}' \
     "${WEBHOOK_URL}"
   ```
   - HTTP 204 = success (Discord returns 204 No Content on success)
   - Otherwise handle as above
5. Write to config, enable, proceed to trigger selection

---

**For Telegram:**

1. Display setup instructions:
   ```
   Telegram Setup
   ==============
   Step 1 — Create a bot:
     1. Open Telegram and search for @BotFather
     2. Send /newbot and follow the prompts
     3. Copy the bot token (format: 1234567890:ABCDefGhIjKlMnOpQrStUvWxYz)

   Step 2 — Get your chat_id:
     1. Send any message to your new bot
     2. Run this command to find your chat_id:
        curl "https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates"
     3. Look for "chat":{"id": XXXXXXX} in the response
   ```
2. Ask for bot token (validate format: `\d+:[A-Za-z0-9_-]{35,}`)
3. Ask for chat_id (validate: integer, positive or negative)
4. Send a validation ping:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" \
     "https://api.telegram.org/bot${TOKEN}/sendMessage" \
     -d "chat_id=${CHAT_ID}&text=[Maestro] Webhook validation ping"
   ```
   HTTP 200 = success
5. Write to config, enable, proceed to trigger selection

---

**Trigger selection (runs after any provider setup):**

Use AskUserQuestion:
- Question: "Which events should trigger notifications?"
- Header: "Triggers"
- Options (multiSelect: true):
  1. label: "Story complete", description: "Notify when each story passes QA"
  2. label: "Feature complete", description: "Notify when all stories are done"
  3. label: "QA rejection", description: "Alert when QA rejects a story"
  4. label: "Failures", description: "Alert on self-heal failures and test regressions"

Save selected triggers to `notifications.triggers` in config.

---

### `test` — Send test message

Send a test notification to all configured and enabled providers.

For each provider, run the appropriate curl command with this payload:

**Slack payload:**
```json
{
  "text": "[Maestro] Test notification. If you see this, Slack is configured correctly.",
  "username": "Maestro",
  "icon_emoji": ":robot_face:"
}
```

**Discord payload:**
```json
{
  "content": "[Maestro] Test notification. If you see this, Discord is configured correctly.",
  "username": "Maestro"
}
```

**Telegram payload:**
```
chat_id=<chat_id>&text=[Maestro] Test notification. If you see this, Telegram is configured correctly.
```

**Retry logic:** If the first attempt fails with a 5xx error or network error, retry up to 2 times with a 2-second wait between attempts. On each retry, log: `[maestro] Retry 1/2 for Slack...`

**Rate limiting:** Wait at least 200ms between sends to different providers to avoid bursting. Do not send more than 5 notifications per minute per provider — if this limit would be exceeded, queue the excess and warn: `[maestro] Rate limit reached for Slack — notification queued.`

Report results:

```
[maestro] Test notifications sent:

  (ok) Slack       delivered  (HTTP 200)
  (x)  Discord     not configured
  (ok) Telegram    delivered  (HTTP 200)
  (!)  Webhook.co  failed after 3 attempts (HTTP 503) — check provider status
```

---

### `send MESSAGE` or just a message — Send custom notification

Send the user's message to all configured and enabled providers.

Apply the same provider-specific payload wrapping as in `test`, replacing the message body with `[Maestro] ${MESSAGE}`.

Apply the same retry logic (2 retries, 2s wait) and rate limiting (200ms between providers, 5/min cap).

Confirm:

```
[maestro] Message sent to 2 provider(s).
  (ok) Slack       delivered
  (ok) Telegram    delivered
```

---

### `disable` — Disable notifications

Set `notifications.enabled: false` in config.

```
[maestro] Notifications disabled. Providers remain configured.
(i) Re-enable with: /maestro notify enable
```

### `enable` — Enable notifications

Set `notifications.enabled: true` in config.

```
[maestro] Notifications enabled.
```

---

## Webhook URL Validation Reference

| Provider  | Valid prefix                            | Validation pattern                                                       |
|-----------|-----------------------------------------|--------------------------------------------------------------------------|
| Slack     | `https://hooks.slack.com/services/`    | `https://hooks.slack.com/services/[A-Z0-9]+/[A-Z0-9]+/[a-zA-Z0-9]+`   |
| Discord   | `https://discord.com/api/webhooks/`    | `https://discord.com/api/webhooks/\d+/[a-zA-Z0-9_-]+`                  |
| Telegram  | n/a (uses bot token + chat_id)         | Token: `\d+:[A-Za-z0-9_-]{35,}`  Chat ID: `-?\d+`                      |

Always validate format before attempting a network call. If format is invalid, reject immediately without making any HTTP request.

---

## Output Contract

Every `notify` invocation emits output in this order:

1. ASCII banner (mandatory)
2. Primary output block (status table, test results, send confirmation)
3. Retry logs inline if retries occurred (`(!) Retry 1/2 for Slack...`)
4. Rate limit warnings if applicable
5. AskUserQuestion prompt (in `setup` and no-argument views)

**Config writes:** All provider config is written to `.maestro/config.yaml` under `notifications.providers.<provider>`. Never write secrets to any other file. Never echo a webhook URL or bot token back in plaintext after it has been saved.

---

## Argument Parsing

| Invocation | Behavior |
|-----------|----------|
| `/maestro notify` | Show provider status + interactive menu |
| `/maestro notify setup` | Interactive provider setup wizard |
| `/maestro notify test` | Send test message to all configured providers |
| `/maestro notify send MESSAGE` | Send a custom message to all providers |
| `/maestro notify status` | Show provider status (same as no args) |
| `/maestro notify disable` | Disable all notifications |
| `/maestro notify enable` | Enable all notifications |

For `send`, `MESSAGE` is everything after `send ` in `$ARGUMENTS`. If it is empty after stripping whitespace, show:
```
[maestro] Usage: /maestro notify send "your message"
```

## Config File Structure

The `notifications` block in `.maestro/config.yaml`:

```yaml
notifications:
  enabled: true
  providers:
    slack:
      enabled: true
      webhook_url: "https://hooks.slack.com/services/..."
    discord:
      enabled: false
      webhook_url: ""
    telegram:
      enabled: true
      bot_token: "1234567890:ABCDefGhIjKlMnOpQrStUvWxYz"
      chat_id: "-1001234567890"
  triggers:
    - story_complete
    - feature_complete
    - qa_rejection
    - self_heal_failure
    - test_regression
  rate_limit:
    per_provider_per_minute: 5
```

When reading the config for `status` display:
- A provider is "configured" if its required credential fields are non-empty strings
- A provider is "enabled" only if both `notifications.enabled: true` AND `providers.<name>.enabled: true`
- Show `(ok)` for configured+enabled, `(-)` for configured-but-disabled, `(x)` for not-configured

## Error Handling

| Condition | Action |
|-----------|--------|
| `.maestro/config.yaml` missing | Show `[maestro] Not initialized. Run /maestro init first.` and stop |
| `notifications` section absent from config | Treat as all providers unconfigured; offer to run `setup` |
| curl not available | Show `(x) curl is required for notifications but is not installed.` and stop |
| HTTP 4xx on validation | Show specific error; do NOT save the webhook URL |
| HTTP 5xx on validation | Warn about provider issues; ask user whether to save anyway |
| Network error (curl fails with exit 6/7) | Show `(x) Network error — cannot reach <provider>. Check your internet connection.` |
| Webhook URL saved but send fails later | Update provider status to `error` in config; surface in `status` view |
| Config write fails (disk full, permissions) | Show `(x) Cannot write config: <reason>`. Do not retry silently. |

## Examples

### Example 1: Show notification status

```
/maestro notify
```

```
+---------------------------------------------+
| Notifications                               |
+---------------------------------------------+

  Status    enabled

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

  Rate limiting:  5 notifications / minute (per provider)
```

### Example 2: Send a custom notification

```
/maestro notify send "Deployment to production completed successfully"
```

```
[maestro] Message sent to 2 provider(s).
  (ok) Slack       delivered
  (ok) Telegram    delivered
```

### Example 3: Test notifications

```
/maestro notify test
```

```
[maestro] Test notifications sent:

  (ok) Slack       delivered  (HTTP 200)
  (x)  Discord     not configured
  (ok) Telegram    delivered  (HTTP 200)
```

### Example 4: Disable notifications

```
/maestro notify disable
```

```
[maestro] Notifications disabled. Providers remain configured.
(i) Re-enable with: /maestro notify enable
```
