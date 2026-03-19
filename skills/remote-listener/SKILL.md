---
name: remote-listener
description: "Receive commands from Telegram to control Maestro remotely. Polls Bot API and translates messages to state file changes."
requires_env: [MAESTRO_TELEGRAM_TOKEN, MAESTRO_TELEGRAM_CHAT]
---

# Remote Listener

Polls the Telegram Bot API for incoming messages and translates them to Maestro state actions. Runs as a background process alongside `opus-daemon.sh`.

## Prerequisites

### 1. Create a Telegram Bot

1. Open Telegram and message `@BotFather`
2. Send `/newbot` and follow the prompts
3. Save the token BotFather gives you (format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

### 2. Get Your Chat ID

Send any message to your bot, then run:

```bash
curl "https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates" | jq '.result[0].message.chat.id'
```

The number returned is your `chat_id`. If you want a group chat, add the bot to the group and send a message there before running the above.

### 3. Set Environment Variables

```bash
export MAESTRO_TELEGRAM_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
export MAESTRO_TELEGRAM_CHAT="987654321"
```

Add these to your shell profile or a `.env` file (never commit credentials).

## Starting the Listener

```bash
./scripts/remote-listener.sh &
```

Or to keep it running after terminal close:

```bash
nohup ./scripts/remote-listener.sh >> .maestro/logs/remote-listener.log 2>&1 &
echo $! > .maestro/logs/remote-listener.pid
```

To stop it:

```bash
kill "$(cat .maestro/logs/remote-listener.pid)"
```

## Available Commands

Send these commands to your bot in Telegram:

| Command | Action |
|---------|--------|
| `/status` | Read `.maestro/state.local.md` and send a formatted summary of active feature, phase, progress, and token spend |
| `/pause` | Set `phase: paused` in the state file — Maestro will stop at the next checkpoint |
| `/resume` | Set `phase: opus_executing` and `active: true` — Maestro resumes from paused state |
| `/logs` | Send the last 10 lines of `.maestro/logs/daemon.log` |
| `/stories` | List all story files in `.maestro/stories/` with their status |
| `/heartbeat` | Read `.maestro/logs/heartbeat.json` and send timestamp, phase, and status |

Unknown commands receive: `Unknown command. Available: /status /pause /resume /logs /stories /heartbeat`

## Security

The listener only processes messages from the chat ID configured in `MAESTRO_TELEGRAM_CHAT`. Messages from any other chat or user are silently ignored and logged to stderr.

## Audit Log

All received commands are appended to `.maestro/logs/remote-commands.jsonl`:

```json
{"timestamp":"2026-03-18T10:30:00Z","command":"/status","chat_id":"987654321","username":"rodrigo"}
```

## Daemon Integration

The remote listener is designed to run alongside `opus-daemon.sh` as a companion process:

```
[Terminal / tmux session]
  |
  +-- opus-daemon.sh         (orchestrates Claude Code sessions)
  +-- remote-listener.sh     (handles Telegram remote commands)
```

Both processes read and write `.maestro/state.local.md`. The listener uses atomic file operations (write to tmp + mv) when modifying state to avoid corruption.

The listener does not start or stop the daemon — it only modifies the state file. The daemon reads state changes at its next polling cycle.

## Files

| File | Purpose |
|------|---------|
| `.maestro/state.local.md` | Session state — read by `/status`, modified by `/pause` and `/resume` |
| `.maestro/logs/telegram-offset` | Tracks last processed Telegram update_id to avoid reprocessing |
| `.maestro/logs/daemon.log` | Read by `/logs` |
| `.maestro/logs/heartbeat.json` | Read by `/heartbeat` |
| `.maestro/logs/remote-commands.jsonl` | Audit trail for all received commands |
| `.maestro/stories/` | Story files listed by `/stories` |

## Error Handling

- Network failure on curl → warning logged to stderr, listener continues
- Telegram API error → warning logged, listener retries after 10 seconds
- Empty API response → warning logged, listener retries after 5 seconds
- State file missing when running `/pause` or `/resume` → error message sent back via Telegram
- `jq` parse errors → graceful fallback values used, no crash

## Polling Behavior

Uses Telegram's long-polling mode with a 30-second timeout. This means:
- Each request blocks for up to 30 seconds waiting for new messages
- When a message arrives, the API responds immediately
- The offset is advanced after each batch so messages are never processed twice
- curl timeout is set to 35 seconds (5s buffer beyond the long-poll timeout)
