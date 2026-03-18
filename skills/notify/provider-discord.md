---
name: notify-provider-discord
description: "Discord notification provider. Sends messages via Webhook URL using bash curl with embed formatting."
---

# Notification Provider: Discord

Sends Maestro notifications to a Discord channel via Webhook.

## Prerequisites

1. In Discord: Channel Settings > Integrations > Webhooks > New Webhook
2. Copy the webhook URL to `.maestro/config.yaml`:

```yaml
notifications:
  providers:
    discord:
      webhook_url: "https://discord.com/api/webhooks/1234567890/abcdef..."
```

## Message Formatting

Discord supports embeds with color-coded sidebars:

| Event Type | Color | Hex |
|------------|-------|-----|
| story_complete | Green | 0x0E8A16 |
| feature_complete | Blue | 0x0075CA |
| qa_rejection | Yellow | 0xE4E669 |
| self_heal_failure | Red | 0xB60205 |
| test_regression | Red | 0xB60205 |
| ship_complete | Purple | 0xD876E3 |

### Sending notifications

```bash
curl -s -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "embeds": [{
      "title": "'"${EVENT_TITLE}"'",
      "description": "'"${MESSAGE}"'",
      "color": '"${COLOR_INT}"',
      "fields": [
        {"name": "Story", "value": "'"${STORY}"'", "inline": true},
        {"name": "Status", "value": "'"${STATUS}"'", "inline": true},
        {"name": "Cost", "value": "$'"${COST}"'", "inline": true}
      ],
      "footer": {"text": "Maestro | '"${PROJECT}"'"},
      "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
    }]
  }'
```

## Testing

```bash
curl -s -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d '{"content": "[Maestro] Test notification. Discord is configured correctly."}'
```

## Error Handling

- 204 No Content → success (Discord returns 204 on webhook success)
- 400 → invalid payload
- 401/403 → webhook deleted or permissions changed
- 429 → rate limited (back off)
