---
name: truth-verifier
description: "Verify every claim in an implementer's status report before proceeding to QA. Catches contradicted claims, logs trust issues, and auto-reverts worktrees that contradict their own reports."
---

# Truth Verifier

After an implementer reports DONE, verify every factual claim in its status report against observable reality. Inspired by Ruflo's truth verification system that auto-rollbacks on failed assertions.

## When to Run

- **Automatically** — after every implementer reports `STATUS: DONE`, before Phase 5 (QA review) begins
- **Never skipped** — even if the implementer is a trusted model or the story is trivial
- **Not for NEEDS_CONTEXT or BLOCKED** — those are not factual claims about completed work

## Claim Parsing

Parse the implementer's status report to extract verifiable claims. Claims appear in two blocks: the summary header and the per-AC lines.

### Claim Types and Parsers

| Claim pattern | Parser | Verification command |
|---------------|--------|----------------------|
| `Tests: N passing` | Extract N | Run test suite, count passing tests |
| `Tests: N passing, M failing` | Extract N, M | Run test suite, compare counts |
| `Files: path/to/file (created)` | Extract path | `stat path/to/file` — must exist |
| `Files: path/to/file (modified)` | Extract path | `git diff HEAD -- path/to/file` — must have changes |
| `AC1: [description] — PASS` | Extract AC text | Criterion-specific check (see below) |
| `AC1: [description] — FAIL` | Skip — already failing | No verification needed |

Parse ALL claims, not just the ones that look suspicious.

### Claim Extraction Example

Given this status report:
```
STATUS: DONE
Tests: 5 passing
Files: src/components/PriceTable.tsx (created), src/lib/pricing.ts (modified)
AC1: Side-by-side layout renders correctly — PASS
AC2: Prices sort ascending/descending — PASS
AC3: Empty state shows placeholder — PASS
```

Extract:
1. Claim: "Tests: 5 passing" → type=test_count, expected=5
2. Claim: "src/components/PriceTable.tsx (created)" → type=file_exists, path=src/components/PriceTable.tsx
3. Claim: "src/lib/pricing.ts (modified)" → type=file_modified, path=src/lib/pricing.ts
4. Claim: "AC1: Side-by-side layout renders correctly — PASS" → type=ac_pass, text=...
5. Claim: "AC2: Prices sort ascending/descending — PASS" → type=ac_pass, text=...
6. Claim: "AC3: Empty state shows placeholder — PASS" → type=ac_pass, text=...

## Verification Protocol

For each extracted claim, run the corresponding check and score it.

### Test Count Verification

```bash
# Run the project's test command (from package.json or DNA)
npm test 2>&1
# or: pytest, cargo test, go test ./..., etc.
```

Parse the output for pass/fail counts. Compare against the claimed number.

- If claimed 5 passing and test run shows 5 passing → VERIFIED
- If claimed 5 passing and test run shows 4 passing → CONTRADICTED
- If test command not found or exits with unexpected error → UNVERIFIED

### File Existence Verification

```bash
stat {path}
```

- File exists → VERIFIED (for `created` claims)
- File does not exist → CONTRADICTED
- Permission error or ambiguous → UNVERIFIED

### File Modified Verification

```bash
git diff HEAD -- {path}
# Also check against pre-implementation baseline if available
git diff {base-commit}..HEAD -- {path}
```

- Diff is non-empty → VERIFIED (for `modified` claims)
- Diff is empty → CONTRADICTED (file exists but was not changed)
- File does not exist → CONTRADICTED

### AC Verification

AC verification uses heuristic matching. This is best-effort — some ACs cannot be automatically verified.

**For each AC claim, attempt these checks in order:**

1. **Test name match** — scan test output for a test name that contains key words from the AC description. If found and passing → VERIFIED.
2. **File content match** — if the AC mentions a specific output or UI element (e.g., "shows placeholder"), grep the relevant file for that string or a close variant. Present → VERIFIED.
3. **Cannot automate** — if neither check applies → UNVERIFIED (not CONTRADICTED).

The heuristic is intentionally conservative: only mark VERIFIED when confidence is high. When in doubt, mark UNVERIFIED.

## Scoring

Every claim gets exactly one score:

| Score | Meaning |
|-------|---------|
| **VERIFIED** | Claim matches observable reality |
| **UNVERIFIED** | Cannot automatically check; claim neither confirmed nor denied |
| **CONTRADICTED** | Claim does NOT match observable reality |

## Decision Rules

After all claims are scored:

| Condition | Action |
|-----------|--------|
| All claims VERIFIED or UNVERIFIED | Proceed to QA with confidence note |
| 1+ claims CONTRADICTED | BLOCK — do not proceed to QA; log trust issue; trigger auto-rollback |
| All claims UNVERIFIED (no test runner, no files checkable) | Proceed to QA with low-confidence note; flag for manual QA depth |

## Trust Log

All verification runs are appended to `.maestro/trust.yaml`.

```yaml
# .maestro/trust.yaml
verifications:
  - timestamp: 2026-03-18T14:32:01Z
    story: "03-add-price-table"
    agent_id: "implementer-a3f1"
    worktree: ".worktrees/story-03"
    status: PASS  # PASS | FAIL
    claims:
      - text: "Tests: 5 passing"
        type: test_count
        expected: 5
        actual: 5
        score: VERIFIED
      - text: "src/components/PriceTable.tsx (created)"
        type: file_exists
        path: "src/components/PriceTable.tsx"
        score: VERIFIED
      - text: "AC1: Side-by-side layout renders correctly — PASS"
        type: ac_pass
        score: UNVERIFIED
        note: "No matching test name found; AC is visual"
    contradicted_count: 0
    unverified_count: 1
    trust_score: 0.83  # verified / total
```

When `status: FAIL`, also append to the trust issue index:

```yaml
trust_issues:
  - timestamp: 2026-03-18T15:01:44Z
    story: "04-add-sort"
    agent_id: "implementer-b7d2"
    contradicted_claims:
      - text: "Tests: 5 passing"
        expected: 5
        actual: 3
    action_taken: rollback
```

## Auto-Rollback

When any claim is CONTRADICTED:

**Step 1: Log the trust issue** (as above).

**Step 2: Revert the worktree.**
```bash
cd {worktree_path}
git reset --hard {base-commit}
```
The base commit is the commit the worktree branched from, recorded in `.maestro/state.local.md`.

**Step 3: Re-dispatch the implementer.**
Send the original story prompt with this prefix:

```
TRUTH VERIFICATION FAILED on previous attempt.

Contradicted claims:
- [list each CONTRADICTED claim and what was actually found]

The previous implementation was reverted. You are starting from a clean state.
Pay close attention to:
1. Reporting accurate test counts — run the tests before reporting
2. Confirming files exist before listing them as created
3. Verifying your own claims before submitting STATUS: DONE
```

**Step 4: Cap retries at 2.** If truth verification fails twice for the same story, BLOCK and surface to the user with the full trust log excerpt. Do not attempt a third auto-dispatch.

## Verification Output Block

After verification completes, append this block to the dev-loop's execution log and pass it to the QA reviewer as context:

```
TRUTH VERIFICATION RESULT
Story: [story-id]
Agent: [agent-id]
Status: PASS | FAIL
Verified: N/T claims (N verified, M unverified, K contradicted)
Trust score: X.XX
Confidence for QA: HIGH | MEDIUM | LOW
Notes: [any UNVERIFIED claims with reason]
```

**Confidence mapping:**
- `verified / total >= 0.8` → HIGH
- `0.5 <= verified / total < 0.8` → MEDIUM
- `verified / total < 0.5` → LOW (proceed to QA but flag for deep review)

## Integration Points

**dev-loop/SKILL.md** — truth verification runs as Phase 4.5, between self-heal (Phase 4) and QA review (Phase 5). It is non-optional.

**multi-review/SKILL.md** — pass the verification output block as the first item of context to the QA reviewer. QA uses the confidence level to calibrate review depth (HIGH = standard review, LOW = deep review).

**audit-log/SKILL.md** — log a `truth_verification` decision entry when any claim is CONTRADICTED, with the contradicted claims as input state and `rollback + re-dispatch` as the decision.

**self-correct/SKILL.md** — if the same agent produces CONTRADICTED claims on 2+ separate stories, trigger a self-correct signal of type `qa_rejection` targeting the implementer's system prompt.
