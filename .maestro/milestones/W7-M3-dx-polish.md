# W7-M3: Developer Experience Polish

## Scope
Surface existing data (cost, context health) and adopt new Claude Code features.

## Stories
- S11: Session cost display in stop-hook.sh output
- S12: Context health warning in PostToolUse hook (warn at 70%/90%)
- S13: Move SOUL/memory to CLAUDE_PLUGIN_DATA for cross-project portability
- S14: Document /effort, /loop, /remote-control patterns in help.md

## Acceptance Criteria
1. Stop hook shows session cost estimate
2. PostToolUse warns when context > 70% full
3. SOUL files read from CLAUDE_PLUGIN_DATA with .maestro/ fallback
4. Help command documents all native Claude Code integrations
