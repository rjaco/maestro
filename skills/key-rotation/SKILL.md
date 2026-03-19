---
name: key-rotation
description: "API key rotation on 429 rate-limit responses. Round-robin across comma-separated ANTHROPIC_API_KEYS, sticky on success, with Retry-After backoff when all keys are exhausted. Key rotation runs before model escalation."
---

# Key Rotation

Rotates API keys automatically when a 429 rate-limit response is received. Designed for users running multiple Claude Code instances or planning multi-provider support. Keys are never logged by value — only by index.

**Note:** Claude Code manages its own API key internally. This skill applies when Maestro is running in a context where it manages API calls directly, such as multi-instance setups or future provider integrations.

## Configuration

Set a comma-separated list of API keys in the environment:

```bash
export ANTHROPIC_API_KEYS=key1,key2,key3
```

If `ANTHROPIC_API_KEYS` is not set, key rotation is disabled and standard single-key behavior applies. The skill is a no-op in that case.

## Key Indexing

Keys are indexed from 1 (not 0) in all logs and state fields, so the first key is `key_1`, the second is `key_2`, etc. Key values are never written to any log, state file, or output. Only the index is recorded.

```
ANTHROPIC_API_KEYS=keyA,keyB,keyC

key_1 → keyA   (active at start)
key_2 → keyB
key_3 → keyC
```

## Rotation Strategy

### Sticky on Success

The active key stays in use as long as requests succeed. No round-robin polling — rotation only happens on a 429.

```
Request → key_1 → 200 OK   → stay on key_1
Request → key_1 → 200 OK   → stay on key_1
Request → key_1 → 429      → rotate to key_2
Request → key_2 → 200 OK   → stay on key_2 (now sticky)
```

### Round-Robin on 429

When a 429 is received, advance to the next key in the list. If the last key is active, wrap around to key_1.

```
key_1 → 429 → try key_2
key_2 → 429 → try key_3
key_3 → 429 → try key_1  (wrap)
key_1 → 429 → all keys exhausted → Retry-After backoff
```

"All keys exhausted" is defined as: a full cycle was attempted (every key returned 429 in this rotation pass) without a successful response.

### Retry-After Backoff (Exhaustion)

When all keys are exhausted, read the `Retry-After` header from the last 429 response:

| `Retry-After` present | Behavior |
|-----------------------|----------|
| Yes, value N seconds | Wait N seconds, then retry from key_1 |
| No header | Exponential backoff: 30s, 60s, 120s, then fail |

Log the wait at each step:

```
[key-rotation] All keys exhausted. Retry-After: 45s. Waiting before retry from key_1.
```

## State Fields

Written to `.maestro/state.local.md` under `key_rotation`:

| Field | Type | Description |
|-------|------|-------------|
| `key_rotation.active_index` | integer | Index of the currently active key (1-based) |
| `key_rotation.total_keys` | integer | Total number of configured keys |
| `key_rotation.rotation_count` | integer | Cumulative number of rotations this session |
| `key_rotation.last_429_at` | ISO 8601 | Timestamp of the most recent 429 |
| `key_rotation.exhaustion_count` | integer | Times all keys were exhausted this session |

State is reset at each session start.

## Rotation Sequence

```
Receive 429 response
        │
        ▼
Compute next_index = (active_index % total_keys) + 1
        │
        ▼
Log: [key-rotation] 429 on key_{active}. Rotating to key_{next}.
        │
        ▼
Update active_index = next_index in state
        │
        ▼
Retry request with new key
        │
     ┌──┴──┐
   200 OK  429
     │      │
     ▼      ▼
  Stay   Is this a full cycle?
  sticky    │
          ┌─┴────┐
         Yes    No
          │      │
          ▼      ▼
    Retry-After  Continue
    backoff      rotating
```

## Security Requirements

- Never write a key value to any file, log, or output message.
- Never include key values in audit-log entries.
- Only log the key index (`key_1`, `key_2`, etc.).
- If `ANTHROPIC_API_KEYS` is logged for debug purposes, mask all but the last 4 characters of each key.

## Log Format

All key-rotation events use this prefix and format:

```
[key-rotation] 429 on key_1. Rotating to key_2. (rotation 3 this session)
[key-rotation] key_2 succeeded. Sticky on key_2.
[key-rotation] All 3 keys exhausted. Waiting 45s (Retry-After). Will retry from key_1.
[key-rotation] key rotation disabled — ANTHROPIC_API_KEYS not set.
```

## Integration with Model Failover

Key rotation happens **before** model escalation. When a 429 is received:

1. Attempt key rotation (this skill).
2. If rotation succeeds (a key returns 200) — model escalation is not triggered.
3. If all keys are exhausted and backoff also fails — then hand off to model-failover for escalation.

This ordering prevents unnecessary model upgrades when the rate limit is a quota issue, not a capability issue.

```
429 received
     │
     ▼
key-rotation: try next key
     │
  ┌──┴──┐
 OK   exhausted
  │      │
  ▼      ▼
done  model-failover escalates
```

## Integration Points

| Skill / Component | Integration |
|-------------------|-------------|
| `delegation/SKILL.md` | Wraps API calls; on 429, invokes key-rotation before retrying or escalating |
| `model-failover` (if present) | Receives handoff only after all keys are exhausted and backoff fails |
| `audit-log/SKILL.md` | Rotation events logged as `key_rotation` entries with index only, no key values |
| `token-ledger/SKILL.md` | Records which key index was active when tokens were consumed (for per-key usage analysis) |
| `cost-dashboard/SKILL.md` | Displays per-key rotation counts and exhaustion events for quota visibility |
