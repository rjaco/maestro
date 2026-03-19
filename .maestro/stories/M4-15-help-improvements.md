---
id: M4-15
slug: help-improvements
title: "Interactive help with examples, contextual suggestions, search"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `commands/help.md` with:
   - **Contextual help**: When user runs /maestro help during an active session, show session-relevant commands
   - **Examples**: Each command listing includes a concrete usage example
   - **Search**: /maestro help "search term" finds relevant commands and skills
   - **Quick reference card**: /maestro help --quick shows a compact 1-page reference
2. Help sections organized by workflow:
   - Getting Started: init, quick-start, demo
   - Building: maestro, plan, spec, magnum-opus
   - Monitoring: status, board, viz, deps, history
   - Configuration: config, model, profile, preferences, squad
   - Operations: doctor, retro, rollback, notify
3. Each section has a brief description and most common flags
4. Mirror: command in both root and plugins/maestro/commands/

## Context for Implementer

Read the current `commands/help.md` first. Then enhance it.

The help command should detect context:
- If .maestro/state.local.md exists and active, show "You're in an active session" with relevant commands (status, pause, btw)
- If .maestro/dna.md doesn't exist, suggest /maestro init
- If no active session, show full command reference

For search: the skill should grep through command descriptions for the search term and return matching commands.

Reference: commands/help.md (current)
Reference: README.md for command listing
