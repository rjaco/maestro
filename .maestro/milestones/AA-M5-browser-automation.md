---
id: AA-M5
title: Browser Automation Agent
status: pending
stories: 3
depends_on: [AA-M2, AA-M4]
---

# AA-M5: Browser Automation Agent

## Purpose
Playwright-based agent for interacting with ANY website that doesn't have an API. Create accounts, fill forms, make purchases, post content, manage dashboards.

## Stories

### S16: Browser Session Manager
- Persistent browser profiles stored in `.maestro/browser-profiles/`
- Cookie and auth state preservation between sessions
- Profile per service/website (e.g., `twitter-profile`, `namecheap-profile`)
- Login flow executor with credential retrieval from service registry
- Screenshot capture at each step for audit trail

### S17: Universal Form Filler & Purchase Flow
- Intelligent form detection and filling using page snapshots
- Multi-step form flows (checkout, registration, configuration)
- CAPTCHA detection with notification to user (cannot auto-solve)
- Payment form filling using tokenized card data from service registry
- Confirmation page verification before final submit
- Purchase actions always classified as irreversible

### S18: Social Media Posting Agent
- Platform-specific posting skills: Twitter/X, LinkedIn, Instagram
- Image/media upload support
- Hashtag and mention handling
- Post scheduling via the existing scheduler skill
- Social media posts classified as irreversible (public-facing)

## Acceptance Criteria
1. Browser profiles persist authentication between sessions
2. Form filler handles multi-step flows reliably
3. Purchase flows stop at confirmation page for verification
4. Social media posts work on at least 3 platforms
5. All browser actions captured in screenshot audit trail
