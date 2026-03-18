---
name: speculative
description: "Speculative execution patterns using forkSession + enableFileCheckpointing + rewindFiles(). Try multiple approaches and keep the best result. Integrates with dev-loop, checkpoint, gcr-loop, and dev-loop SELF-HEAL phase."
---

# Speculative Execution

Try an approach. Evaluate it. If it fails, rewind and try another. Keep the best result. No manual undo, no risky exploratory commits.

## What Is Speculative Execution

Speculative execution forks the current session before attempting a risky approach, tracks all file changes via checkpointing, and rolls back cleanly if the approach fails. The agent explores without fear — every branch is reversible.

This is distinct from `checkpoint` (which snapshots git state for revert) and `gcr-loop` (which iterates a single artifact). Speculation branches at the strategy level: different approaches are tried independently before any is committed.

## SDK API Mapping

| SDK Parameter | Purpose |
|---------------|---------|
| `forkSession: true` | Create an independent session branch; changes are isolated from the parent |
| `enableFileCheckpointing: true` | Track all file writes and edits so `rewindFiles()` can undo them |
| `rewindFiles()` | Roll back all file changes since the checkpoint; leaves git history clean |
| `maxTurns` | Cap exploration depth per branch (default: 30 turns) |

## Use Cases

**1. Architecture Exploration** — Try 2-3 structural approaches (e.g., REST vs GraphQL vs tRPC). Evaluate test pass rate, code delta, and schema fit. Rewind losing branches. Keep the winner.

**2. Risky Refactoring** — Attempt a large refactor (e.g., class components to hooks) in a fork. Run tests. If they fail and auto-fix cannot resolve, rewindFiles() and leave the codebase untouched.

**3. Test-First Experimentation** — Write tests, then try implementations in separate forks until one turns green. Tests are written once and shared; implementations are speculative.

**4. Performance Optimization** — Apply an optimization (e.g., memoization, query batching) in a fork. Benchmark. If slower than baseline, rewindFiles(). Log the delta either way.

**5. Dependency Upgrade** — Upgrade `package.json` and lockfile in a fork. Run `npm install && npm test`. If breaking, rewindFiles(), log which tests failed, report to user.

**6. Multi-Strategy Comparison** — Run all branches to completion, then pick the best by score (test count, error count, benchmark delta, line count).

## Execution Pattern

```
1. CHECKPOINT       — Create named checkpoint via `checkpoint` skill (pre-spec-{story-slug})
2. FORK SESSION     — forkSession=true, enableFileCheckpointing=true
3. TRY APPROACH A   — Agent runs with maxTurns cap (default: 30)
4. EVALUATE         — Tests pass? Benchmark met? QA rubric passes?
5a. IF SUCCESS      — Record outcome. Continue to compare or commit.
5b. IF FAILURE      — rewindFiles(). Log what failed and why.
6. TRY APPROACH B   — Fork again from the same checkpoint
7. EVALUATE         — Same criteria as step 4
8. COMPARE          — If both succeeded, apply the better-scoring result
9. COMMIT           — Winning approach goes through normal git-craft flow
```

When two branches both pass, prefer the one with fewer lines and higher test count.

### Branch Evaluation Criteria

Score each completed branch before selecting the winner:

| Criterion | Signal |
|-----------|--------|
| Test pass rate | All pass preferred; tie-break on count |
| Compilation | Zero errors required |
| Code delta | Fewer net lines for equivalent functionality |
| Benchmark delta | Measured improvement over baseline (optimization stories) |
| QA rubric | APPROVED > REJECTED (if gcr-loop is in use) |

## Integration with Existing Skills

**dev-loop (IMPLEMENT phase)** — Add `speculative: true` and `speculative_approaches: [...]` to a story spec. The implementer runs each approach in a forked session. The first approach satisfying all acceptance criteria wins. If none pass within 3 branches, fall through to standard SELF-HEAL escalation.

**checkpoint** — Always invoke `checkpoint` before starting speculation (name: `pre-spec-{story-slug}`). This is the clean revert point if `rewindFiles()` itself encounters an unexpected issue.

**gcr-loop** — With `gcr_speculative: true`, the Generator produces N candidate artifacts speculatively (one per fork, max 3). The Critic evaluates all candidates and the Refiner improves the best-scoring one — useful when the problem space is wide and a single first draft will likely miss.

**dev-loop (SELF-HEAL phase)** — When auto-fix fails after 3 attempts, try speculative fix strategies before escalating to the user: (A) regenerate the failing file from scratch, (B) revert to pre-story state and re-implement from the failure message, (C) apply the fix under stricter constraints. If all three fail, escalate with all three failure logs.

## Safety Rules

1. **Max 3 speculative branches per story.** More than 3 signals an underspecified story — PAUSE and ask the user to clarify the approach instead.
2. **Timeout per branch: 5 minutes (default).** Configurable via `speculative_timeout_minutes`. A timeout counts as a failure — rewind and try the next branch.
3. **Always checkpoint before starting.** If the checkpoint step fails, abort speculation and use the standard approach.
4. **Never speculate on production deployments.** Speculation is for local file changes and test runs only. Infrastructure, CI/CD, and live-environment configs must use standard execution.
5. **Log all attempts.** Every branch is logged to `.maestro/speculation/{story-slug}.md`: approach description, outcome, evaluation scores, and whether `rewindFiles()` was called.

## Speculation Log Format

```
## Speculation: {story-slug}
Checkpoint: pre-spec-{story-slug}

### Branch 1: {approach}
Outcome: FAIL — 3/8 tests failing (type mismatch in parseResponse)
rewindFiles(): called

### Branch 2: {approach}
Outcome: PASS — 8/8 tests, +42/-11 lines
Selected: YES

### Summary
Winner: Branch 2 | Committed: feat(api): add response validation via Zod
```
