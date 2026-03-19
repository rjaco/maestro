---
id: M4-16
slug: command-ux-audit
title: "Command UX audit — consistent flags, better help, aliases"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. All 39 commands audited for consistency:
   - All use `--flag-name` format (no single-dash long flags)
   - Common flags standardized: --verbose, --quiet, --json, --dry-run
   - --help flag documented in every command
2. Command aliases documented in help:
   - /maestro opus → /maestro magnum-opus
   - /maestro s → /maestro status
   - /maestro b → /maestro board
   - /maestro h → /maestro help
3. Every command has a one-line description and usage example in its file
4. Commands that take arguments have clear argument documentation
5. Error for unknown commands: "Unknown command '[X]'. Did you mean '[closest match]'?"
6. Mirror: all changes in both root and plugins/maestro/

## Context for Implementer

Audit all files in commands/ directory. For each command:
1. Check if it has clear usage documentation
2. Check if flag naming is consistent
3. Add usage examples if missing
4. Ensure the description frontmatter is clear and specific

Focus on the most-used commands first:
- maestro.md (main command)
- status.md
- init.md
- help.md
- magnum-opus.md
- plan.md
- board.md

For fuzzy matching on unknown commands, the classifier skill should suggest the closest match using Levenshtein distance or simple prefix matching.

Reference: commands/*.md (all command files)
Reference: skills/classifier/SKILL.md for command routing
