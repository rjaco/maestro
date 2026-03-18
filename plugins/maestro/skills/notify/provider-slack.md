---
name: notify-provider-slack
description: "Slack notification provider. Sends messages via Incoming Webhook URL using bash curl."
---

# Notification Provider: Slack

Sends Maestro notifications to a Slack channel via Incoming Webhook.

## Prerequisites

1. Create a Slack App at https://api.slack.com/apps
2. Enable "Incoming Webhooks" feature
3. Add a webhook to your workspace and select a channel
4. Copy the webhook URL to `.maestro/config.yaml`:

```yaml
notifications:
  providers:
    slack:
      webhook_url: "https://hooks.slack.com/services/T.../B.../..."
```

## Message Formatting

Slack supports Block Kit for rich formatting. Each notification type uses a structured block layout:

### story_complete

```bash
curl -s -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "Story Complete"}
      },
      {
        "type": "section",
        "fields": [
          {"type": "mrkdwn", "text": "*Story:* '"${STORY_TITLE}"'"},
          {"type": "mrkdwn", "text": "*Status:* '"${QA_RESULT}"'"},
          {"type": "mrkdwn", "text": "*Cost:* $'"${COST}"'"},
          {"type": "mrkdwn", "text": "*Next:* '"${NEXT_TITLE}"'"}
        ]
      },
      {
        "type": "context",
        "elements": [
          {"type": "mrkdwn", "text": "Maestro | '"${PROJECT}"' | '"${MODE}"' mode"}
        ]
      }
    ]
  }'
```

### feature_complete

```bash
curl -s -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "Feature Complete"}
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*'"${FEATURE_NAME}"'*\nStories: '"${COMPLETED}"'/'"${TOTAL}"' | Cost: $'"${COST}"' | Time: '"${DURATION}"'\nQA first-pass: '"${QA_RATE}"'% | Trust: '"${TRUST_LEVEL}"'"}
      }
    ]
  }'
```

### qa_rejection (warning)

```bash
curl -s -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "QA Rejected"}
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*'"${STORY_TITLE}"'* (attempt '"${ATTEMPT}"'/'"${MAX}"')\n> '"${REASON}"'"}
      }
    ]
  }'
```

### self_heal_failure / test_regression (alert)

```bash
curl -s -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "[Maestro] '"${EVENT_TYPE}"': '"${SUMMARY}"'\nAction: '"${ACTION}"'"
  }'
```

## Testing

```bash
# Test webhook connectivity
curl -s -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{"text": "[Maestro] Test notification. If you see this, Slack is configured correctly."}'
```

Check HTTP response: `ok` means success, anything else indicates an issue.

## Error Handling

- 200 + "ok" → success
- 400 → invalid payload (check JSON escaping)
- 403 → webhook URL revoked or invalid
- 404 → webhook URL deleted
- Timeout (5s) → network issue, skip
