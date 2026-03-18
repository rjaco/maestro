---
name: semantic-diff
description: "Generate architectural-impact explanations of code changes. Goes beyond line diffs to explain WHAT changed and WHY it matters — capabilities, contracts, and risk."
---

# Semantic Diff

Produces a structured explanation of code changes at three levels: line, function, and architecture. The goal is not to restate what `git diff` already shows, but to explain the architectural significance of those changes.

## When to Generate

- **After each story completes** — before QA review begins
- **During ship** — included in the PR body (see `ship/SKILL.md`)
- **On user request** — for any commit range: `/semantic-diff <ref>..<ref>`
- **In build-log export** — included in the blog narrative format

## Output Format

```markdown
## Semantic Diff: Story 03 — Add OAuth Login

### What Changed
- **New capability**: OAuth2 login flow with Google and GitHub providers
- **New dependency**: `passport` + `passport-google-oauth20` + `passport-github2`
- **API surface**: +3 endpoints (`/auth/google`, `/auth/github`, `/auth/callback`)

### Architectural Impact
- **Auth layer**: Extended from email/password only to multi-provider
- **Session model**: Now stores provider info + access tokens
- **Database**: Added `oauth_accounts` table (1:N with users)

### Risk Assessment
- **Breaking changes**: None (additive only)
- **Security surface**: New OAuth token storage (encrypted at rest)
- **Performance**: No impact (new endpoints, existing ones unchanged)

### Files Changed (5)
| File | Change Type | Impact |
|------|------------|--------|
| src/auth/oauth.ts | NEW | Core OAuth flow |
| src/auth/types.ts | MODIFIED | Added OAuthAccount type |
| src/routes/auth.ts | MODIFIED | Added 3 OAuth routes |
| migrations/003_oauth.sql | NEW | oauth_accounts table |
| tests/auth/oauth.test.ts | NEW | OAuth flow tests |
```

## Generation Method

**Step 1: Gather changed files** — run `git diff --stat <base>..<head>`. Use change magnitude (+lines/-lines) to prioritize reading order; large diffs in core files warrant deeper analysis.

**Step 2: Read the diffs** — run `git diff <base>..<head> -- <file>` per file. For files with >200 changed lines, focus on exported symbols, function signatures, and type definitions.

**Step 3: Three-level analysis** — analyze each file at all three levels before writing output:

- **Line level**: added/removed imports, changed signatures, modified constants, deleted code paths
- **Function level**: new functions or methods, modified signatures vs. body-only changes, removed functions, restructured classes
- **Architecture level**: new external dependencies, API endpoints added/removed/changed, database schema changes, new auth requirements, changed data flow, new background jobs

**Step 4: Synthesize** — collapse the analysis into the output format. Prioritize architectural observations. Line-level details belong only in the Files Changed table.

## Risk Assessment Categories

All four dimensions must appear in every output. If a category has no risk, write "None."

**Breaking changes** — removed or renamed exports, changed function signatures (parameters without defaults), removed API endpoints, database column removed or retyped.

**Security surface** — new auth or authorization logic, new endpoints accepting user input, new calls to external services, new token or credential storage, changed permission checks.

**Performance impact** — new database queries in hot paths, new loops over unbounded data, changed data structures affecting memory, new synchronous network calls, removed caching.

**Dependency risk** — new packages added, major version bumps, packages with CVEs or poor maintenance, large transitive dependency additions.

## Integration Points

**git-craft/SKILL.md** — include a condensed version in the commit body:
```
Semantic impact: [one-line summary]
Breaking changes: [None / description]
```

**ship/SKILL.md** — include the full semantic diff in the PR body between "Key Changes" and "Testing" sections, under a `## Semantic Diff` heading.

**QA review / multi-review** — pass the semantic diff as context so the reviewer can focus on files with breaking changes, new security surface, and signature changes.

**build-log/SKILL.md** — in blog export format, replace the raw Files Changed list with the semantic diff output. The architectural narrative replaces line-count statistics.

## Commit Range Syntax

Accepts standard git ref syntax: `HEAD~1..HEAD` (default), `main..feature-branch`, `v1.2.0..v1.3.0`, or `<sha>..<sha>`.
