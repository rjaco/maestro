---
name: plugin-data
description: "Portable state management via CLAUDE_PLUGIN_DATA. Separates global identity/preferences from project-specific state, enabling persistent personality across plugin updates."
---

# Plugin Data

Manages Maestro's persistent state across plugin updates using the `CLAUDE_PLUGIN_DATA` directory introduced in Claude Code v2.1.78+.

## Portable State via CLAUDE_PLUGIN_DATA

Claude Code v2.1.78+ provides `CLAUDE_PLUGIN_DATA` — a persistent
directory that survives plugin updates.

### What Goes in PLUGIN_DATA (global, cross-project)
- `SOUL.md` — persistent personality identity
- `preferences.md` — developer preferences
- `memory/plan-accuracy.md` — cross-plan learning data
- `memory/patterns.md` — learned coding patterns

### What Stays in .maestro/ (project-specific)
- `state.local.md` — session state
- `dna.md` — project DNA
- `config.yaml` — project config
- `stories/` — story files
- `logs/` — session logs

### Resolution Order
1. `.maestro/SOUL.md` (project override — highest priority)
2. `${CLAUDE_PLUGIN_DATA}/SOUL.md` (portable identity)
3. `templates/soul-profiles/casual.md` (fallback)

This mirrors OpenClaw's `~/.openclaw/workspace/` pattern.
