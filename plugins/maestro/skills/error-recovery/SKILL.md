---
name: error-recovery
description: "Intelligent error recovery that pattern-matches errors against a learned database before dispatching a fixer agent. Exact matches apply known fixes instantly. Similar matches seed the fixer with a hint. Novel errors go through standard self-heal and then save the solution as a new pattern. Integrates with learning-loop (pattern growth) and truth-verifier (fix validation)."
---

# Error Recovery

Goes beyond retry-based self-heal. Before dispatching a fixer agent, searches a persisted error pattern database for a known solution. If found, the fix is applied directly — no agent dispatch needed. If similar (but not exact), the pattern is passed as a hint to the fixer agent. If novel, standard self-heal runs and the resolution is saved for future use.

The pattern database grows automatically from successful fixes. Over time, recurring error classes resolve instantly without consuming agent tokens.

## When to Run

Error recovery replaces the self-heal step in the dev-loop. It runs whenever:

- A build step exits non-zero during the IMPLEMENT or CHECKPOINT phase
- A test suite run exits non-zero (failing tests, not zero tests)
- A lint or type-check command exits non-zero
- An implementer reports `STATUS: BLOCKED` due to a runtime error

Error recovery does **not** run for:
- `STATUS: NEEDS_CONTEXT` — those are missing-information problems, not fixable errors
- QA rejections — those go through the rework loop, not self-heal

## Error Pattern Database

Stored at `.maestro/error-patterns.md`. Each pattern is a structured record with enough signal for fuzzy matching.

### Pattern Record Format

```markdown
### Pattern: [short ID — e.g., EP-042]

- **Category**: build | runtime | test | lint | type
- **Signature**: [normalized error string — stripped of paths, line numbers, and variable names]
- **Fingerprint**: [hash of the normalized signature — for exact matching]
- **Fix**: [imperative action the fixer should take — or the exact command/edit to apply]
- **Fix type**: `instant` | `hint`
  - `instant` — fix can be applied as a known command or edit without an agent
  - `hint` — fix is a heuristic that seeds the fixer agent's context
- **Confidence**: [0.0–1.0 — grows with each successful application]
- **Occurrences**: [N — total times this pattern was matched and fix was applied]
- **Last seen**: [ISO date]
- **Source**: [auto-learned | manually-authored]
- **Verified by**: truth-verifier | manual

---
```

### Example Records

```markdown
### Pattern: EP-001

- **Category**: build
- **Signature**: "Cannot find module '<path>' or its corresponding type declarations"
- **Fingerprint**: a3f9c2
- **Fix**: Run `tsc --noEmit` to surface the exact missing export, then add the missing export to the relevant barrel file (index.ts). If the module is a new file, ensure it is added to the barrel before the import is used.
- **Fix type**: hint
- **Confidence**: 0.91
- **Occurrences**: 11
- **Last seen**: 2026-03-18
- **Source**: auto-learned
- **Verified by**: truth-verifier

---

### Pattern: EP-002

- **Category**: lint
- **Signature**: "ESLint: 'X' is defined but never used (no-unused-vars)"
- **Fingerprint**: b7e104
- **Fix**: Remove the unused variable declaration. If it is a destructured parameter, prefix with `_` to suppress the rule.
- **Fix type**: instant
- **Confidence**: 0.98
- **Occurrences**: 34
- **Last seen**: 2026-03-17
- **Source**: auto-learned
- **Verified by**: truth-verifier

---

### Pattern: EP-003

- **Category**: type
- **Signature**: "Type 'X | undefined' is not assignable to type 'X'"
- **Fingerprint**: c1d882
- **Fix**: Add a null guard before the assignment. Use optional chaining (`?.`) for property access or a non-null assertion (`!`) only when the value is guaranteed by invariant.
- **Fix type**: hint
- **Confidence**: 0.85
- **Occurrences**: 22
- **Last seen**: 2026-03-16
- **Source**: auto-learned
- **Verified by**: truth-verifier
```

## Error Normalization

Before searching the database, normalize the raw error output to remove volatile tokens. This makes fingerprinting stable across different projects and paths.

### Normalization Rules

| Replace | With |
|---------|------|
| Absolute paths (`/home/user/project/src/...`) | `<path>` |
| Relative paths (`./src/components/Button.tsx`) | `<path>` |
| Line and column numbers (`:42:7`) | `` |
| Variable names in quotes that change per invocation | `X` |
| Stack trace frames | `` |
| Timestamps | `` |
| Hash suffixes in module names | `` |

Normalization is applied to the first 3 lines of the error output. The normalized string is the **signature**. The **fingerprint** is a short hash (first 6 chars of SHA-256) of the signature.

### Normalization Example

Raw error:
```
/home/rodrigo/dev/myapp/src/components/Button.tsx:42:7 - error TS2322:
Type 'string | undefined' is not assignable to type 'string'.
  42       label={props.buttonLabel}
```

Normalized signature:
```
Type 'X | undefined' is not assignable to type 'X'.
```

Fingerprint: `c1d882` (matches EP-003 above)

## Match Protocol

When an error occurs, run this three-step lookup:

### Step 1 — Exact Match (fingerprint)

Compute the fingerprint of the normalized error signature. Search `error-patterns.md` for a record with the same fingerprint.

- **Match found, confidence >= 0.7** → apply the known fix (see Fix Application below)
- **Match found, confidence < 0.7** → use as hint (treat as Similar Match)
- **No match** → proceed to Step 2

### Step 2 — Similar Match (fuzzy)

Compare the normalized signature against all pattern signatures using token overlap. Score = `shared_tokens / max(len(query_tokens), len(pattern_tokens))`.

- **Score >= 0.6** → use the best-matching pattern as a hint for the fixer agent
- **Score < 0.6 for all patterns** → proceed to Step 3 (Novel Error)

### Step 3 — Novel Error

No existing pattern matches. Run the standard fixer agent dispatch (self-heal). After the fixer resolves the error:

1. Extract the fix from the fixer agent's output
2. Normalize the error to produce a signature and fingerprint
3. Save a new pattern record to `error-patterns.md` with `confidence: 0.5` and `occurrences: 1`
4. Log the new pattern to `.maestro/logs/error-recovery.md`

## Fix Application

### Instant Fix

When `fix_type: instant` and confidence >= 0.7:

1. Log the match to `.maestro/logs/error-recovery.md` (see Log Format)
2. Apply the fix command or edit directly — no agent dispatch
3. Re-run the failing command to verify the fix resolved the error
4. If the re-run passes → RESOLVED. Increment pattern `occurrences` and update `last_seen`.
5. If the re-run fails → degrade to Hint (dispatch fixer agent with the pattern as context)

Instant fixes must be deterministic. If the fix description contains branching language ("if", "or", "depending on") it should be classified `hint`, not `instant`.

### Hint

When a match exists but fix requires agent judgment:

Prepend this block to the fixer agent's context:

```
ERROR RECOVERY: Similar pattern found in database

Pattern: EP-042
Category: type
Signature: "Type 'X | undefined' is not assignable to type 'X'"
Confidence: 0.85 (22 prior occurrences)

Known fix approach:
  Add a null guard before the assignment. Use optional chaining (`?.`) for property
  access or a non-null assertion (`!`) only when the value is guaranteed by invariant.

Apply this approach if it fits the current error. If the fix approach does not apply,
ignore this hint and resolve the error using your own judgment.
```

The fixer agent proceeds with its normal logic. The hint is advisory only.

### No Match (Novel)

Dispatch the fixer agent with no pre-loaded hint. Standard self-heal protocol applies.

## Error Categories

| Category | Triggered by | Example patterns |
|----------|-------------|------------------|
| **build** | Build command exits non-zero | Missing module, missing export, import resolution failure |
| **runtime** | Process crashes or throws during execution | Null reference, undefined method, unhandled promise rejection |
| **test** | Test suite exits non-zero | Assertion failure, test timeout, snapshot mismatch |
| **lint** | Linter exits non-zero | Unused variable, wrong quote style, missing semicolon |
| **type** | Type checker exits non-zero | Type mismatch, missing property, incompatible types |

Each category has its own normalization heuristics for stripping volatile tokens. Build and type errors strip paths and line numbers. Lint errors strip variable names and values. Runtime errors strip stack traces and addresses.

## Pattern Growth

Patterns grow from two sources: auto-learning from successful fixes, and the learning-loop pipeline.

### Auto-Learning (per fix)

After every successful fixer agent run:

1. Normalize the original error to produce a signature
2. Check if the fingerprint already exists in `error-patterns.md`
3. **Existing pattern** → increment `occurrences`, update `last_seen`, recompute confidence (see Confidence Model below), verify by truth-verifier
4. **New pattern** → create a new record with `confidence: 0.5`, `occurrences: 1`, `source: auto-learned`

### Learning-Loop Integration

At the end of each milestone, the learning-loop RETRIEVE phase collects self-heal signals. Self-heal errors with 3+ fix attempts are marked as high-priority. learning-loop DISTILL may convert these into explicitly authored pattern records (with `source: manually-authored`) and write them to `error-patterns.md` with higher initial confidence.

Auto-learned patterns from error-recovery feed into learning-loop as `self_heal` signals. The two systems share the same signal pool — learning-loop provides the milestone-level view, error-recovery provides the per-error fix.

### Confidence Model

Confidence grows with successful applications and decays when a pattern fails:

| Event | Confidence change |
|-------|-----------------|
| Fix applied and verified | `+0.05` (capped at 1.0) |
| Fix applied, re-run failed | `-0.15` |
| Hint used, fixer succeeded | `+0.02` |
| Hint used, fixer failed | `-0.05` |

A pattern with confidence < 0.3 is flagged `status: degraded` and excluded from exact-match lookup (it may still appear in fuzzy results as a low-weight hint).

## Truth-Verifier Integration

After any instant fix is applied and the command re-run passes, invoke truth-verifier to confirm the fix did not introduce a new failure:

1. Re-run the full test suite (not just the failing command)
2. If all tests pass → mark fix as VERIFIED, update pattern confidence
3. If new failures appeared → mark fix as PARTIAL, revert, fall back to fixer agent dispatch

For hint-based fixes, truth-verifier runs as normal after the fixer agent completes (standard post-implementer verification).

## Log Format

All error-recovery activity appends to `.maestro/logs/error-recovery.md`.

```markdown
## Error Recovery Run — 2026-03-18T14:32:01Z — story-04

**Error class**: type
**Raw error** (first 3 lines):
```
/home/rodrigo/dev/myapp/src/api/handler.ts:88:14 - error TS2345:
Argument of type 'string | undefined' is not assignable to parameter of type 'string'.
```
**Normalized signature**: "Argument of type 'X | undefined' is not assignable to parameter of type 'X'."
**Fingerprint**: c1d882
**Match type**: exact (EP-003, confidence: 0.85)
**Fix type**: hint
**Fix applied**: fixer agent dispatched with hint
**Outcome**: RESOLVED (fixer agent succeeded, truth-verifier passed)
**Pattern confidence after**: 0.87
**Pattern occurrences after**: 23

---

## Error Recovery Run — 2026-03-18T15:01:44Z — story-05

**Error class**: lint
**Normalized signature**: "ESLint: 'X' is defined but never used (no-unused-vars)"
**Fingerprint**: b7e104
**Match type**: exact (EP-002, confidence: 0.98)
**Fix type**: instant
**Fix applied**: Removed unused variable `buttonVariant` from Button.tsx line 14
**Re-run result**: lint passed
**Outcome**: RESOLVED (instant fix, no agent dispatch)
**Pattern confidence after**: 0.98
**Pattern occurrences after**: 35

---

## Error Recovery Run — 2026-03-18T16:20:11Z — story-06

**Error class**: build
**Normalized signature**: "Module not found: Can't resolve '<path>' in '<path>'"
**Fingerprint**: d4f201
**Match type**: none (novel error)
**Fix type**: N/A — dispatched fixer agent (standard self-heal)
**Fixer outcome**: RESOLVED after 1 attempt
**New pattern saved**: EP-044 (confidence: 0.5, occurrences: 1)
```

## Pattern Pruning

Patterns are pruned on the CONSOLIDATE phase of each learning-loop run.

A pattern is pruned when:
- `confidence < 0.2` — too many failed applications
- `occurrences == 1` and `last_seen` is more than 20 milestones ago — rare and stale
- `status: degraded` and not seen in the last 10 milestones

Pruned patterns are removed from `error-patterns.md` and their IDs are logged to `.maestro/logs/error-recovery.md` under a `## Pruned Patterns` heading. IDs are not reused.

## Integration Points

| Skill | Integration |
|-------|-------------|
| **dev-loop** | error-recovery replaces the self-heal dispatch in Phase 4. dev-loop calls error-recovery with the raw error output and receives back either `resolved` (instant fix applied), `dispatched` (fixer agent sent with hint or no hint), or `failed` (fixer could not resolve). |
| **learning-loop** | learning-loop RETRIEVE reads `.maestro/logs/error-recovery.md` for self-heal signals. learning-loop CONSOLIDATE may write manually-authored patterns to `error-patterns.md` for high-confidence rules. The two skills share data but have separate write domains: error-recovery owns per-fix writes, learning-loop owns milestone-level consolidation. |
| **truth-verifier** | After every instant fix, error-recovery calls the truth-verifier protocol (re-run full test suite) before marking the fix resolved. For hint-based fixes, truth-verifier runs at the normal post-implementer stage. |
| **self-correct** | When a fixer agent resolves a novel error, error-recovery saves the pattern. self-correct may also write to `dna.md` if the same error class appears 3+ times — the two systems are complementary. self-correct handles correction-based learning; error-recovery handles fix-pattern storage and retrieval. |
| **delegation** | When error-recovery dispatches a fixer agent with a hint, it passes the hint block as the leading context in the fixer's prompt. delegation constructs the full context package as normal — error-recovery only provides the hint prefix. |
| **audit-log** | Log a `self_heal` decision entry for each error-recovery run: input = raw error, decision = `instant_fix` / `hint_dispatch` / `novel_dispatch`, outcome = resolved / failed. |
