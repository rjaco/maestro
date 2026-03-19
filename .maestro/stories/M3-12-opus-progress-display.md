---
id: M3-12
slug: opus-progress-display
title: "Opus progress display — live dispatch status, ETA, spend"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/dashboard/SKILL.md` with Opus-specific progress display
2. Display format for active Opus sessions:
```
╔══════════════════════════════════════════════════════╗
║  MAGNUM OPUS — Wave 5: Ultimate Development Tool    ║
╠══════════════════════════════════════════════════════╣
║  Milestone 2/7: Advanced Orchestration Intelligence  ║
║  Story 3/5: Knowledge Graph                         ║
║  Phase: IMPLEMENT                                   ║
║  ████████░░░░░░░░░░ 40% complete                    ║
╠──────────────────────────────────────────────────────╣
║  Stories: ✓✓✓○○ (3 done, 2 remaining)              ║
║  Cost: ~$2.40 spent | ~$3.60 remaining              ║
║  Time: 45m elapsed | ~1h 10m ETA                    ║
║  QA Pass Rate: 80% (4/5 first-pass)                 ║
╚══════════════════════════════════════════════════════╝
```
3. Progress bar using Unicode blocks (█░)
4. Story completion indicators (✓ for done, ○ for pending, ▶ for current)
5. ETA calculation based on average time per story
6. Cost display from token-ledger data
7. QA first-pass rate tracking

## Context for Implementer

Read the current `skills/dashboard/SKILL.md` first. Add a new section for Opus progress display. This display should be shown:
- After each story completes in the opus-loop
- When user asks for `/maestro status` during an Opus session
- At milestone boundaries

Use Unicode box-drawing characters for the frame. Use ANSI color codes (via markdown code blocks) for emphasis. The display is generated as text output, not a real TUI — it's printed between agent dispatches.

Reference: skills/dashboard/SKILL.md (current)
Reference: skills/opus-loop/SKILL.md for opus execution context
Reference: skills/output-format/SKILL.md for formatting standards
