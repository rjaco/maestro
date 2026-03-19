---
name: telegram-bot
description: "Send Telegram notifications for Maestro events. Uses Bot API via curl. Configured via environment variables."
requires_env: [MAESTRO_TELEGRAM_TOKEN, MAESTRO_TELEGRAM_CHAT]
---

# Telegram Bot Skill

Send real-time Maestro event notifications to a Telegram chat using the Telegram Bot API. All credentials are read from environment variables — never stored in config files.

## Setup

1. Create a bot via [@BotFather](https://t.me/BotFather) and obtain the token.
2. Start a conversation with the bot or add it to a group, then find the chat ID using:
   ```bash
   curl -s "https://api.telegram.org/bot${MAESTRO_TELEGRAM_TOKEN}/getUpdates"
   ```
3. Export the environment variables:
   ```bash
   export MAESTRO_TELEGRAM_TOKEN="123456:ABC-your-token-here"
   export MAESTRO_TELEGRAM_CHAT="-1001234567890"
   ```

## Sending Messages

Use `scripts/telegram-send.sh` for all outbound messages:

```bash
# Plain message
./scripts/telegram-send.sh "Maestro session started"

# Send a photo/screenshot
./scripts/telegram-send.sh --photo /path/to/screenshot.png "Dashboard screenshot"
```

Or call the API directly via curl:

```bash
curl -s -X POST "https://api.telegram.org/bot${MAESTRO_TELEGRAM_TOKEN}/sendMessage" \
  -d "chat_id=${MAESTRO_TELEGRAM_CHAT}" \
  -d "text=${MESSAGE}" \
  -d "parse_mode=Markdown"
```

## Message Templates

### Milestone Complete
```
✅ *Milestone M{N} Complete*
{milestone_name}
Stories: {completed}/{total}
```

### Story Complete
```
📝 Story {id} complete: {title}
```

### Error
```
❌ *Error* in story {id}
{error_summary}
```

### Pause
```
⏸ Maestro paused at M{N}/{story}
```

### Resume
```
▶️ Maestro resumed
```

## Sending Photos

Use the `sendPhoto` endpoint to share dashboard screenshots:

```bash
curl -s -X POST "https://api.telegram.org/bot${MAESTRO_TELEGRAM_TOKEN}/sendPhoto" \
  -F "chat_id=${MAESTRO_TELEGRAM_CHAT}" \
  -F "photo=@/path/to/screenshot.png" \
  -F "caption=Dashboard snapshot"
```

Or via `telegram-send.sh`:

```bash
./scripts/telegram-send.sh --photo /path/to/screenshot.png "Dashboard snapshot"
```

## Security

- **Never** store `MAESTRO_TELEGRAM_TOKEN` or `MAESTRO_TELEGRAM_CHAT` in `.maestro/config.yaml`, `.env` files committed to git, or any file tracked by version control.
- Use shell environment variables or a secrets manager.
- The `token_env` / `chat_id_env` keys in config name the environment variables to read — they do not hold the values themselves.

## Integration with Notification Hub

Enable Telegram in `.maestro/config.yaml`:

```yaml
notifications:
  telegram:
    enabled: true
    token_env: MAESTRO_TELEGRAM_TOKEN
    chat_id_env: MAESTRO_TELEGRAM_CHAT
```

The `scripts/notify.sh` hub will automatically route events to Telegram when enabled.

## Error Handling

- Missing env vars → script exits with code 1, logs warning, does not block the dev-loop.
- Non-2xx API response → logs the response body for diagnosis, exits with code 1.
- Network timeout (5 s) → treated as failure, logged.
- Photo file not found → exits with code 1 before making the API call.
