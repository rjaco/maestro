---
id: AA-M6
title: Task Chains & Enhanced Daemon
status: pending
stories: 3
depends_on: [AA-M3, AA-M5]
---

# AA-M6: Task Chains & Enhanced Daemon

## Purpose
Multi-service task orchestration and 24/7 autonomous operation. Complex workflows that span multiple services with rollback on failure and remote command integration.

## Stories

### S19: Multi-Service Task Chain Orchestrator
- Define task chains as sequences of service actions
- Each step specifies: service, action, inputs, outputs, rollback action
- Chain execution with dependency resolution
- Output of one step can feed into the next (e.g., domain ID → DNS setup)
- Example chain: buy domain → configure DNS → deploy app → set up email → announce
- Chain templates for common workflows

### S20: Rollback Engine
- Track all executed actions with their rollback operations
- On failure at step N, rollback steps N-1 through 1 in reverse
- Irreversible actions (domain purchase) logged but not rollbackable
- Partial rollback for mixed chains
- Rollback receipts sent to notification hub

### S21: Enhanced Daemon with Remote Command Integration
- Daemon accepts commands from ALL connected channels (Telegram, Slack, Teams, Discord)
- Command parsing from natural language messages
- Task queue for async execution
- Session persistence across daemon restarts
- Budget tracking persisted across daemon restarts
- Graceful shutdown with state save
- Crash recovery with pending task resume

## Acceptance Criteria
1. Multi-step chains execute end-to-end with output forwarding
2. Rollback correctly reverses reversible actions on failure
3. Daemon accepts and processes commands from messaging channels
4. State persists across daemon restarts
5. Budget tracking accurate across long daemon sessions
