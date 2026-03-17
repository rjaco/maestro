# Milestone Evaluator — Acceptance Criteria Verification

Evaluates whether a completed milestone meets its acceptance criteria. Runs automated checks, dispatches an Opus-quality reviewer, and generates fix stories if issues are found.

## When to Run

After all stories in a milestone have passed individual QA and been committed. This is the integration-level quality gate — it catches issues that per-story reviews miss.

## Evaluation Steps

### Step 1: Automated Checks

Run the project's verification suite:

```bash
# TypeScript compilation
npx tsc --noEmit

# Linting
npm run lint

# Full test suite (not just story-specific tests)
npm test
```

Record pass/fail for each check. If the project DNA documents known pre-existing errors (e.g., `@opennextjs/cloudflare` type errors), exclude those from the evaluation.

### Step 2: Lighthouse Audit (if applicable)

If the milestone includes UI components and a dev server is available:

1. Start the dev server if not already running
2. Run Lighthouse on affected pages
3. Check against thresholds:
   - Performance > 80
   - Accessibility > 90
   - Best Practices > 85
   - SEO > 85 (if the product has public-facing pages)

Skip this step for backend-only, API-only, or CLI milestones.

### Step 3: Acceptance Criteria Review

Read the milestone spec from `.maestro/milestones/MN-slug.md`. For each acceptance criterion:

1. Identify the evidence that proves the criterion is met
2. Verify the evidence:
   - Test output that exercises the criterion
   - File that implements the feature
   - API response that demonstrates the behavior
   - UI state that shows the expected result
3. Mark each criterion as PASS or FAIL with evidence

### Step 4: Opus Quality Gate

Dispatch an Opus-model reviewer agent to examine the combined diff of all stories in this milestone.

```yaml
name: opus-gate-reviewer
model: opus
tools: [Read, Bash, Grep, Glob]
maxTurns: 30
```

The reviewer checks:
- **Cross-story integration**: Do the stories work together? Are there interface mismatches, missing glue code, or inconsistent state management?
- **Architectural coherence**: Does the milestone's implementation align with the project DNA and architecture?
- **Security surface**: Any new attack vectors introduced across the combined changes?
- **Performance**: Any O(N^2) loops, unbounded queries, or memory leaks across the combined code?
- **Dead code**: Any code from early stories that later stories made obsolete?

Confidence scoring applies: only issues with confidence >= 80 are reported.

### Step 5: Generate Verdict

Combine all evaluation results:

```
Milestone Evaluation: M[N] — [name]

Automated Checks:
  TypeScript: [PASS/FAIL]
  Linting:    [PASS/FAIL]
  Tests:      [PASS/FAIL] ([N] passing, [N] failing)
  Lighthouse: [PASS/SKIP/FAIL] (perf: [N], a11y: [N], bp: [N])

Acceptance Criteria:
  [x] Criterion 1 — [evidence]
  [x] Criterion 2 — [evidence]
  [ ] Criterion 3 — FAIL: [reason]

Opus Quality Gate:
  [APPROVED / REJECTED with issues]

VERDICT: MILESTONE_PASSED / MILESTONE_FAILED
```

## Auto-Fix Protocol

If the verdict is MILESTONE_FAILED:

1. Collect all failures into a list of discrete, fixable issues.
2. For each issue, generate a fix story:
   ```yaml
   ---
   id: MN-FIX-01
   slug: fix-[issue-slug]
   title: "Fix: [concise issue description]"
   model_recommendation: sonnet
   type: [inferred from the issue]
   ---
   ## Acceptance Criteria
   1. [The specific check that must pass]

   ## Context for Implementer
   - Error output: [exact error message or failing criterion]
   - Affected files: [file paths]
   - Root cause analysis: [what the evaluator believes is wrong]
   ```
3. Execute fix stories via dev-loop in yolo mode.
4. Re-run this evaluator.
5. Track fix cycle count. Maximum 3 cycles per milestone.

If after 3 fix cycles the milestone still fails, PAUSE execution and present the unresolved issues to the user. Do not loop indefinitely.
