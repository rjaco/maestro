---
id: M5-19
slug: cowork-adaptive
title: "Cowork adaptive output — detect environment, format for collaboration"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/desktop-compat/SKILL.md` with Cowork-specific adaptations
2. Cowork detection: check for `CLAUDE_COWORK` env var or presence of cowork indicators
3. When in Cowork mode:
   - Shorter output (Cowork has limited display space)
   - No ASCII art banners (clutters collaborative view)
   - Structured progress updates instead of dashboards
   - Collaborative annotations: "[For team] This change affects..."
4. When in terminal mode (default):
   - Full dashboards, ASCII art, detailed output
5. Environment detection priority: Cowork > Desktop > Terminal > SDK
6. Mirror: skill in both root and plugins/maestro/

## Context for Implementer

Read the current `skills/desktop-compat/SKILL.md` and `skills/ecosystem/SKILL.md` first.

Cowork is Claude Code's collaborative mode where multiple users share a session. Key adaptations:
- Output should be concise and team-readable
- Status updates should use structured format (not box-drawing dashboards)
- File changes should be annotated with impact context
- No verbose self-improvement or retrospective output

The detection logic:
```
if CLAUDE_COWORK is set → cowork mode
elif CLAUDE_DESKTOP is set → desktop mode
elif TERM is set → terminal mode
else → SDK mode (headless)
```

Reference: skills/desktop-compat/SKILL.md (current)
Reference: skills/ecosystem/SKILL.md for environment detection
Reference: skills/universal-output/SKILL.md for output adaptation
