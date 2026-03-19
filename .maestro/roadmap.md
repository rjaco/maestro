# Opus Roadmap — Autonomous Agent: Universal Task Execution

## Wave 8: Autonomous Agent (active)

| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| AA-M1 | 4 | pending | Service Registry & Credential Management |
| AA-M2 | 4 | pending | Autonomy Engine & Action Classification |
| AA-M3 | 3 | pending | Enhanced Notification Hub |
| AA-M4 | 4 | pending | Core Service Integration Skills |
| AA-M5 | 3 | pending | Browser Automation Agent |
| AA-M6 | 3 | pending | Task Chains & Enhanced Daemon |

**Total: 21 stories across 6 milestones**

### Dependency Graph

```
AA-M1 (Service Registry) ──→ AA-M2 (Autonomy Engine)
         │                           │
         ├───────────────────────────┤
         ↓                           ↓
   AA-M3 (Notifications)     AA-M4 (Service Skills)
         │                           │
         └─────────────┬─────────────┘
                       ↓
               AA-M5 (Browser Automation)
                       ↓
               AA-M6 (Task Chains & Daemon)
```

---

## AA-M1: Service Registry & Credential Management
Foundation layer — how Maestro discovers, connects to, and authenticates with external services.
- S1: Service registry format and config skill
- S2: Three-tier credential manager (MCP / vault / env)
- S3: Service health check and validation
- S4: Connect/disconnect commands and status display

## AA-M2: Autonomy Engine & Action Classification
Configurable autonomy — classify actions and enforce approval policies.
- S5: Action classifier (free / reversible-paid / irreversible)
- S6: Approval engine with three modes (full-auto / tiered / manual)
- S7: Spending limit tracker (per-action / per-session / per-day)
- S8: Runtime mode switching via CLI and messaging channels

## AA-M3: Enhanced Notification Hub
All-channel notifications with configurable levels — every action notified.
- S9: Notification levels (all / important / critical / none)
- S10: Action receipts — notify even auto-approved actions
- S11: Approval prompts via messaging channels (Telegram/Slack/Teams/Discord)

## AA-M4: Core Service Integration Skills
Service-specific skills for the most common external services.
- S12: Cloud provider skills (AWS CLI, Vercel, DigitalOcean, Cloudflare)
- S13: Domain & DNS skills (Cloudflare DNS, Namecheap API)
- S14: Communication skills (SendGrid email, Twilio SMS)
- S15: Payment & commerce skills (Stripe API)

## AA-M5: Browser Automation Agent
Playwright-based agent for ANY website without an API.
- S16: Browser session manager (cookies, profiles, auth state)
- S17: Universal form filler and purchase flow executor
- S18: Social media posting agent (Twitter/X, LinkedIn, Instagram)

## AA-M6: Task Chains & Enhanced Daemon
Multi-service orchestration and 24/7 autonomous operation.
- S19: Multi-service task chain orchestrator
- S20: Rollback engine for failed chains
- S21: Enhanced daemon with remote command channel integration

---

## Previous Waves (complete)

### Quality Refinement (complete)
| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| QR-M1 | 4 | complete | Critical data integrity fixes |
| QR-M2 | 3 | complete | Shell script security hardening |
| QR-M3 | 3 | complete | Consistency & polish |
| QR-M4 | 2 | complete | Mirror sync & credential masking |

### Wave 7 (complete)
| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| W7-M1 | 6 | complete | Hook coverage & zero-code wins |
| W7-M2 | 4 | complete | Quality & testing |
| W7-M3 | 4 | complete | Developer experience polish |

### Wave 6 (complete)
| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| M1 | 4 | complete | Full-auto reliability |
| M2 | 3 | complete | Multi-instance coordination |
| M3 | 3 | complete | Communication channels |
| M4 | 3 | complete | Enhanced SOUL & personality |
| M5 | 4 | complete | Ruflo feature adoption |
| M6 | 3 | complete | OpenClaw-inspired enhancements |
