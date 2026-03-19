---
name: notify-approval-prompts
description: "Bidirectional approval prompts via messaging channels. When the autonomy engine requires user approval, sends rich prompts to all connected channels and accepts the first response."
---

# Approval Prompts via Messaging

When the autonomy engine classifies an action as requiring user approval, Maestro sends a rich approval request to every configured messaging channel simultaneously and waits for the first response. Any channel can approve or deny — the first reply wins.

## Trigger

Approval prompts are sent when:
- Autonomy engine raises `approval_needed` for an action
- A spending threshold requires confirmation before proceeding
- An irreversible action is about to execute
- A security-sensitive action is flagged

The call site in the autonomy engine:

```
if action.requires_approval:
    result = notify.request_approval(action)
    if result == "denied" or result == "timeout_denied":
        abort action and record [DENIED] receipt
    else:
        proceed and record [APPROVED] receipt
```

## Prompt Formats

### Telegram

Uses Markdown formatting via the Bot API. The user replies with a single character to the bot.

```
APPROVAL REQUIRED

Service: Namecheap
Action: Purchase domain "myapp.com"
Cost: ~$12.99/year
Risk: IRREVERSIBLE

Reply: YES to approve, NO to deny
```

Telegram curl dispatch:

```bash
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "parse_mode=Markdown" \
  -d "text=*APPROVAL REQUIRED*

*Service:* ${SERVICE}
*Action:* ${ACTION_DESCRIPTION}
*Cost:* ${COST}
*Risk:* ${RISK_LEVEL}

Reply: \`YES\` to approve, \`NO\` to deny"
```

Polling for response (60-second poll loop, 5-second intervals):

```bash
# Poll getUpdates for a reply to this message
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${LAST_UPDATE_ID}&timeout=5"
# Look for reply text matching /^(yes|no|approve|deny)/i
```

### Slack

Uses Block Kit with interactive buttons. Requires a Slack App with Interactive Components enabled and an Actions endpoint configured.

```json
{
  "blocks": [
    {
      "type": "header",
      "text": { "type": "plain_text", "text": "Approval Required" }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Service:* ${SERVICE}\n*Action:* ${ACTION_DESCRIPTION}\n*Cost:* ${COST}\n*Risk:* ${RISK_LEVEL}"
      }
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": { "type": "plain_text", "text": "Approve" },
          "style": "primary",
          "value": "approve",
          "action_id": "maestro_approve"
        },
        {
          "type": "button",
          "text": { "type": "plain_text", "text": "Deny" },
          "style": "danger",
          "value": "deny",
          "action_id": "maestro_deny"
        }
      ]
    },
    {
      "type": "context",
      "elements": [
        { "type": "mrkdwn", "text": "Maestro | ${PROJECT} | Action ID: ${ACTION_ID}" }
      ]
    }
  ]
}
```

Slack curl dispatch:

```bash
curl -s -X POST "${SLACK_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "${BLOCK_KIT_PAYLOAD}"
```

Note: Button interactions require a separate webhook receiver. If no interactive endpoint is configured, Slack falls back to text-only prompt and ignores button clicks. In fallback mode, post instructions to reply with `approve` or `deny` as a thread message.

### CLI (AskUserQuestion)

When Maestro is running interactively in a terminal, approval is always presented via `AskUserQuestion` regardless of messaging channel configuration. This is the primary approval path when no messaging channels are configured.

Present the prompt as:

```
Action requires approval before proceeding.

  Service:  Namecheap
  Action:   Purchase domain "myapp.com"
  Cost:     ~$12.99/year
  Risk:     IRREVERSIBLE — cannot be undone

Choose an option:
  1. Approve — proceed with the action
  2. Deny — block this action and continue the session
  3. Skip — defer the action and continue without it
```

Use `AskUserQuestion` with options `["Approve", "Deny", "Skip"]`.

- **Approve** → record `[APPROVED]` receipt, proceed
- **Deny** → record `[DENIED]` receipt, skip the action
- **Skip** → record `[DENIED]` receipt with reason "deferred by user", note in `.maestro/notes.md` for follow-up

## First-Response-Wins Protocol

When multiple channels are active simultaneously:

1. Send the approval prompt to ALL connected channels at the same time
2. Start polling all channels concurrently
3. The first response received (from any channel) is the decision
4. Immediately send a confirmation to all channels:
   ```
   Decision recorded: APPROVED by Telegram at 14:10:32
   Action: Purchase domain "myapp.com"
   (This prompt is now closed)
   ```
5. Stop polling all other channels
6. Proceed or abort based on the decision

If the same channel sends conflicting responses (e.g., first `YES` then `NO`), the first message received wins. Later messages are ignored with a note logged.

## Timeout Behavior

| Mode | Default behavior |
|------|-----------------|
| `tiered` (full-auto) | Wait indefinitely — session pauses until a response is received |
| `interactive` | Wait indefinitely — user is present at the CLI |
| `watch` | Wait indefinitely — background monitor, user notified via channels |

Timeout can be overridden in config:

```yaml
notifications:
  approval_timeout_seconds: 0   # 0 = wait indefinitely (default)
                                 # >0 = auto-deny after N seconds
```

When `approval_timeout_seconds > 0` and the timeout elapses with no response:
- Record `[DENIED]` receipt with reason "approval timeout"
- Log to `.maestro/logs/notifications.log`
- Continue the session, skipping the timed-out action

## Risk Level Display

The autonomy engine provides a risk level with each approval request. Display it as:

| Risk level | Display text |
|-----------|-------------|
| `reversible` | LOW RISK — reversible |
| `irreversible` | IRREVERSIBLE |
| `spending` | SPENDING — ${cost} |
| `security` | SECURITY SENSITIVE |
| `destructive` | DESTRUCTIVE — data loss possible |

## Integration with Action Receipts

Every approval prompt resolution feeds directly into the action receipt system:

- User approves → `[APPROVED]` receipt generated
- User denies → `[DENIED]` receipt generated
- Timeout deny → `[DENIED]` receipt with reason "approval timeout"
- Action proceeds and fails → `[FAILED]` receipt generated

The receipt is sent to channels as a follow-up after the approval confirmation message.
