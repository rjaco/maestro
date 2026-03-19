---
id: AA-M4
title: Core Service Integration Skills
status: pending
stories: 4
depends_on: [AA-M1, AA-M2]
---

# AA-M4: Core Service Integration Skills

## Purpose
Service-specific skills that teach Maestro how to interact with the most common external services. Each skill wraps an API, CLI tool, or MCP server with Maestro-aware action classification and notification hooks.

## Stories

### S12: Cloud Provider Skills
Skills for provisioning and managing cloud infrastructure:
- **AWS**: EC2, S3, Route53, Lambda, RDS via `aws` CLI
- **Vercel**: Deploy, domains, env vars via `vercel` CLI
- **DigitalOcean**: Droplets, apps, domains via `doctl` CLI
- **Cloudflare**: Workers, Pages, R2 via `wrangler` CLI
- Each skill declares action classifications (free: list, paid: create, irreversible: delete)

### S13: Domain & DNS Skills
- **Cloudflare DNS**: Add/modify/delete records, manage zones
- **Namecheap**: Domain search, purchase, transfer, renewal via API
- Domain purchase classified as irreversible (always confirm in tiered mode)
- DNS changes classified as reversible-paid

### S14: Communication Skills
- **SendGrid**: Send emails, manage templates, track delivery via API
- **Twilio**: Send SMS, make calls, manage phone numbers via API
- Email to clients classified as irreversible
- Internal notifications classified as free

### S15: Payment & Commerce Skills
- **Stripe**: Create products, manage subscriptions, process payments via API
- Payment processing classified as irreversible
- Product/price management classified as reversible-paid
- Read-only (list charges, check balance) classified as free

## Acceptance Criteria
1. Each service skill works end-to-end with real credentials
2. Action classifications correct for each operation
3. Skills follow service registry pattern (credentials from registry)
4. Error messages are actionable (not raw API errors)
5. Skills document required CLI tools or API keys in frontmatter
