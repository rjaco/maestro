# S9: Notification Hub

**Milestone:** M3 — Communication Channels
**Priority:** High
**Effort:** Medium

## User Story
As a developer, I want a unified notification system that routes events to Telegram, Slack, Discord, and webhooks, so that I can use my preferred platform.

## Tasks
- [ ] 1.1 Enhance existing `skills/notify/SKILL.md` (if exists) or update notify skill
- [ ] 1.2 Add provider configuration in .maestro/config.yaml:
  ```yaml
  notifications:
    providers:
      telegram: { enabled: true, token_env: MAESTRO_TELEGRAM_TOKEN, chat_id_env: MAESTRO_TELEGRAM_CHAT }
      slack: { enabled: false, webhook_env: MAESTRO_SLACK_WEBHOOK }
      discord: { enabled: false, webhook_env: MAESTRO_DISCORD_WEBHOOK }
      webhook: { enabled: false, url_env: MAESTRO_WEBHOOK_URL }
    events:
      milestone_complete: [telegram, slack]
      story_complete: [telegram]
      error: [telegram, slack, discord]
      pause: [telegram]
  ```
- [ ] 1.3 Create `scripts/notify.sh` — reads config and dispatches to enabled providers
- [ ] 1.4 Integrate with notification-hook.sh — call notify.sh on key events
- [ ] 1.5 Mirror to plugins/maestro/

## Files to Create/Modify
- scripts/notify.sh
- hooks/notification-hook.sh (enhance)
- plugins/maestro/hooks/notification-hook.sh (mirror)
