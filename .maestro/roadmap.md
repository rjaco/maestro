# Opus Roadmap — UX Enhancement & Autonomy Deepening

## Wave 9: UX & Autonomy (active)

| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| UX-M1 | 3 | pending | Command Discovery & Help System |
| UX-M2 | 3 | pending | Onboarding & Setup Wizard |
| UX-M3 | 3 | pending | Rich Dashboard & Visualization |
| UX-M4 | 3 | pending | Smart Autonomy Enhancements |
| UX-M5 | 3 | pending | Error UX & Self-Healing |

**Total: 15 stories across 5 milestones**

### Dependency Graph

```
UX-M1 (Command Discovery) ──→ UX-M2 (Onboarding)
         │                           │
         └───────────┬───────────────┘
                     ↓
             UX-M3 (Dashboard)
                     ↓
             UX-M4 (Smart Autonomy)
                     ↓
             UX-M5 (Error UX)
```

---

## UX-M1: Command Discovery & Help System
Make 50+ commands discoverable through categorization, search, and suggestions.
- S1: Categorized command index in help (dev, autonomous, admin, monitoring)
- S2: Command search and fuzzy matching
- S3: Context-aware command suggestions after task completion

## UX-M2: Onboarding & Setup Wizard
Guided onboarding for autonomous features.
- S4: `/maestro setup` — unified autonomous setup wizard
- S5: First-run detection and guided tutorial
- S6: Service quick-connect templates (one-command setup)

## UX-M3: Rich Dashboard & Visualization
Enhanced dashboard with service status, spending, and task chains.
- S7: Service connection status widget in dashboard
- S8: Spending tracker and autonomy mode display
- S9: Task chain progress visualization

## UX-M4: Smart Autonomy Enhancements
Proactive capability discovery and intelligent task routing.
- S10: Proactive service suggestion (detect needed services and offer to connect)
- S11: Smart task routing (API vs CLI vs browser auto-selection)
- S12: Auto-capability expansion (suggest installing missing CLI tools)

## UX-M5: Error UX & Self-Healing
Actionable errors and graceful degradation.
- S13: Error message enhancer (every error gets a fix suggestion)
- S14: Enhanced self-healing with recovery strategies
- S15: Graceful degradation (continue with reduced capabilities)

---

## Previous Waves (complete)

### Wave 8: Autonomous Agent (complete)
| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| AA-M1 | 4 | complete | Service Registry & Credential Management |
| AA-M2 | 4 | complete | Autonomy Engine & Action Classification |
| AA-M3 | 3 | complete | Enhanced Notification Hub |
| AA-M4 | 4 | complete | Core Service Integration Skills |
| AA-M5 | 3 | complete | Browser Automation Agent |
| AA-M6 | 3 | complete | Task Chains & Enhanced Daemon |
