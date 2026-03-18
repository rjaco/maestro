---
name: notify-provider-telegram
description: "Telegram notification provider. Sends messages via Bot API using bash curl with HTML formatting."
---

# Notification Provider: Telegram

Sends Maestro notifications to a Telegram chat via Bot API.

## Prerequisites

1. Message @BotFather on Telegram: `/newbot`
2. Follow prompts to create a bot and get the token
3. Send a message to your bot, then get your chat_id:
   ```bash
   curl "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'
   ```
4. Add to `.maestro/config.yaml`:

```yaml
notifications:
  providers:
    telegram:
      bot_token: "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
      chat_id: "987654321"
```

## Message Formatting

Telegram supports HTML formatting:

```bash
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "parse_mode=HTML" \
  -d "text=<b>[Maestro] ${EVENT_TITLE}</b>

${MESSAGE}

<i>Project: ${PROJECT} | Mode: ${MODE}</i>"
```

### Event-specific formatting

**story_complete:**
```html
<b>[Maestro] Story Complete</b>

<b>Story:</b> ${STORY_TITLE}
<b>Status:</b> ${QA_RESULT}
<b>Cost:</b> $${COST}
<b>Next:</b> ${NEXT_TITLE}
```

**feature_complete:**
```html
<b>[Maestro] Feature Complete</b>

<b>${FEATURE_NAME}</b>
Stories: ${COMPLETED}/${TOTAL}
Cost: $${COST} | Time: ${DURATION}
QA: ${QA_RATE}% first-pass
```

**self_heal_failure / test_regression (alert):**
```html
<b>[Maestro] ${EVENT_TYPE}</b>

${ERROR_SUMMARY}

<b>Action:</b> ${ACTION}
```

## Testing

```bash
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=[Maestro] Test notification. Telegram is configured correctly."
```

## Error Handling

- `"ok": true` → success
- `"ok": false, "error_code": 401` → invalid bot token
- `"ok": false, "error_code": 400` → invalid chat_id or bad message
- `"ok": false, "error_code": 429` → rate limited (wait `retry_after` seconds)
