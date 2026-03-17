---
name: ship
description: "Final verification and shipping. Creates PR with full summary, runs quality gates, updates living docs."
---

# Ship

The final step in the Maestro pipeline. Runs comprehensive verification, generates a PR with a detailed description, updates living documentation, and optionally creates a CHANGELOG entry. Ensures everything is clean before code leaves the local machine.

## When to Use

- After a feature completes (all stories done, committed)
- After a milestone or full Opus session completes
- When the user explicitly requests shipping: `/maestro ship`

## Pre-Ship Verification

### Step 1: Full Test Suite

Run the complete test suite, not just story-specific tests:

```bash
npm test
```

If tests fail, display the failures and ask the user:
```
Pre-ship verification failed: [N] test(s) failing.

  [test failure output]

Options:
  [1] Fix the failures and re-run ship
  [2] Ship anyway (not recommended)
  [3] Abort shipping
```

### Step 2: Type Check

```bash
npx tsc --noEmit
```

Exclude pre-existing errors documented in `.maestro/dna.md` (e.g., `@opennextjs/cloudflare` type errors). Only flag new errors introduced by the feature.

### Step 3: Lint Check

```bash
npm run lint
```

If the project does not have a lint command, skip this step.

### Step 4: Lighthouse (if applicable)

If the feature includes UI components and a dev server is available:
- Run Lighthouse on affected pages
- Check thresholds: Performance > 80, Accessibility > 90

Skip for backend-only, API-only, or CLI features.

### Step 5: Opus Quality Gate (optional)

If the ship skill is invoked after an Opus session or for a large feature (5+ stories), dispatch an Opus-model reviewer to examine the complete diff:

```bash
git diff main...HEAD
```

The reviewer checks:
- Cross-story integration issues
- Architectural coherence
- Security surface
- Performance concerns
- Dead code from iterative development

## PR Generation

### Step 1: Gather Context

Read these files to build the PR description:
- `.maestro/state.local.md` — Session metadata
- `.maestro/stories/` — All story specs for this feature
- Git log for the feature branch commits

### Step 2: Generate PR Description

Create the PR using `gh pr create`:

```bash
gh pr create --title "[type]: [concise feature description]" --body "$(cat <<'EOF'
## Summary

[2-4 bullet points describing what this PR delivers]

## Stories Completed

| # | Title | Type |
|---|-------|------|
| 1 | [title] | [type] |
| 2 | [title] | [type] |

## Key Changes

- [Major change 1: what and why]
- [Major change 2: what and why]

## Testing

- [N] new tests added
- Full test suite passing ([N] tests)
- TypeScript clean
- [Lighthouse scores if applicable]

## QA Summary

- Stories: [N] completed
- QA first-pass rate: [N]%
- Self-heal cycles: [N]

## Files Changed

- Created: [N] files
- Modified: [N] files

---
Built with [Maestro](https://github.com/maestro-org/maestro) — autonomous development orchestrator
EOF
)"
```

### Step 3: Invoke External PR Review (if available)

If `pr-review-toolkit:review-pr` is available as a skill, invoke it on the newly created PR to get an independent review.

## Post-Ship Updates

### CHANGELOG Entry

If a `CHANGELOG.md` exists in the project root, append an entry:

```markdown
## [Unreleased]

### Added
- [New features from this PR]

### Changed
- [Modified behaviors]

### Fixed
- [Bug fixes]
```

If no CHANGELOG exists, skip this step. Do not create one unless the user requests it.

### Living Docs

Update `.maestro/state.md` (persistent project state):

```markdown
## Features Completed
- [timestamp] [feature name] — [N] stories, [N] commits
```

Update `.maestro/roadmap.md` if this was a milestone shipment:
- Mark the milestone as `shipped`
- Add the PR URL and ship date

### Token Ledger

Add a final summary row to `.maestro/token-ledger.md`:

```markdown
| [date] | **[feature] shipped** | PR #[N] | **[total]** | **$[cost]** | | |
```

## Output

Display the ship summary:

```
Shipped: [feature name]

  PR: [PR URL]
  Stories: [N]
  Commits: [N]
  Tests: [N] passing
  Total cost: ~$[N]

  Living docs updated.
  Ready for review and merge.
```
