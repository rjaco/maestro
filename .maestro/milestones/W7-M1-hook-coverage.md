# W7-M1: Hook Coverage & Zero-Code Wins

## Scope
Wire existing hooks and skills that are built but not connected. Then add the highest-impact new hook scripts. Claude Code has 22 hook events — Maestro only wires 4.

## Stories
- S1: Wire PostCompact hook in hooks.json (script exists, just unregistered)
- S2: Wire agents-md into auto-init (skill exists, not called)
- S3: Add effort frontmatter to agent definitions
- S4: StopFailure hook — log errors, send notification, back up state
- S5: PreCompact hook — flush state to disk before context compaction
- S6: PermissionRequest hook — auto-approve known-safe Maestro operations

## Acceptance Criteria
1. hooks.json includes PostCompact, StopFailure, PreCompact, SessionStart, PermissionRequest entries
2. /maestro init produces agents.md at project root
3. All agent definitions include effort: low|medium|high
4. StopFailure sends notification on API errors
5. PreCompact snapshot written before compaction
6. All hooks pass validate-hooks.sh
