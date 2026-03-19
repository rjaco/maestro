---
name: ollama
description: "Local LLM provider via Ollama"
default: false
---

# Ollama Provider

## Authentication
- **Method**: None (local API)
- **Endpoint**: `http://localhost:11434` (configurable via `OLLAMA_HOST`)

## Requirements
- `requires.bins: [ollama]`
- Ollama must be running: `ollama serve`

## Model Catalog

| Model ID | Tier | Context Window | Best For |
|----------|------|----------------|----------|
| llama3.1:70b | standard | 128K | Implementation, general coding |
| llama3.1:8b | budget | 128K | Simple tasks, quick fixes |
| codellama:34b | standard | 16K | Code-specific tasks |
| deepseek-coder:33b | standard | 16K | Code generation |

## Rate Limit Handling
- No rate limits (local)
- Queue requests if GPU is busy
- Timeout after 5 minutes per request

## Cost Per Token
- $0.00 (local compute only)
- Track GPU time instead of token cost
