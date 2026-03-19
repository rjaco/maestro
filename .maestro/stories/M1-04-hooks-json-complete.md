---
id: M1-04
slug: hooks-json-complete
title: "Register all appropriate hook events with proper matchers"
type: infrastructure
depends_on: [M1-03]
parallel_safe: false
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. `hooks.json` registers hooks for ALL events that Maestro uses: SessionStart, PreToolUse (Edit/Write/NotebookEdit), Stop, StopFailure, PostCompact, Notification
2. Each hook entry has appropriate matchers where applicable (PreToolUse uses toolName matchers)
3. All referenced hook scripts exist and are executable (chmod +x)
4. Hook scripts that don't exist yet are created as minimal stubs that exit 0 (no-op) with a TODO comment
5. No duplicate hook registrations
6. Hook order within arrays is intentional (opus-loop before stop, delegation before branch-guard)

## Files

- **Modify:** `hooks/hooks.json`
- **Verify:** All referenced scripts in `hooks/` directory exist and are executable
- **Reference:** Claude Code hook documentation for available events

## Context for Implementer

- Current hooks.json has: SessionStart, PreToolUse (branch-guard + delegation), Stop (opus-loop + stop), StopFailure, PostCompact, Notification
- Available Claude Code hook events: SessionStart, Stop, SubagentStop, PreToolUse, PostToolUse, Notification, StopFailure, PostCompact, WorktreeCreate, WorktreeRemove, TeammateIdle, TaskCompleted
- NOT all events need hooks — only register where Maestro has meaningful behavior
- Consider adding: PostToolUse (for token tracking), WorktreeCreate/WorktreeRemove (for worktree lifecycle tracking)
- Do NOT add hooks that would slow down every tool call with no benefit
