---
name: anthropic
description: "Default Claude API provider via Anthropic"
default: true
---

# Anthropic Provider

## Authentication
- **Method**: API key via `ANTHROPIC_API_KEY` environment variable
- **Fallback**: Claude Code's built-in authentication (no key needed when running inside Claude Code)

## Model Catalog

| Model ID | Tier | Context Window | Best For |
|----------|------|----------------|----------|
| claude-opus-4-6 | premium | 200K | Architecture, complex reasoning, multi-file changes |
| claude-sonnet-4-6 | standard | 200K | Implementation, code generation, standard tasks |
| claude-haiku-4-5 | budget | 200K | Simple fixes, formatting, quick lookups |

## Rate Limit Handling
- Respect `Retry-After` headers on 429 responses
- Exponential backoff: 1s, 3s, 9s, 27s
- After 4 retries, escalate to model-failover skill
- Log rate limits to `.maestro/logs/rate-limits.log`

## Cost Per Token (approximate)

| Model | Input (per 1M) | Output (per 1M) |
|-------|----------------|-----------------|
| opus | $15.00 | $75.00 |
| sonnet | $3.00 | $15.00 |
| haiku | $0.25 | $1.25 |
