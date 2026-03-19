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
