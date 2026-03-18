---
name: multi-review
description: "Three-perspective parallel code review. Dispatches correctness, security, and performance reviewers simultaneously. Combines into unified report."
---

# Multi-Agent Code Review

Dispatch 3 parallel reviewers, each with a different focus. Combines findings into a unified, deduplicated report.

## When to Use

- Trust level is Novice or Apprentice (needs more oversight)
- `--careful` mode is active
- Story is tagged as security-critical or performance-critical

## Reviewers

### 1. Correctness Reviewer

Focus: Does the code do what the story requires?

```
Review this code change for CORRECTNESS:
- Does it implement all acceptance criteria?
- Are there logic bugs or edge cases?
- Are error paths handled?
- Does it match the story specification?
Report only issues with confidence >= 80.
```

### 2. Security Reviewer

Focus: OWASP top 10 and common security issues.

```
Review this code change for SECURITY:
- SQL injection (parameterized queries?)
- XSS (input sanitization? output encoding?)
- Authentication/authorization checks
- Sensitive data exposure (logs, errors, responses)
- CSRF protection
- Input validation at boundaries
Report only issues with confidence >= 80.
```

### 3. Performance Reviewer

Focus: Runtime efficiency and resource usage.

```
Review this code change for PERFORMANCE:
- N+1 query patterns
- Unnecessary re-renders (React)
- Missing database indexes
- Memory leaks (unclosed connections, listeners)
- Unbounded loops or recursion
- Missing pagination or limits
Report only issues with confidence >= 80.
```

## Dispatch

Launch all 3 as background agents in parallel.

**Agent type selection:**
- If the `feature-dev` plugin is installed, use `feature-dev:code-reviewer` for higher-quality reviews.
- If `feature-dev` is not installed, use `maestro:maestro-qa-reviewer` with the focus-specific prompt appended to the standard QA prompt.

```
# Preferred (if feature-dev plugin installed):
Agent(subagent_type="feature-dev:code-reviewer", ...)

# Fallback (always available):
Agent(subagent_type="maestro:maestro-qa-reviewer", ...)
```

**Note:** The `feature-dev` plugin (`feature-dev:code-reviewer`) is an optional dependency. Install it for best multi-review results: `claude plugin marketplace add feature-dev`. Maestro works without it.

Each receives:
- The git diff for the story's changes
- Story acceptance criteria
- Their specific focus prompt (above)
- Project DNA conventions

## Combine

After all 3 complete:

1. Collect all findings
2. Deduplicate (same issue found by multiple reviewers = higher confidence)
3. Categorize: critical / important / minor
4. Sort by confidence (highest first)
5. Present unified report

## Report Format

```
+---------------------------------------------+
| Code Review: Story 03 — API Routes         |
+---------------------------------------------+

  Reviewers: correctness, security, performance
  Findings: 2 important, 1 minor

  IMPORTANT:
    (!) [Security] No rate limiting on POST /api/users
        File: src/routes/users.ts:42
        Confidence: 95%
        Fix: Add rate limiter middleware

    (!) [Correctness] Missing validation for email format
        File: src/routes/users.ts:28
        Confidence: 88%
        Fix: Add Zod schema validation

  MINOR:
    (i) [Performance] Consider adding index on users.email
        File: prisma/schema.prisma
        Confidence: 82%

  Verdict: REJECTED (2 important issues)
```

## Integration

Called by dev-loop Phase 5 (QA REVIEW) when multi-review mode is selected.
