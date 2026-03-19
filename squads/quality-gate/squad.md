---
name: "quality-gate"
description: "Maximum quality team for production deployments and security-critical code. Five agents: architect designs, implementer builds, three specialist reviewers (security, performance, QA) run in parallel."
version: "1.0.0"
author: "Maestro"
agents:
  - role: architect
    agent: "maestro:maestro-implementer"
    model: opus
    focus: "Rigorous system design with explicit threat modeling. Produces architecture decisions, API contracts, data models, security boundaries, and a detailed implementation plan. Identifies attack surfaces, trust boundaries, and performance-sensitive code paths. The implementer executes against this plan exactly — no deviations without architect sign-off."
    tools: [Read, Grep, Glob, Write]
  - role: implementer
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Production-grade implementation against the architect's plan. Every input validated. Every auth check explicit. Every error handled and logged. No shortcuts. No TODO comments in shipped code. Follows the plan precisely and flags any deviation immediately."
    tools: [Read, Edit, Write, Bash, Grep, Glob]
  - role: security-reviewer
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "Adversarial security review. Assume the attacker has read the code. Check for OWASP top 10, injection vectors, auth bypass paths, privilege escalation, secrets exposure, insecure deserialization, SSRF, and mass assignment. Every finding is confidence-scored. No issues at confidence >= 70 may remain open. Report APPROVED or REJECTED."
    tools: [Read, Grep, Glob]
  - role: performance-reviewer
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "Performance and scalability review. Identify N+1 queries, missing indexes, synchronous blocking on hot paths, unbounded memory growth, missing pagination, cache invalidation gaps, and expensive operations in request handlers. Provide specific line-level findings with severity. Report APPROVED or REJECTED."
    tools: [Read, Grep, Glob]
  - role: qa-lead
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "Final acceptance review. Verify every acceptance criterion is met with a traceable implementation. Audit test coverage of critical paths. Check for correctness issues not caught by security or performance reviewers. Synthesize findings from all three parallel reviewers. A story is APPROVED only when all three reviewers have reported APPROVED. Report final STATUS: APPROVED or REJECTED with a consolidated finding list."
    tools: [Read, Grep, Glob]
orchestration_mode: dag
shared_context:
  - ".maestro/dna.md"
  - "CLAUDE.md"
quality_gates:
  - "Architect produces explicit threat model and API contracts before implementation begins"
  - "Every input from untrusted sources is validated with schema-based validation"
  - "Every auth check is explicit — no implicit trust"
  - "All error conditions are handled and logged — no silent failures"
  - "No hardcoded secrets, credentials, or environment-specific values in code"
  - "Security reviewer approves with no issues at confidence >= 70"
  - "Performance reviewer approves with no blocking findings on hot paths"
  - "QA lead synthesizes all reviewer output and reports final APPROVED"
---

# Squad: Quality Gate

## Purpose

Maximum confidence before shipping to production. This squad applies the full weight of Opus-class reasoning at every critical stage: architecture, security, performance, and final acceptance. It is slower and more expensive than other squads — that cost is intentional.

Use this squad when a mistake in production would be costly: payment flows, authentication systems, data migrations, public APIs, security-sensitive features, or any story where a defect has legal, financial, or reputational consequences.

Do not use this squad for routine feature work, prototypes, or internal tooling. The overhead is not justified for low-risk stories. Use `full-stack-dev` or `solo-dev` for those.

## Agents

### architect (opus)

The starting point for every story. No implementation begins until the architect has produced a complete plan.

Responsibilities:
- Define data models with field types, constraints, and relationships
- Specify API contracts in full: HTTP method, path, request schema, response schema, error cases, auth requirements
- Draw explicit trust boundaries: what data comes from untrusted sources, what requires authentication, what is privileged
- Produce a threat model: what can go wrong, what the attacker gains if it does, what mitigations are required
- Identify performance-sensitive paths: queries that could be slow at scale, synchronous operations in request handlers, unbounded data operations
- Write the implementation plan the implementer executes against — specific enough that there is no ambiguity about what to build

The architect does not write production code. It writes the blueprint that makes a production-grade implementation achievable in one pass.

### implementer (sonnet)

Executes the architect's plan with no shortcuts.

Responsibilities:
- Implement exactly what the architect specified — no scope creep, no unauthorized design decisions
- Validate every input from untrusted sources using schema-based validation (Zod or equivalent)
- Apply authentication and authorization checks before any business logic
- Handle every error condition explicitly: log it, return the correct status code, never swallow exceptions
- Write no TODO comments in shipped code — either implement it or flag it as a blocker
- Follow naming conventions and patterns from dna.md without deviation
- Flag any gap between the architect's plan and what is implementable — do not improvise

### security-reviewer (opus)

Adversarial review. Assumes a motivated attacker has read the code.

Responsibilities:
- OWASP Top 10 audit: injection (SQL, command, LDAP), broken auth, XSS, insecure direct object references, security misconfiguration, sensitive data exposure, XML/deserialization issues, known vulnerable components, insufficient logging
- Auth bypass analysis: can any path reach privileged operations without proper auth?
- Privilege escalation: can a low-privilege user trigger actions intended for admins?
- Secrets exposure: are credentials, tokens, or keys present in code, logs, or error messages?
- SSRF and request forgery: are user-controlled URLs fetched without validation?
- Mass assignment: are model fields bound from user input without an allowlist?
- Confidence-score every finding (0-100). Issues at confidence >= 70 are blocking.
- Report APPROVED or REJECTED with a finding list sorted by confidence descending.

### performance-reviewer (opus)

Ensures the implementation will not degrade under real load.

Responsibilities:
- N+1 query detection: loops that issue database queries without batching
- Missing indexes: queries on unindexed columns for tables that will grow large
- Unbounded operations: queries without LIMIT, loops over unbounded collections, memory-accumulating patterns
- Synchronous blocking on hot paths: file I/O, external API calls, or CPU-intensive work in request handlers without async handling
- Pagination gaps: list endpoints that return all records without pagination
- Cache invalidation: are cached values invalidated correctly when the underlying data changes?
- Provide specific line-level findings with severity (blocking/warning). Report APPROVED or REJECTED.

### qa-lead (opus)

The final gate. Synthesizes all reviewer output and makes the definitive call.

Responsibilities:
- Verify every acceptance criterion maps to a traceable implementation
- Confirm test coverage exists for critical paths (not 100%, but the paths that matter: happy path, auth rejection, validation failure, error handling)
- Review the security-reviewer and performance-reviewer findings — if either reported REJECTED, the story is REJECTED
- Identify any correctness issues not caught by the specialist reviewers
- Produce a consolidated finding list: security findings, performance findings, correctness issues, and criteria gaps
- Report final STATUS: APPROVED only when: all three parallel reviewers approved, all criteria are met, and no blocking correctness issues remain

## Workflow

```
architect
    |
implementer
    |
    +-- security-reviewer  (parallel)
    |
    +-- performance-reviewer  (parallel)
    |
    +-- qa-lead  (parallel, waits for both reviewers above)
              |
           (final verdict)
```

1. **architect** receives the story and produces: threat model, API contracts, data models, trust boundaries, and a detailed implementation plan.

2. **implementer** receives the architect's full output and produces the implementation. No deviations from the plan without an explicit note.

3. **security-reviewer**, **performance-reviewer**, and **qa-lead** all receive the full diff and the architect's plan. Security and performance reviewers run in parallel. QA lead runs after both specialist reviewers complete, incorporating their findings.

4. **qa-lead** reports the final verdict. The story is done only when qa-lead reports STATUS: APPROVED.

## Context Sharing

Every agent in this squad receives:
- `.maestro/dna.md` — Project DNA: tech stack, conventions, security standards
- `CLAUDE.md` — Project-level rules all agents must follow

In addition:
- **implementer** receives the architect's full plan as injected context
- **security-reviewer** and **performance-reviewer** receive the full diff and architect's threat model
- **qa-lead** receives the full diff, architect's plan, and both specialist reviewer reports

## Quality Gates

1. **Threat model gate** — Architect must produce an explicit threat model before implementation proceeds. No implementation without identified trust boundaries and mitigations.
2. **Input validation** — Every field from untrusted input must have schema-based validation. Missing validation = automatic security rejection.
3. **Auth explicitness** — Every privileged operation must have an explicit, traceable auth check. Implicit trust (e.g., assuming a session is valid without checking) = automatic rejection.
4. **No silent failures** — Every error path must log and return an appropriate response. Swallowed exceptions or empty catch blocks = rejection.
5. **Security gate** — Security reviewer must report APPROVED with no findings at confidence >= 70.
6. **Performance gate** — Performance reviewer must report APPROVED with no blocking findings on request-path code.
7. **Final QA gate** — QA lead must report STATUS: APPROVED after synthesizing all reviewer output.

## When to Use

- Payment processing, billing logic, or financial data handling
- Authentication and session management systems
- Any endpoint that handles PII or sensitive user data
- Public-facing APIs that will be consumed by third parties
- Database migrations on tables with production data
- Security policy enforcement (rate limiting, RBAC, audit logging)
- Code that runs with elevated privileges or service-role access
- Any story where a defect in production has legal, financial, or reputational consequences
