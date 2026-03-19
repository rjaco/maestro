# S8: Telegram Bot Skill

**Milestone:** M3 — Communication Channels
**Priority:** High
**Effort:** Medium

## User Story
As a developer monitoring Maestro remotely, I want to receive Telegram messages about milestone completions and errors, so that I can stay informed without watching the terminal.

## Tasks
- [ ] 1.1 Create `skills/telegram-bot/SKILL.md`
- [ ] 1.2 Configure via .maestro/config.yaml: `notifications.telegram.bot_token` (from env $MAESTRO_TELEGRAM_TOKEN), `notifications.telegram.chat_id` (from env $MAESTRO_TELEGRAM_CHAT)
- [ ] 1.3 Skill instructs: use `curl` to send messages via Telegram Bot API `https://api.telegram.org/bot{token}/sendMessage`
- [ ] 1.4 Message format: emoji prefix + event type + details (milestone complete, story complete, error, pause)
- [ ] 1.5 Support sending photos/screenshots via `sendPhoto` endpoint
- [ ] 1.6 Create script `scripts/telegram-send.sh` for easy sending from hooks
- [ ] 1.7 Mirror to plugins/maestro/

## Files to Create
- skills/telegram-bot/SKILL.md
- scripts/telegram-send.sh
- plugins/maestro/skills/telegram-bot/SKILL.md
