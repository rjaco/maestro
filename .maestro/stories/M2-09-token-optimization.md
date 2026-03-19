---
id: M2-09
slug: token-optimization
title: "Token optimization — pattern caching, batch dispatch, cost tracking"
type: feature
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced skill `skills/token-ledger/SKILL.md` with new capabilities (expand by 80+ lines):
   - **Per-story cost tracking**: Log actual token usage per story (input + output + cache)
   - **Cost-per-LOC metric**: Track tokens per line of code produced (efficiency indicator)
   - **Budget forecasting**: Based on historical cost-per-story, predict remaining budget for milestone
2. Enhanced skill `skills/context-engine/SKILL.md` with optimization:
   - **Context deduplication**: Detect and remove duplicate content across context sources
   - **Relevance threshold**: Only include files scoring > 0.3 relevance (reduce noise)
   - **Cache-friendly ordering**: Order context to maximize Anthropic's prompt caching hit rate
3. New section in `skills/cost-routing/SKILL.md`:
   - **Batch dispatch**: Group independent stories and dispatch in parallel to reduce overhead
   - **Cost ceiling**: Per-story cost ceiling that triggers model downgrade if exceeded
4. Cost dashboard updated with new metrics
5. Mirror: all changes in both root and plugins/maestro/

## Context for Implementer

Ruflo claims 30-50% token reduction through ReasoningBank retrieval (32%), WASM transforms (15%), caching (10%), and batching (20%). Maestro can't use WASM, but can optimize:

1. **Context deduplication**: When composing context, check for duplicate file contents (e.g., same helper file referenced by multiple stories). Remove duplicates.
2. **Cache-friendly ordering**: Anthropic's prompt caching works on prefix matches. Put stable context (CLAUDE.md, DNA, steering) at the top, volatile context (story spec, recent changes) at the bottom. This maximizes cache hits.
3. **Per-story tracking**: After each story, log: story_id, model_used, input_tokens, output_tokens, cache_read, cache_create, total_cost.
4. **Cost-per-LOC**: Total tokens / lines of code changed. Track over time to measure efficiency improvements.

Reference: skills/token-ledger/SKILL.md for current tracking
Reference: skills/cost-routing/SKILL.md for current routing
Reference: skills/context-engine/SKILL.md for context composition
Reference: skills/cost-dashboard/SKILL.md for visualization
