---
id: M3-10
slug: enhanced-health-dashboard
title: "Enhanced health dashboard — box-drawing, sparklines, color, responsive"
type: enhancement
depends_on: []
parallel_safe: true
complexity: high
model_recommendation: sonnet
---

## Acceptance Criteria

1. `scripts/health-dashboard.sh` is rewritten/enhanced (200+ lines)
2. Dashboard renders a terminal UI with:
   - Box-drawing characters (─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼)
   - Section headers with clear visual hierarchy
   - Color coding: green=healthy, yellow=warning, red=critical
   - Responsive to terminal width (works at 80+ columns)
3. Dashboard sections:
   - **Project Health**: DNA status, init status, version
   - **Skills Inventory**: Total count, categories, thin skill warnings
   - **Hook Status**: All hooks listed with status (active/error/missing)
   - **Mirror Sync**: Root vs plugins/maestro comparison
   - **Recent Activity**: Last 5 commits with dates
   - **Opus Session**: Current milestone/story/phase if active
   - **Background Workers**: Status of each worker if configured
4. Sparkline representation for metrics where applicable (e.g., skill growth over versions)
5. No external dependencies — pure bash with ANSI escape codes
6. Script is executable (chmod +x)
7. Mirror: script available at both root and plugins/maestro/scripts/

## Context for Implementer

Read the current `scripts/health-dashboard.sh` first. Enhance it with:

1. Use ANSI escape codes for colors: `\033[32m` (green), `\033[33m` (yellow), `\033[31m` (red), `\033[0m` (reset)
2. Box-drawing: Use Unicode characters that work in most modern terminals
3. Responsive: Read terminal width with `tput cols` and adjust layout
4. Sparklines: Use Unicode block characters (▁▂▃▄▅▆▇█) for mini bar charts

Example layout:
```
┌─────────────────────────────────────┐
│ MAESTRO HEALTH DASHBOARD       v1.4.0│
├─────────────────────────────────────┤
│ Project: maestro-orchestrator       │
│ Branch:  development                │
│ Health:  ██████████ 92/100  ✓       │
├─────────────────────────────────────┤
│ Skills: 109  Commands: 39  Agents: 6│
│ Hooks:  8/8 active  Workers: 6/6   │
│ Mirror: ✓ synced (109/109)         │
└─────────────────────────────────────┘
```

Reference: scripts/health-dashboard.sh (current version)
Reference: skills/dashboard/SKILL.md for dashboard skill patterns
