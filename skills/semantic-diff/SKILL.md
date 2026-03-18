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

## Diff Analysis Protocol

Follow this protocol in order. Do not skip steps.

**Step 1: Gather changed files** — run `git diff --stat <base>..<head>`. Use change magnitude (+lines/-lines) to prioritize reading order; large diffs in core files warrant deeper analysis. Note files with both high addition and deletion counts — these are likely refactors, not just additions.

**Step 2: Read the diffs** — run `git diff <base>..<head> -- <file>` per file. For files with >200 changed lines, focus on exported symbols, function signatures, and type definitions rather than implementation bodies.

**Step 3: Three-level analysis** — analyze each file at all three levels before writing output:

- **Line level**: added/removed imports, changed signatures, modified constants, deleted code paths, renamed variables
- **Function level**: new functions or methods, modified signatures vs. body-only changes, removed functions, restructured classes, changed return types
- **Architecture level**: new external dependencies, API endpoints added/removed/changed, database schema changes, new auth requirements, changed data flow, new background jobs, changed inter-service contracts

**Step 4: Categorize each change** — assign each meaningful change to exactly one category from the table below. A single file may contribute changes to multiple categories.

**Step 5: Score risk** — apply the risk level for each category. When one file contributes to multiple categories, use the highest risk level for that file's row in the output table.

**Step 6: Synthesize** — collapse the analysis into the output format. Prioritize architectural observations. Line-level details belong only in the Files Changed table.

## Change Categories

Every detected change must be classified before producing output.

| Category | Definition | Examples |
|----------|------------|---------|
| **New Feature** | Adds a capability that did not exist before | new endpoint, new UI component, new background job |
| **Bug Fix** | Corrects incorrect behavior without changing the API contract | off-by-one corrected, null guard added, race condition resolved |
| **Refactor** | Changes internal structure without altering observable behavior | extracted function, renamed variable, changed data structure with adapter |
| **Breaking Change** | Alters or removes a public contract that callers depend on | removed export, changed function signature, renamed or dropped API field |
| **Dependency Update** | Adds, removes, or upgrades a third-party package | new npm package, major version bump, package removed |
| **Performance** | Changes that primarily affect throughput, latency, or memory | added index, removed N+1 query, added cache, switched algorithm |
| **Security** | Changes to auth, permissions, encryption, or input validation | new auth middleware, changed token storage, added rate limiting |
| **Configuration** | Changes to environment variables, flags, or deployment config | new env var required, changed default value, added feature flag |
| **Test / Docs** | Test-only or documentation-only changes | new test file, updated README, added JSDoc |

## Risk Scoring

Assign one risk level per change category present in the diff. Include all risk levels in the output.

| Category | Risk Level | Rationale |
|----------|-----------|-----------|
| Breaking Change | HIGH | Callers will break silently or explicitly |
| Security | HIGH | Vulnerabilities compound; audit required |
| Dependency Update (major) | HIGH | Upstream breaking changes, possible CVEs |
| New Feature | MEDIUM | New surface area, new failure modes |
| Performance | MEDIUM | Can degrade unpredictably under load |
| Dependency Update (minor/patch) | LOW | Typically safe; verify changelog |
| Refactor | LOW | Behavior unchanged if tests pass |
| Configuration | LOW–HIGH | Depends on whether change is required in prod |
| Bug Fix | LOW | Targeted correction; verify regression test exists |
| Test / Docs | NONE | No runtime impact |

When multiple HIGH-risk categories appear in the same diff, flag the output with a **REVIEW REQUIRED** banner.

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

### Change Categories Detected
| Category | Scope | Risk |
|----------|-------|------|
| New Feature | OAuth login flow | MEDIUM |
| Security | New token storage path | HIGH |
| Dependency Update (major) | passport 0.6 → 0.7 | HIGH |
| Test / Docs | OAuth test suite | NONE |

> REVIEW REQUIRED: 2 HIGH-risk categories detected.

### Risk Assessment
- **Breaking changes**: None (additive only)
- **Security surface**: New OAuth token storage (encrypted at rest); verify token expiry handling
- **Performance**: No impact (new endpoints, existing ones unchanged)
- **Dependency risk**: `passport` major bump — review upstream changelog for removed APIs

### Files Changed (5)
| File | Change Type | Category | Risk |
|------|------------|----------|------|
| src/auth/oauth.ts | NEW | New Feature | MEDIUM |
| src/auth/types.ts | MODIFIED | New Feature | LOW |
| src/routes/auth.ts | MODIFIED | New Feature + Security | HIGH |
| migrations/003_oauth.sql | NEW | New Feature | MEDIUM |
| tests/auth/oauth.test.ts | NEW | Test / Docs | NONE |
```

## Risk Assessment Categories

All four dimensions must appear in every output. If a category has no risk, write "None."

**Breaking changes** — removed or renamed exports, changed function signatures (parameters without defaults), removed API endpoints, database column removed or retyped.

**Security surface** — new auth or authorization logic, new endpoints accepting user input, new calls to external services, new token or credential storage, changed permission checks.

**Performance impact** — new database queries in hot paths, new loops over unbounded data, changed data structures affecting memory, new synchronous network calls, removed caching.

**Dependency risk** — new packages added, major version bumps, packages with CVEs or poor maintenance, large transitive dependency additions.

## QA Integration

The semantic diff is the primary input the QA reviewer uses to focus its attention. The handoff works as follows:

1. Implementer finishes; semantic diff is generated automatically.
2. The semantic diff is passed to the QA reviewer as context before it reads any code.
3. The QA reviewer uses the risk levels to determine review depth:
   - **HIGH risk files** — full read, look for edge cases, missing error handling, security gaps
   - **MEDIUM risk files** — check function signatures, happy-path tests present, integration points valid
   - **LOW / NONE risk files** — spot-check only; assume correct unless tests fail

This ensures QA effort scales with actual risk rather than line count. A 500-line refactor with LOW risk gets less scrutiny than a 20-line auth patch with HIGH risk.

When the semantic diff contains a **REVIEW REQUIRED** banner, the QA reviewer must explicitly sign off on each HIGH-risk item before the story can move to DONE.

### QA Reviewer Receives

The following block is prepended to QA reviewer context when a semantic diff is available:

```
SEMANTIC DIFF SUMMARY
Change categories: [list]
Highest risk: [HIGH / MEDIUM / LOW]
Files requiring close review: [list of HIGH/MEDIUM files]
Breaking changes: [Yes / No — description if yes]
REVIEW REQUIRED: [Yes / No]
```

## Real-World Example

Below is a semantic diff for a hypothetical change that replaces direct database calls with a repository pattern.

**Input:** 14 files modified, 380 insertions, 290 deletions, across `src/services/`, `src/db/`, and `tests/`.

```markdown
## Semantic Diff: Story 07 — Repository Pattern Extraction

### What Changed
- **Refactor**: Direct `db.query()` calls in service layer replaced with `UserRepository`, `OrderRepository`, `ProductRepository`
- **New interfaces**: `IUserRepository`, `IOrderRepository` added to `src/db/types.ts`
- **Test change**: Service unit tests now mock repository interfaces instead of the database driver

### Architectural Impact
- **Testability**: Service layer is now database-agnostic; tests no longer need a live DB
- **Coupling**: Services depend on interfaces, not concrete implementations
- **Data layer boundary**: Repository is now the single point of DB access — no service bypasses it

### Change Categories Detected
| Category | Scope | Risk |
|----------|-------|------|
| Refactor | Service + DB layers | LOW |
| Test / Docs | Updated unit tests | NONE |

### Risk Assessment
- **Breaking changes**: None — service APIs unchanged, only internal call sites refactored
- **Security surface**: No change
- **Performance**: No change — queries are identical, just moved
- **Dependency risk**: No new packages

### Files Changed (14)
| File | Change Type | Category | Risk |
|------|------------|----------|------|
| src/services/UserService.ts | MODIFIED | Refactor | LOW |
| src/services/OrderService.ts | MODIFIED | Refactor | LOW |
| src/db/UserRepository.ts | NEW | Refactor | LOW |
| src/db/OrderRepository.ts | NEW | Refactor | LOW |
| src/db/types.ts | MODIFIED | Refactor | LOW |
| tests/services/*.test.ts (9 files) | MODIFIED | Test / Docs | NONE |
```

**QA guidance generated from this diff:** Spot-check the service tests to confirm mock contracts match real repository interfaces. No HIGH-risk items; standard review sufficient.

## Integration Points

**git-craft/SKILL.md** — include a condensed version in the commit body:
```
Semantic impact: [one-line summary]
Breaking changes: [None / description]
```

**ship/SKILL.md** — include the full semantic diff in the PR body between "Key Changes" and "Testing" sections, under a `## Semantic Diff` heading.

**QA review / multi-review** — pass the semantic diff as context so the reviewer can focus on files with breaking changes, new security surface, and signature changes. See QA Integration section above for the exact handoff block format.

**build-log/SKILL.md** — in blog export format, replace the raw Files Changed list with the semantic diff output. The architectural narrative replaces line-count statistics.

## Commit Range Syntax

Accepts standard git ref syntax: `HEAD~1..HEAD` (default), `main..feature-branch`, `v1.2.0..v1.3.0`, or `<sha>..<sha>`.
