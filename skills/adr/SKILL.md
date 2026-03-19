---
name: adr
description: "Auto-generate Architecture Decision Records at milestone boundaries by analyzing the combined diff for significant architectural changes. Cumulative, append-only, lightweight."
---

# ADR Auto-Generation

Analyzes the combined diff at each milestone boundary and generates Architecture Decision Records for significant architectural changes. Inspired by Ruflo's background ADR worker.

## When to Run

- **Automatically** — after each milestone completes in opus mode, before the post-milestone checkpoint
- **On request** — `/maestro adr <commit-range>` to analyze any diff range
- **Never** — at the story level; ADRs are milestone-scoped, not story-scoped

## What Counts as Significant

Only generate an ADR when one of these is detected in the diff. Minor code changes do not qualify.

| Signal | What to look for in the diff |
|--------|------------------------------|
| New dependency | New entry in `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `requirements.txt`, or equivalent |
| New database table | `CREATE TABLE`, new migration file, new model/schema file with a table definition |
| New API endpoint namespace | New router file, new route prefix (`/api/v2/`, `/webhooks/`, `/admin/`), new Express/FastAPI/Rails router mount |
| New hook registration | New lifecycle hook, event listener, or pub/sub subscription wired at the application level |
| New environment variable | New `process.env.*`, `os.getenv`, `ENV[...]`, or `.env.example` entry |
| Framework change | Dependency swap at a framework level (e.g., Express → Fastify, React → Svelte) |
| Infrastructure change | New Dockerfile, Terraform resource, cloud provider configuration, CI pipeline change |
| New integration point | New call to a third-party API, SDK, or external service not previously used |

If none of these signals appear in the milestone diff, skip ADR generation entirely.

## ADR Location and Numbering

All ADRs live in `.maestro/adrs/`. Numbering is sequential and zero-padded to four digits.

```
.maestro/adrs/
  0001-add-prisma-orm.md
  0002-new-webhook-namespace.md
  0003-postgres-sessions-table.md
```

**Numbering protocol:**

1. List existing files in `.maestro/adrs/` sorted lexicographically.
2. The next number is `max(existing) + 1`, or `0001` if none exist.
3. Never reuse a number. Never overwrite an existing ADR.

The title slug is kebab-case, derived from the decision title (max 5 words).

## ADR Format

```markdown
# NNNN — [Title]

**Status:** Accepted
**Date:** YYYY-MM-DD
**Milestone:** [milestone name or number]
**Diff range:** [base-commit..head-commit]

## Context

[What situation or constraint led to this decision? What problem was being solved?
One short paragraph, 2–4 sentences. Focus on the *why* — what forced this choice.]

## Decision

[What was decided? State it plainly in one sentence, then explain any alternatives
that were considered and rejected. Be specific: name the package, table, endpoint,
or variable.]

## Consequences

**Positive:**
- [Benefit 1]
- [Benefit 2]

**Negative / Trade-offs:**
- [Cost or risk 1]
- [Cost or risk 2]

**Follow-up actions required:**
- [Any migration, update, or documentation task this decision creates — or "None"]
```

## Analysis Protocol

Follow these steps in order after a milestone completes.

**Step 1: Get the diff range.**
Identify the base commit (start of milestone) and head commit (current HEAD). Use the checkpoint tag if available:
```bash
git log --oneline maestro/cp/{session}/{pre-milestone-name}..HEAD
```
If no checkpoint tag, use the commit hash recorded in `.maestro/state.local.md` at milestone start.

**Step 2: Scan for signals.**
Run targeted diffs to detect each signal type:

```bash
# New dependencies
git diff {base}..{head} -- package.json Cargo.toml go.mod pyproject.toml requirements.txt

# New migration or schema files
git diff {base}..{head} --name-only | grep -E "(migration|schema|migrate)"

# New route/API files
git diff {base}..{head} --name-only | grep -E "(route|router|endpoint|controller)"

# New env vars
git diff {base}..{head} | grep -E "^\+.*process\.env\.|^\+.*os\.getenv|^\+.*ENV\["

# Infrastructure changes
git diff {base}..{head} --name-only | grep -E "(Dockerfile|\.tf$|\.yml$|\.yaml$)"
```

**Step 3: Cluster signals into decisions.**
Group related signals into a single ADR when they belong to the same decision. Example: adding `passport`, `passport-google-oauth20`, and a new `oauth_accounts` migration are one decision ("add OAuth authentication"), not three.

**Step 4: Write one ADR per decision.**
Apply the format above. Fill each section concisely — the ADR is a record, not an essay. Context and Decision sections should be 1–3 sentences each.

**Step 5: Verify no overwrite.**
Before writing, confirm the target file path does not already exist. If numbering produces a collision (race condition in parallel milestones), increment by one and retry.

## Integration Points

**checkpoint/SKILL.md** — ADR generation runs after git-craft and before the post-milestone checkpoint is saved. The ADR files are committed as part of the milestone commit if any were generated.

**git-craft/SKILL.md** — when ADRs are generated, include them in the milestone commit. Commit message note:
```
ADRs: .maestro/adrs/NNNN-title.md (and any others)
```

**semantic-diff/SKILL.md** — the semantic diff is the primary input to the ADR analysis. Run semantic-diff first, then use its "Change Categories Detected" table to identify which signals qualify.

**retrospective/SKILL.md** — at retrospective time, list all ADRs generated during the milestone as part of the architectural summary section.

## Lightweight Guarantee

The ADR skill must not generate noise. If in doubt about whether a change is significant enough, do not generate an ADR. The bar is: "Would a new engineer need to know this decision existed to understand the codebase architecture?" If yes, write it. If no, skip it.

Maximum ADRs per milestone: 5. If more than 5 signals are detected, cluster aggressively. If clustering cannot reduce below 5, surface the top 5 by architectural impact and log a note that minor decisions were omitted.

## Decision Tree: Is This ADR-Worthy?

Use this tree before writing any ADR. Start at the top and follow the first matching branch.

```
Is the change in the diff purely within existing files (no new files, no dependency changes)?
  YES → Does it change how a core system boundary works (auth, data flow, external contract)?
          YES → ADR warranted (architectural refactor)
          NO  → Skip. Not ADR-worthy.
  NO  →
    Is a new dependency being added?
      YES → Is it replacing an existing dependency, or is it the first of its kind?
              Replacing → ADR warranted (framework/library swap)
              First of kind → ADR warranted (new external dependency)
              Patch/minor version bump → Skip.
    Is a new file in migrations/, schema/, or equivalent?
      YES → Does it create a new table or materially change a table's structure?
              YES → ADR warranted (new DB schema decision)
              NO (additive column, index) → Skip.
    Is a new route prefix or API namespace added (/api/v2/, /admin/, /webhooks/)?
      YES → ADR warranted (new API surface)
    Is a new environment variable introduced?
      YES → Does it gate a new integration or runtime behavior?
              YES → ADR warranted (new config contract)
              NO (logging verbosity, feature flag) → Skip.
    Is there a new Dockerfile, Terraform resource, or CI pipeline file?
      YES → ADR warranted (infrastructure decision)
    None of the above matched → Skip. Not ADR-worthy.
```

**Rule of thumb:** If you can describe the change in a single verb ("added a column", "renamed a variable", "fixed a typo"), it is not ADR-worthy. If you need a sentence that includes *why* and *instead of what*, it is.

## Clustering: Grouping Related Signals Into One ADR

When multiple signals belong to the same root decision, write one ADR — not one per signal.

**Example: Adding OAuth authentication in one milestone**

Signals detected:
- New dependency: `passport` in `package.json`
- New dependency: `passport-google-oauth20` in `package.json`
- New migration: `create_oauth_accounts_table`
- New env var: `GOOGLE_CLIENT_ID`
- New env var: `GOOGLE_CLIENT_SECRET`
- New route file: `routes/auth/google.ts`

This is **one decision** — "Adopt Google OAuth via Passport.js" — not six. The ADR title is `0004-google-oauth-passport.md`. All six signals are mentioned in the Context section.

**Clustering rule:** If signals share the same capability noun (auth, payments, notifications, search), cluster them. If they serve unrelated capabilities, write separate ADRs.

**Counter-example — do not cluster these:**
- New dependency: `stripe` (payments)
- New migration: `create_sessions_table` (session management)

These serve different capabilities. Write two ADRs even though they appeared in the same milestone.

## Prioritization When > 5 Signals Detected

When clustering cannot reduce the candidate ADR count below 5, apply this ranking to select which 5 to write. Rank from highest to lowest architectural impact:

| Rank | Category | Reason |
|------|----------|--------|
| 1 | Framework or runtime change | Affects every file; hardest to reverse |
| 2 | New external service integration | Introduces a new failure domain and cost center |
| 3 | New database table or schema | Defines a permanent data contract |
| 4 | New API namespace or surface | Creates a versioning commitment |
| 5 | New environment variable with behavioral effect | Changes runtime contract |
| 6+ | Additional dependencies, minor infra changes | Lower impact; omit if over limit |

When omitting, append this note to the last ADR in the set:

```
**Note:** Additional minor decisions were detected in this milestone diff but omitted
to stay within the 5-ADR limit. See the semantic-diff summary for full signal list.
```

## Concrete Example ADRs

### ADR-0001: Adopt Supabase over raw PostgreSQL

```markdown
# 0001 — Adopt Supabase over Raw PostgreSQL

**Status:** Accepted
**Date:** 2026-01-15
**Milestone:** 1 — Data Layer Setup
**Diff range:** abc1234..def5678

## Context

The project requires a managed Postgres database with built-in auth, row-level security,
and a real-time subscription layer. Operating raw PostgreSQL would require separate
setup for connection pooling, auth tables, and a websocket layer — significant
undifferentiated infrastructure work.

## Decision

Adopt Supabase as the database platform instead of self-managed PostgreSQL. The
`@supabase/supabase-js` client replaces direct `pg` queries. Considered PlanetScale
(MySQL, no RLS) and Neon (Postgres-only, no auth layer) — both rejected for missing
the auth + RLS requirement.

## Consequences

**Positive:**
- Auth, RLS, and real-time subscriptions available with no additional services.
- Supabase migrations toolchain integrates with existing CI.

**Negative / Trade-offs:**
- Vendor lock-in on auth layer; migrating away requires rewriting auth tables and RLS policies.
- Local development requires `supabase start` (Docker); adds ~2 min to cold-start.

**Follow-up actions required:**
- Add `supabase start` to the dev onboarding script.
- Document RLS policy conventions in `docs/database.md`.
```

### ADR-0002: Use App Router over Pages Router

```markdown
# 0002 — Use Next.js App Router over Pages Router

**Status:** Accepted
**Date:** 2026-01-22
**Milestone:** 2 — Frontend Scaffolding
**Diff range:** def5678..9ab0123

## Context

Next.js 14 ships two routing paradigms. The Pages Router is stable and widely
documented. The App Router is the recommended path forward with React Server
Components, nested layouts, and streaming built in. The project's dashboard views
require nested persistent layouts that are cumbersome to implement in Pages Router.

## Decision

Use the App Router (`app/` directory) exclusively. No `pages/` directory will be
created. Considered starting with Pages Router for stability and migrating later —
rejected because incremental migration is high-friction and the project has no
legacy Pages Router code to preserve.

## Consequences

**Positive:**
- React Server Components reduce client bundle size for data-heavy dashboard views.
- Nested layouts eliminate repeated header/sidebar rendering.

**Negative / Trade-offs:**
- App Router ecosystem is less mature; some third-party libraries require client
  component wrappers.
- Team familiarity is lower — Pages Router muscle memory causes early confusion.

**Follow-up actions required:**
- Add an `app/` vs `pages/` note to CONTRIBUTING.md.
- Pin Next.js to 14.x until App Router APIs stabilize.
```

## Integration with semantic-diff

The semantic-diff skill categorizes changes before ADR runs. Use its "Change Categories Detected" table as the primary signal source — this avoids re-scanning the diff manually.

**Mapping from semantic-diff categories to ADR triggers:**

| semantic-diff category | Maps to ADR signal | ADR warranted? |
|------------------------|--------------------|----------------|
| `dependency-added` | New dependency | Yes — always evaluate |
| `dependency-changed` (major version) | Framework change | Yes if major; skip minor/patch |
| `schema-migration` | New database table | Yes if new table; evaluate column adds |
| `api-surface-added` | New API endpoint namespace | Yes |
| `env-var-added` | New environment variable | Yes if behavioral |
| `infra-file-added` | Infrastructure change | Yes |
| `integration-call-added` | New integration point | Yes |
| `refactor` | Internal restructure | No — only if it changes a system boundary |
| `test-added` | Test file added | No |
| `docs-changed` | Documentation update | No |
| `style-change` | Formatting/linting | No |

**Workflow:**

```
1. semantic-diff runs → produces Change Categories table
2. adr skill reads that table
3. For each row with a "Yes" in the ADR column, evaluate further with the decision tree above
4. Cluster related signals
5. Write ADRs for surviving candidates
```

If semantic-diff was not run before ADR (e.g., manual invocation), fall back to Step 2 of the Analysis Protocol (bash scan).
