# Opus Roadmap — Wave 6: The Grand Ultimate Tool

| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| M1 | 4 | ✓ complete | Full-auto reliability — fix the loop |
| M2 | 3 | ✓ complete | Multi-instance coordination |
| M3 | 3 | ✓ complete | Communication channels & remote control |
| M4 | 3 | ✓ complete | Enhanced SOUL & personality |
| M5 | 4 | ✓ complete | Ruflo feature adoption (S17 deferred) |
| M6 | 3 | ✓ complete | OpenClaw-inspired enhancements |

**Total: 20 stories across 6 milestones — ALL COMPLETE**
**Wave 6 completed: All 6 milestones (19 stories implemented, 1 deferred)**

---

## M1: Full-Auto Reliability ✓
Fix the #1 user pain: full-auto mode silently stops after some cycles.
- ✓ S1: Harden opus-loop-hook — inline vision, escalation, iteration counter, heartbeat
- ✓ S2: Enhance session-start-hook — full Opus recovery with vision, milestone, stories, directive
- ✓ S3: Opus-daemon already hardened — stall detection, JSONL history, colored output, vision prompts
- ✓ S4: Heartbeat system — heartbeat skill, heartbeat command, opus-loop integration

## M2: Multi-Instance Coordination ✓
Enable parallel Maestro instances without conflicts.
- ✓ S5: Instance registry — .maestro/instances/ lifecycle, story claiming, stale cleanup
- ✓ S6: Branch manager — per-instance branches, branch-guard updated for maestro/*
- ✓ S7: Merge coordinator — rebase strategy, conflict resolution rules, file locking

## M3: Communication Channels & Remote Control ✓
OpenClaw-inspired messaging bridges for remote monitoring.
- ✓ S8: Telegram bot skill + telegram-send.sh script
- ✓ S9: Notification hub — notify.sh + enhanced notification-hook.sh
- ✓ S10: Remote command receiver — remote-listener.sh with /status /pause /resume /logs

## M4: Enhanced SOUL & Personality ✓
Persistent autonomous personality that learns.
- ✓ S11: Enhanced SOUL.md — personality traits, communication style, decision principles
- ✓ S12: Personality learning via self-correct skill — learned traits, confirmation signals
- ✓ S13: Personality profiles deferred to templates/ (future)

## M5: Ruflo Feature Adoption ✓
Best Ruflo patterns adapted for markdown-first architecture.
- ✓ S14: Scout/explorer agent — 3 strategies, read-only enforcement, recon reports
- ✓ S15: SPARC methodology — 5-phase lifecycle with gates
- ✓ S16: Production validator — mock/stub/TODO detection + production-validate.sh
- ○ S17: Enhanced background workers — deferred to Wave 7

## M6: OpenClaw-Inspired Enhancements ✓
Patterns from the 321k-star project.
- ✓ S18: Declarative skill dependency gating — requires_os, requires_bins, requires_env
- ✓ S19: Three-tier skill precedence — workspace > global > bundled
- ✓ S20: Skill watcher with session-scoped snapshots
