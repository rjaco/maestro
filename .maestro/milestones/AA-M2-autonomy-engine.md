---
id: AA-M2
title: Autonomy Engine & Action Classification
status: pending
stories: 4
depends_on: AA-M1
---

# AA-M2: Autonomy Engine & Action Classification

## Purpose
Configurable autonomy — classify every external action by risk level, enforce approval policies, track spending, and allow runtime mode switching.

## Stories

### S5: Action Classifier
Classify actions into three tiers:
- **Free**: Read-only operations, status checks, listing resources (always auto-approve)
- **Reversible-paid**: Creating cloud instances, starting services (auto under spending limit)
- **Irreversible**: Domain purchases, sending emails to clients, deleting resources (confirm per mode)
- Classification metadata in service skill definitions

### S6: Approval Engine with Three Modes
- **Full-auto**: All actions auto-approved. Maximum speed for overnight runs.
- **Tiered**: Free=auto, reversible-paid=auto under limit, irreversible=always confirm
- **Manual**: Always ask before any external action
- Approval prompts sent to ALL connected channels (CLI + messaging)
- Response accepted from ANY channel (first response wins)

### S7: Spending Limit Tracker
- Per-action limit (default $50)
- Per-session limit (default $500)
- Per-day limit (default $1000)
- Configurable in `.maestro/config.yaml` under `autonomy.spending`
- Running total tracked in `.maestro/spending-log.yaml`
- Alert when approaching limits (80% threshold)

### S8: Runtime Mode Switching
- `/maestro autonomy full-auto` — switch to full autonomy
- `/maestro autonomy tiered` — switch to tiered approval
- `/maestro autonomy manual` — switch to manual
- `/maestro autonomy status` — show current mode and spending
- Mode switchable via messaging channel: "Switch to tiered approval"
- Persisted in state.local.md, takes effect immediately

## Acceptance Criteria
1. Actions correctly classified by risk tier
2. Three autonomy modes all work correctly
3. Spending tracked accurately with configurable limits
4. Mode switchable at runtime without restart
5. Approval prompts reach all connected channels
