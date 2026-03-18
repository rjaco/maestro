---
name: feature-registry
description: "Durable requirements registry for multi-session continuity. Creates and manages .maestro/registry.json — a ground-truth record that survives context resets."
---

# Feature Registry

A persistent, append-only requirements registry that enables seamless session handoff. The registry is the ground truth for feature completion — not conversation history, not git log, not state files.

## Registry Format

Create `.maestro/registry.json`:

```json
{
  "feature": "User Authentication",
  "created": "2026-03-18",
  "requirements": [
    {
      "id": "REQ-001",
      "description": "Login endpoint accepts email/password",
      "verification": "POST /api/auth/login returns 200 with JWT",
      "passes": false,
      "priority": 1,
      "implemented_in": null,
      "session_id": null
    },
    {
      "id": "REQ-002",
      "description": "JWT tokens expire after 15 minutes",
      "verification": "Token decoded shows exp claim 15min from iat",
      "passes": false,
      "priority": 2,
      "implemented_in": null,
      "session_id": null
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `id` | Unique identifier, format `REQ-NNN` |
| `description` | What the requirement is |
| `verification` | Explicit, runnable step to confirm completion |
| `passes` | `false` until verified. Never revert once `true` |
| `priority` | Execution order. Lower number = higher priority |
| `implemented_in` | Commit SHA set when `passes` becomes `true` |
| `session_id` | Session ID recorded alongside `implemented_in` |

## Registry Rules

**Immutable entries**: Requirements are never deleted. If a requirement is wrong, add a replacement and mark the old one `passes: true` with `[SUPERSEDED by REQ-NNN]` in the description.

**Append-only**: New requirements are appended to the array. Existing entries update only `passes`, `implemented_in`, and `session_id` — and only to record completion.

**Verification-driven**: Every requirement must have a concrete verification step. Reject vague entries:
- Bad: "Login works" — Good: "POST /api/auth/login returns 200 and `{token: string}`"
- Bad: "Tests pass" — Good: "`npm test -- --grep 'auth'` exits 0, 8 tests pass"

**Priority-ordered**: Sessions always pick the lowest `priority` number with `passes: false`. Ties broken by `id` ascending.

## Session Workflow

**On session start:**
1. Read `.maestro/registry.json`
2. Sort incomplete entries by `priority` ascending, then `id` ascending
3. Take the first — this is the active requirement
4. Log: `[REQ-NNN] Starting: [description]`

**Execute:** Implement the requirement using TDD. Write a failing test, make it pass, refactor.

**Verify:** Run the exact `verification` string from the registry. Do not substitute a different check. The verification step is the contract.

**Update:** Once verification passes, write to the registry immediately:
```json
{ "passes": true, "implemented_in": "<commit SHA>", "session_id": "<session id>" }
```

**Continue:** Pick the next incomplete entry. Repeat until none remain or context approaches capacity.

## Generation from Stories

When decompose creates story files, also generate registry entries. Each acceptance criterion in a story becomes one registry entry.

```
Story 01-auth-api.md:
  AC1: Login endpoint accepts email/password   → REQ-001 (priority: 1)
  AC2: JWT tokens expire after 15 minutes      → REQ-002 (priority: 2)

Story 02-auth-refresh.md:
  AC1: Refresh tokens are single-use           → REQ-003 (priority: 3)
```

Priority is assigned sequentially across stories in dependency order. Generate a concrete `verification` string for each AC — include HTTP method and expected response for endpoints, DOM selectors for UI, exact test commands for test criteria.

If a registry already exists (resuming a feature), append only new entries. Do not overwrite completed entries.

## Handoff Protocol

Context approaching the limit is a planned handoff, not a failure.

**When context reaches ~80% capacity:**
1. Mark any in-progress requirement as incomplete (do not falsely set `passes: true`)
2. Write registry to disk
3. Save handoff state to `.maestro/state.local.md`:
   ```yaml
   registry_handoff:
     timestamp: "2026-03-18T14:23:00Z"
     last_completed: "REQ-003"
     next_pending: "REQ-004"
   ```
4. Commit: `chore(registry): checkpoint — REQ-001 through REQ-003 complete`
5. Log: "Context limit reached. New session: read `.maestro/registry.json`, resume at REQ-004."

**On session resume**, the new session does NOT need conversation history:
1. Read `.maestro/registry.json`
2. Find the first `passes: false` entry by priority
3. Confirm: "Resuming at REQ-004: [description]. Verification: [verification]. Proceed?"
4. Continue the session workflow

**Emergency handoff** (crash, timeout): the last committed registry is the recovery point. Discard in-flight work; the next session restarts the interrupted requirement from scratch.

## Integration Points

**opus-loop**: After each story completes, update registry entries for all ACs in that story. Between milestones, commit registry state as a resumability checkpoint. On `/maestro magnum-opus --resume`, read the registry instead of reconstructing from context.

**decompose**: After writing story files, run registry generation. Log: "Registry generated: [N] requirements from [M] stories." Present the registry entry count in the approval summary alongside the story list.

**dev-loop**: After Phase 6 (Git Craft), mark corresponding registry entries `passes: true` with the commit SHA. Include registry delta in the commit message: `Registry: REQ-001 through REQ-003 now pass`.

**ship**: Before generating the PR, read the registry and include a completion table in the PR body:

```markdown
## Requirements Registry

[N]/[total] verified

| ID | Description | Status |
|----|-------------|--------|
| REQ-001 | Login endpoint accepts email/password | PASS |
```

If any entries are still `passes: false`, surface a warning — do not block the ship. The user may have intentionally deferred some requirements.
