---
id: M1-03
slug: plugin-paths-audit
title: "Audit and fix all hardcoded paths — use ${CLAUDE_PLUGIN_ROOT} everywhere"
type: infrastructure
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Zero hardcoded paths to `~/.claude/plugins/cache/maestro-orchestrator/...` in any file
2. All hook scripts use relative paths or `${CLAUDE_PLUGIN_ROOT}` — no absolute paths
3. All skill/command references to plugin files use `${CLAUDE_PLUGIN_ROOT}` substitution
4. `statusline.sh` comment uses `${CLAUDE_PLUGIN_ROOT}` not a hardcoded version path
5. `settings.json` uses `${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh` (already correct — verify)
6. `hooks.json` uses `${CLAUDE_PLUGIN_ROOT}/hooks/...` for all entries (already correct — verify)
7. Any script that reads files relative to itself uses `$(dirname "$0")` or `${CLAUDE_PLUGIN_ROOT}`

## Files

- **Modify:** Any file with hardcoded paths (grep for them)
- **Reference:** `settings.json`, `hooks/hooks.json` (as examples of correct usage)

## Context for Implementer

- Search all files for patterns like: `/home/`, `~/.claude/`, `/cache/maestro`, `1.0.0`, `1.1.0` (hardcoded version)
- The plugin root variable `${CLAUDE_PLUGIN_ROOT}` is available in hooks.json and settings.json
- In bash scripts, use `$(dirname "$0")` to get the script's own directory, or source from a known relative path
- In skill/command markdown, `${CLAUDE_PLUGIN_ROOT}` is available as a string substitution
- This is a grep + fix task — systematic search and replace
