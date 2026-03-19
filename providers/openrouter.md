---
name: openrouter
description: "Multi-model provider via OpenRouter API"
default: false
---

# OpenRouter Provider

## Authentication
- **Method**: API key via `OPENROUTER_API_KEY` environment variable
- **Endpoint**: `https://openrouter.ai/api/v1`

## Requirements
- `requires.env: [OPENROUTER_API_KEY]`

## Model Catalog

Access to 100+ models across providers. Maestro maps its tiers to OpenRouter models:

| Maestro Tier | Default OpenRouter Model | Fallback |
|-------------|--------------------------|----------|
| premium | `anthropic/claude-opus-4-6` | `openai/gpt-4o` |
| standard | `anthropic/claude-sonnet-4-6` | `openai/gpt-4o-mini` |
| budget | `anthropic/claude-haiku-4-5` | `google/gemini-2.0-flash` |

## Rate Limit Handling
- Respect `Retry-After` headers
- Automatic model fallback within same tier
- Log provider switches to `.maestro/logs/provider-routing.log`

## Cost Per Token
- Varies by model — see OpenRouter pricing
- Track via OpenRouter's usage API
