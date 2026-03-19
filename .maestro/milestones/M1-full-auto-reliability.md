# M1: Full-Auto Reliability

## Scope
Fix the critical bug where Magnum Opus full-auto mode silently stops after some cycles. The user reports seeing "Full-auto mode continues..." messages but then nothing happens. The loop must either continue indefinitely or clearly communicate why it stopped.

## Root Cause Analysis
1. **stop_hook_active flag**: Claude Code sets this after multiple stop hook blocks, forcing exit
2. **Post-compact context loss**: After context compaction, the Opus orchestration context is lost
3. **Daemon prompt too weak**: The daemon's continuation prompt doesn't provide enough context
4. **No stall detection**: No mechanism to detect when Claude stops making progress

## Acceptance Criteria
1. Opus-loop-hook includes inline vision summary in re-injection (not just "read file")
2. Session-start-hook injects full Opus state after compact (milestone, story, phase, vision summary)
3. Daemon script tracks iteration progress, detects stalls (no state change in 5 min), auto-restarts
4. Heartbeat file updated on every agent dispatch, readable by daemon
5. All hooks pass shellcheck with no errors
6. Mirror sync maintained between root hooks/ and plugins/maestro/hooks/

## Stories
- S1: Harden opus-loop-hook
- S2: Enhance session-start-hook for post-compact Opus recovery
- S3: Harden opus-daemon.sh with progress tracking and stall detection
- S4: Add heartbeat + progress tracking system
