# M3: Communication Channels & Remote Control

## Scope
Add OpenClaw-inspired messaging bridges so users can monitor and control Maestro from Telegram, Slack, or Discord. The notification hub sends status updates on key events, and the remote command receiver parses messages into Maestro actions.

## Architecture
```
Maestro (hooks/events)
    │
    ├─ notification-hub skill
    │   ├─ Telegram Bot API → chat messages
    │   ├─ Slack Webhook → channel messages
    │   ├─ Discord Webhook → channel messages
    │   └─ Generic HTTP POST → custom endpoints
    │
    └─ remote-control skill
        ├─ Telegram Bot (polling) → parse commands
        ├─ Slash commands: /status, /pause, /resume, /logs
        └─ Write commands to .maestro/remote-commands.jsonl
```

## Acceptance Criteria
1. Telegram bot sends milestone/story completion notifications
2. Slack webhook sends progress updates
3. User can send /status to Telegram bot and receive current state
4. User can send /pause and Maestro pauses after current story
5. Configuration in .maestro/config.yaml under `notifications:` section
6. Credentials stored in environment variables, never in config files

## Stories
- S8: Telegram bot skill
- S9: Notification hub (unified multi-channel)
- S10: Remote command receiver
