---
id: M5-18
slug: agent-teams-native
title: "Agent Teams native support — TeammateIdle/TaskCompleted hook handlers"
type: feature
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `hooks/hooks.json` with new hook registrations:
   - `TeammateIdle` hook handler
   - `TaskCompleted` hook handler
2. New hook script: `hooks/teammate-idle-hook.sh` (60+ lines)
   - When an agent team member goes idle, check for queued stories
   - If stories available, provide next story context for auto-dispatch
   - Log idle events to .maestro/logs/team.md
3. New hook script: `hooks/task-completed-hook.sh` (60+ lines)
   - When a task completes, update Maestro state (current_story, progress)
   - Trigger milestone evaluation if all stories in milestone are done
   - Log completion events
4. Enhanced `skills/agent-teams/SKILL.md` with hook integration documentation
5. All new scripts executable (chmod +x)
6. Mirror: hooks and scripts in both root and plugins/maestro/

## Context for Implementer

Claude Code's native agent teams feature supports:
- `TeammateIdle`: Fires when an agent team member is about to go idle (no more tasks)
- `TaskCompleted`: Fires when a task is marked complete

These hooks receive JSON input with team member info and task details. Read the hooks/hooks.json to understand the existing format, then add the new events.

The TeammateIdle hook should:
1. Read .maestro/state.local.md for current session
2. If opus session active, check for next story in queue
3. Output story context to stdout (this gets injected into the idle agent)

The TaskCompleted hook should:
1. Parse the completed task info from stdin
2. Update .maestro/state.local.md (increment current_story)
3. Check if milestone is complete

Reference: hooks/hooks.json (current hook config)
Reference: skills/agent-teams/SKILL.md (current team coordination)
Reference: hooks/session-start-hook.sh (example of hook script pattern)
