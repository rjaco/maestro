# S10: Remote Command Receiver

**Milestone:** M3 — Communication Channels
**Priority:** Medium
**Effort:** Medium

## User Story
As a developer away from my terminal, I want to send commands via Telegram to Maestro, so that I can pause, resume, or check status remotely.

## Tasks
- [ ] 1.1 Create `scripts/remote-listener.sh` — polls Telegram Bot API for updates
- [ ] 1.2 Parse incoming messages as commands: /status, /pause, /resume, /logs, /stories
- [ ] 1.3 /status → read state.local.md and send summary via Telegram
- [ ] 1.4 /pause → set phase: paused in state.local.md
- [ ] 1.5 /resume → set phase: opus_executing and active: true
- [ ] 1.6 /logs → send last 10 lines of daemon.log
- [ ] 1.7 /stories → list current milestone stories with status
- [ ] 1.8 Write received commands to .maestro/remote-commands.jsonl for audit
- [ ] 1.9 Create `skills/remote-listener/SKILL.md` documenting the system
- [ ] 1.10 Mirror to plugins/maestro/

## Files to Create
- scripts/remote-listener.sh
- skills/remote-listener/SKILL.md
- plugins/maestro/skills/remote-listener/SKILL.md
