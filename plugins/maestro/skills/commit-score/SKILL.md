---
name: commit-score
description: "Score each commit on quality: tests, conventions, message quality, cleanliness. Track average per project."
effort: low
maxTurns: 3
disallowedTools:
  - Write
  - Edit
---

# Commit Quality Score

Rate each commit on 4 dimensions (0-25 each, total 0-100). Produce a badge, a breakdown, and persist the result to `.maestro/trust.yaml`.

## Dimensions

### 1. Tests Included (0-25)

Measures whether the commit ships proof that the code works.

| Condition | Score | Reasoning |
|-----------|-------|-----------|
| Test files present AND all tests pass | 25 | Full coverage shipped with the change |
| Test files present AND some tests fail | 12 | Tests exist but the commit is broken — partial credit only |
| No new tests but existing suite still passes | 8 | No regression, but no new coverage either |
| No test files and no test infrastructure exists | 5 | New project, infrastructure not yet set up |
| No test files and test infrastructure exists | 0 | Tests are expected but missing |

**Earns points:**
- Adding a `*.test.*`, `*.spec.*`, or `__tests__/*` file alongside changed source files.
- Tests covering the new behavior introduced, not just happy-path smoke tests.
- Integration tests in addition to unit tests.

**Loses points:**
- Deleting existing test files without replacement.
- Skipping (`it.skip`, `xit`, `pytest.mark.skip`) previously passing tests.
- Committing with a broken test suite (`--no-verify` bypass or failing CI).

---

### 2. Conventions Followed (0-25)

Measures how well the commit matches the project's established DNA patterns. DNA is derived from the five most recently edited files in the same directory.

| Check | Points | How to Verify |
|-------|--------|---------------|
| File naming matches convention | 5 | Compare to sibling files: kebab-case, PascalCase, snake_case |
| Export style matches (named vs. default) | 5 | Check existing files in same module for default vs. named exports |
| Import ordering follows project pattern | 5 | stdlib → third-party → internal → relative; check 3 existing files |
| Component / function structure matches | 5 | Arrow fn vs. function declaration, hook placement, return shape |
| Styling approach matches project | 5 | Tailwind utilities, CSS modules, styled-components — must be consistent |

**Earns points:**
- Following the pattern set by surrounding files even if the pattern is unconventional.
- Adding new files that could pass as existing ones without any style friction.

**Loses points:**
- Mixing export styles (some files default, new file named) without justification.
- Introducing a new styling method in a project already committed to one approach.
- Deviating from import order in a project that enforces it via ESLint.
- Adding a new file naming convention (e.g., `userService.ts` in a `user-service.ts` project).

---

### 3. Message Quality (0-25)

Measures whether future engineers can understand this commit without reading the diff.

| Check | Points | Pass Condition |
|-------|--------|---------------|
| Follows conventional commits format | 10 | Subject line is `type(scope): description` — type is one of: feat, fix, chore, refactor, test, docs, style, perf, ci |
| Description is meaningful | 5 | Subject not just "fix", "update", "wip", "changes", or a file name |
| Body explains WHY, not just WHAT | 5 | Body present AND contains reasoning, not just a restatement of the diff |
| References story or issue | 5 | Body or footer contains `Story:`, `Fixes #`, `Closes #`, or `Ref:` |

**Earns points:**
- Breaking changes flagged with `BREAKING CHANGE:` footer.
- Linking to the relevant story file path.
- Body that explains the trade-off considered, not just the decision made.

**Loses points:**
- Subject line longer than 72 characters.
- Capitalizing the subject after the colon (`feat: Add user` instead of `feat: add user`).
- Ending subject with a period.
- Vague verbs: "fix issue", "handle case", "update code", "misc changes".

---

### 4. Code Cleanliness (0-25)

Measures whether the commit is production-ready or still in draft state.

| Check | Points | What to Look For |
|-------|--------|-----------------|
| No TODO/FIXME/HACK introduced | 10 | `git diff` for lines beginning with `+` that contain these tokens |
| No console.log / print / pp left in | 7 | Language-appropriate debug print statements in non-test files |
| No commented-out code | 5 | Lines beginning with `+` that are pure comments containing code syntax |
| No debugging artifacts | 3 | debugger statements, breakpoints, `binding.pry`, `dd()`, `dump()` |

**Earns points:**
- Removing existing TODO/FIXME comments that were already in the file (net negative = bonus consideration).
- Clean, self-documenting code that needs no inline explanations.

**Loses points:**
- `console.log("here")`, `console.log(variable)` in non-test source files.
- Blocks of commented-out code that represent "just in case" fallbacks.
- `// TODO: fix this later` added in the same PR the code was written.
- Any `debugger;` statement in JavaScript/TypeScript.

---

## Grade Thresholds

| Score | Badge | What It Means |
|-------|-------|---------------|
| 90-100 | Gold | Exemplary. Ready to merge without review concerns. |
| 75-89 | Silver | Good. Minor imperfections but no blockers. |
| 60-74 | Bronze | Acceptable. At least one dimension needs attention. |
| <60 | Needs Work | Should not merge until issues are resolved. |

Note: The previous Silver threshold was 70. It has been raised to 75 to align with the trust-level escalation criteria.

---

## Example Scoring Walkthrough

**Commit:** `feat(auth): add JWT refresh token endpoint`

**Diff summary:** Added `src/auth/refresh.ts`, added `src/auth/refresh.test.ts` with 4 passing tests, no body in commit message, one `console.log("token refreshed")` left in the source file.

| Dimension | Raw Score | Notes |
|-----------|-----------|-------|
| Tests | 25 | Test file present, all 4 passing |
| Conventions | 23 | File naming correct (-0), exports correct (-0), import order off by one group (-2) |
| Message | 15 | Conventional commits format (+10), meaningful description (+5), no body (-5), no story ref (-5) |
| Cleanliness | 18 | No TODO/HACK (+10), console.log present (-7), no commented code (+5), no debugger (+3) |
| **Total** | **81** | **Silver** |

```
  Commit score: 81/100 (Silver)
    Tests        25/25  all passing
    Conventions  23/25  import order misaligned
    Message      15/25  missing body and story reference
    Clean        18/25  console.log in refresh.ts:42
```

---

## Output Format

```
  Commit score: 85/100 (Silver)
    Tests        25/25
    Conventions  20/25  (default export used once — project uses named exports)
    Message      20/25  (body missing — add reasoning for the approach chosen)
    Clean        20/25  (1 TODO added at auth/session.ts:88)
```

If score is below 60, append a one-line action recommendation per failing dimension:

```
  [!] Needs Work: Tests — add tests for the error paths in middleware.ts
  [!] Needs Work: Message — rewrite subject; "fix stuff" is not meaningful
```

---

## Integration with trust.yaml

After scoring, append the result to `.maestro/trust.yaml`:

```yaml
commit_scores:
  average: 82
  last_5: [85, 80, 90, 75, 80]
  trend: stable          # improving | stable | declining
  gold: 3
  silver: 8
  bronze: 2
  needs_work: 0
```

**Trend calculation:**
- Compare the average of the last 3 scores against the average of the 3 before that.
- If delta > +5 points: `improving`
- If delta < -5 points: `declining`
- Otherwise: `stable`

The `average` commit score feeds into trust-level calculation. A declining trend at journeyman or expert level triggers a trust-level review in the next retrospective.
