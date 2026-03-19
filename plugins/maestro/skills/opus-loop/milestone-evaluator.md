# Milestone Evaluator — Acceptance Criteria Verification

Evaluates whether a completed milestone meets its acceptance criteria. Runs automated checks, dispatches an Opus-quality reviewer, and generates fix stories if issues are found.

## When to Run

After all stories in a milestone have passed individual QA and been committed. This is the integration-level quality gate — it catches issues that per-story reviews miss.

## Evaluation Steps

### Step 1: Automated Checks

Run the project's verification suite. Detect available tools from `.maestro/dna.md`:

```bash
# 1. TypeScript compilation (if tsconfig.json exists)
npx tsc --noEmit 2>&1

# 2. Linting (detect linter from package.json scripts)
# Try in order: npm run lint, npx eslint ., npx biome check
npm run lint 2>&1

# 3. Full test suite (detect runner from package.json)
# Try in order: npm test, npx vitest run, npx jest
npm test 2>&1

# 4. Build check (ensure project builds — catches import errors)
npm run build 2>&1
```

**Pre-existing error handling:**
- Read `.maestro/dna.md` for documented pre-existing errors (e.g., `@opennextjs/cloudflare` type errors).
- Run checks and capture ALL output.
- Filter out known pre-existing errors from the failure list.
- Only NEW errors count as milestone failures.

**How to detect new vs. pre-existing errors:**
1. If DNA documents the error pattern → pre-existing.
2. If the error references a file NOT created/modified in this milestone → likely pre-existing.
3. If the error references a file created/modified in this milestone → NEW (counts as failure).
4. When in doubt, count it as new (false positives are safer than false negatives).

### Step 2: Lighthouse Audit (if applicable)

Trigger conditions (ALL must be true):
- Milestone includes stories that created/modified files in `src/app/`, `src/pages/`, `src/components/`, or similar UI directories
- `package.json` has a `dev` or `start` script
- The project has a web framework (Next.js, Remix, Nuxt, SvelteKit, etc.)

**Execution protocol:**

```bash
# 1. Start dev server in background
npm run dev &
DEV_PID=$!

# 2. Wait for server to be ready (max 30 seconds)
for i in {1..30}; do
  curl -s http://localhost:3000 > /dev/null 2>&1 && break
  sleep 1
done

# 3. Run Lighthouse CLI (if available)
npx lighthouse http://localhost:3000 --output=json --chrome-flags="--headless --no-sandbox" 2>/dev/null

# 4. If Lighthouse CLI not available, use Playwright MCP for screenshots
# Navigate to each affected page and take screenshots for visual verification

# 5. Clean up
kill $DEV_PID 2>/dev/null
```

**Thresholds:**

| Category | Minimum | Critical (auto-fix) |
|----------|---------|-------------------|
| Performance | 80 | < 60 |
| Accessibility | 90 | < 80 |
| Best Practices | 85 | < 75 |
| SEO | 85 (public pages only) | < 70 |

Skip Lighthouse for: backend-only milestones, API-only milestones, CLI tools, libraries.

### Step 3: Acceptance Criteria Review

Read the milestone spec from `.maestro/milestones/MN-slug.md`. For EACH acceptance criterion, follow this verification protocol:

#### Evidence Types

| Criterion Type | Evidence Required | How to Verify |
|---------------|------------------|--------------|
| "Users can [action]" | Test that exercises the action | `grep -r "test.*[action keyword]" --include="*.test.*"` to find the test, then check it passes |
| "API endpoint: [method] [path]" | Route file exists + test | Check file exists at expected path, check test covers the endpoint |
| "Page at [URL]" | Route/page component exists | Check file at the expected path in the app router |
| "Lighthouse [metric] > N" | Lighthouse output | From Step 2 results |
| "All tests passing" | Test suite output | From Step 1 results |
| "Mobile-responsive" | Responsive CSS/Tailwind | Check for responsive breakpoints in component files |
| "JSON-LD structured data" | Script tag in page | `grep -r "application/ld+json"` in relevant page files |

#### Verification Decision Tree

```
For each criterion:
  1. Identify the evidence type (from table above)
  2. Run the verification check
  3. If evidence found AND passes → PASS
  4. If evidence found but fails → FAIL with specific failure reason
  5. If no evidence found → FAIL with "No implementation found for: [criterion]"
```

#### Scoring

Each criterion gets one of three scores:

| Score | Meaning | Example |
|-------|---------|---------|
| PASS | Criterion fully met with evidence | Test passes, file exists, metric above threshold |
| PARTIAL | Criterion partially met | "Mobile-responsive" but only for 1 of 3 pages |
| FAIL | Criterion not met | No test, no implementation, metric below threshold |

**Milestone passes if:** ALL criteria are PASS. Any FAIL triggers auto-fix. PARTIAL criteria are flagged but don't block (they become fix stories).

### Step 4: Opus Quality Gate

Dispatch an Opus-model reviewer to examine the combined diff of the ENTIRE milestone. This catches cross-story integration issues that per-story QA misses.

**What to send to the reviewer:**

```bash
# Get the combined diff for all milestone stories
# Assumes stories were committed sequentially on the feature branch
git log --oneline --format="%H %s" | grep "Story: MN-" | awk '{print $1}' > /tmp/milestone-commits.txt
FIRST_COMMIT=$(tail -1 /tmp/milestone-commits.txt)
git diff ${FIRST_COMMIT}^..HEAD
```

**Reviewer focus areas:**

1. **Cross-story integration:**
   - Do API routes match what the frontend expects?
   - Are type definitions consistent across all stories?
   - Is state management coherent (no conflicting stores/contexts)?
   - Do imports resolve correctly across story boundaries?

2. **Architectural coherence:**
   - Does the combined code follow project DNA patterns?
   - Any anti-patterns introduced (circular dependencies, god components)?
   - Is the file structure consistent with project conventions?

3. **Security surface:**
   - New user input → validation present?
   - New API routes → authentication/authorization applied?
   - New data queries → injection protection in place?
   - Secrets or tokens → not hardcoded?

4. **Performance:**
   - Any N+1 queries across the combined data access patterns?
   - Any unbounded lists without pagination?
   - Any large synchronous operations on the main thread?

5. **Dead code and leftovers:**
   - Code from early stories that later stories made obsolete?
   - Unused imports, variables, or functions?
   - TODO comments that should have been resolved within the milestone?

**Confidence scoring applies:** Only issues with confidence >= 80 are reported.

### Step 5: Generate Verdict

Combine all evaluation results into a structured report:

```
========================================
Milestone Evaluation: M[N] — [name]
========================================

Automated Checks:
  TypeScript:  [PASS/FAIL] ([N] errors, [M] pre-existing excluded)
  Linting:     [PASS/FAIL] ([N] errors, [M] warnings)
  Tests:       [PASS/FAIL] ([N] passing, [M] failing, [K] skipped)
  Build:       [PASS/FAIL]
  Lighthouse:  [PASS/SKIP/FAIL] (perf: [N], a11y: [N], bp: [N], seo: [N])

Acceptance Criteria: [passed]/[total]
  [x] Criterion 1 — PASS: [evidence]
  [x] Criterion 2 — PASS: [evidence]
  [~] Criterion 3 — PARTIAL: [what's missing]
  [ ] Criterion 4 — FAIL: [reason]

Opus Quality Gate: [APPROVED / REJECTED]
  Issues: [N] (confidence >= 80)
  [list each issue if rejected]

VERDICT: MILESTONE_PASSED / MILESTONE_FAILED

Failed items requiring fix:
  1. [specific failure with root cause]
  2. [specific failure with root cause]
```

**Decision logic:**

```
IF all automated checks PASS
  AND all acceptance criteria PASS
  AND Opus quality gate APPROVED
THEN MILESTONE_PASSED

IF any automated check FAIL (excluding pre-existing)
  OR any acceptance criterion FAIL
  OR Opus quality gate REJECTED with security/correctness issues
THEN MILESTONE_FAILED

IF only PARTIAL criteria or non-critical Opus warnings:
  Generate fix stories but mark milestone as MILESTONE_PASSED_WITH_WARNINGS
  (proceed to next milestone, fix stories queued for later)
```

## Auto-Fix Protocol

If the verdict is MILESTONE_FAILED:

1. **Parse failures into discrete issues.** Each issue must be:
   - Specific (one failure per issue)
   - Actionable (clear what needs to change)
   - Testable (clear how to verify the fix)

2. **Generate fix stories** (max 3 per fix cycle):
   ```yaml
   ---
   id: MN-FIX-01
   slug: fix-[issue-slug]
   title: "Fix: [concise issue description]"
   model_recommendation: sonnet
   type: [inferred from the issue — backend, frontend, test, etc.]
   parallel_safe: true
   ---
   ## Acceptance Criteria
   1. [The specific check that must now pass]

   ## Context for Implementer
   - Error output: [exact error message or failing criterion]
   - Affected files: [file paths with line numbers if available]
   - Root cause analysis: [what the evaluator believes is wrong]
   - Suggested approach: [minimal fix, not refactor]
   ```

3. **Execute fix stories** via dev-loop in yolo mode. Fix stories can run in parallel if independent.

4. **Re-run this evaluator** (Step 1-5 again).

5. **Track fix cycle count.** Maximum 3 cycles per milestone.

6. **After 3 failed fix cycles:**
   - PAUSE execution
   - Present ALL unresolved issues with full context
   - Ask user via AskUserQuestion:
     - "Fix manually, then resume"
     - "Skip this milestone"
     - "Abort Opus session"
   - Do NOT loop indefinitely

## Metrics Output

After evaluation (pass or fail), append metrics to the milestone's retrospective data:

```yaml
evaluation_metrics:
  automated_checks:
    tsc: pass
    lint: pass
    tests: { pass: 23, fail: 0, skip: 2 }
    build: pass
    lighthouse: { perf: 87, a11y: 95, bp: 90, seo: 88 }
  acceptance_criteria:
    total: 8
    passed: 7
    partial: 1
    failed: 0
  opus_gate:
    verdict: approved
    issues_found: 0
    false_positives: 0
  fix_cycles_needed: 0
  time_elapsed: "3m 45s"
```

These metrics feed into the retrospective for self-improvement between milestones.
