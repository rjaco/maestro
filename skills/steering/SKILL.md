---
name: steering
description: "Persistent steering files that provide high-level product, structure, tech, and standards context to all agents across all sessions. T1 context — always included in every agent package."
---

# Steering Files

Maintains four persistent files in `.maestro/steering/` that survive across sessions. Steering files give every agent an authoritative, token-efficient view of the project: what it is, how it is organized, what technology it uses, and what quality bar it holds. Agents no longer need this context re-explained per session.

## The Four Steering Files

### product.md — What We're Building

```markdown
# Product

## Vision
[One paragraph: what problem this solves and for whom]

## Target Audience
- Primary: [persona — role, pain, need]
- Secondary: [persona — role, pain, need]

## Key Features
- [Feature] — [differentiator or why it matters]
- [Feature] — [differentiator or why it matters]

## Success Metrics
- [Metric]: [target value or direction]
- [Metric]: [target value or direction]

## Non-Goals
- [Explicitly out of scope — prevents scope creep]
- [Explicitly out of scope]
```

**What to fill in:** Vision comes from the user interview during `maestro init`. Personas and success metrics must be provided by the user — they cannot be inferred from code. Non-goals are especially valuable: capture anything the team has consciously decided not to build.

### structure.md — How the Code Is Organized

```markdown
# Structure

## Directory Layout
[Auto-populated from project-dna scan — top 3 levels with layer labels]

## Module Boundaries
- [Module/package] — [responsibility, what it owns, what it must not do]
- [Module/package] — [responsibility]

## Key Abstractions
- `[ClassName / function / type]` at `[path]` — [what it does, when to use it]
- `[ClassName / function / type]` at `[path]` — [what it does, when to use it]

## Data Flow
[Narrative: how data moves from source to UI or between services]

---
<!-- AUTO-GENERATED — do not edit below this line -->
[Regenerated section from project-dna on each refresh]
```

**Auto-populated section:** The directory layout and key abstraction list are populated from `project-dna` output. Everything above the divider is user-owned and will never be overwritten.

### tech.md — Technical Decisions and Constraints

```markdown
# Tech

## Stack
| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Framework | [name] | [version] | [why this was chosen] |
| Database | [name] | [version] | [why] |
| Hosting | [name] | — | [why] |
| Styling | [name] | [version] | [why] |
| Auth | [name] | [version] | [why] |

## Key Dependencies
- `[package]` [version] — [purpose, gotchas if any]
- `[package]` [version] — [purpose, gotchas if any]

## Performance Constraints
- [Constraint, e.g. "API responses under 200ms p95"]
- [Constraint, e.g. "Bundle size must stay under 150KB gzipped"]

## Security Requirements
- [Requirement, e.g. "All user input validated server-side with Zod"]
- [Requirement, e.g. "No secrets in client bundles"]

## API Conventions
- Style: [REST / GraphQL / tRPC / other]
- Auth: [e.g. API key via resolveApiKey(), JWT Bearer, session cookie]
- Versioning: [e.g. /api/v1/ prefix, header-based, none]
- Error format: [e.g. { error: string, code: string }]
```

**Auto-populated:** Stack table and key dependencies are seeded from `package.json` and `dna.md`. Rationale, performance constraints, security requirements, and API conventions require user input.

**Updated by:** `architecture` skill adds or updates rows in the Stack table when new tech decisions are made. Each update appends a `[CHANGED yyyy-mm-dd]` annotation so drift is visible.

### standards.md — Quality and Process Standards

```markdown
# Standards

## Code Style
- [Rule beyond linter, e.g. "Named exports only — no default exports except pages"]
- [Rule, e.g. "Zod schemas defined in types/ not inline in route handlers"]

## Testing Requirements
- Coverage target: [e.g. 80% line coverage, or "no coverage target — test critical paths"]
- Required test types: [e.g. unit + integration, no E2E in CI]
- Test location: [e.g. co-located *.test.ts, or tests/ directory]
- Mocking policy: [e.g. "never mock the database — use test containers"]

## Review Process
- [e.g. "All PRs require one approval before merge"]
- [e.g. "Self-merge allowed for chore/ and docs/ branches"]

## Deployment Constraints
- [e.g. "No deploys on Friday after 3pm"]
- [e.g. "Staging must pass smoke tests before production promotion"]

## Documentation Expectations
- [e.g. "All public functions need JSDoc with @param and @returns"]
- [e.g. "ADRs required for any new infrastructure dependency"]
```

**What to fill in:** Linting rules are auto-populated from `.eslintrc` / `eslint.config.*`. Everything else requires user input: coverage targets, review policy, and deployment constraints are team decisions, not inferable from code.

## Generation Workflow

### During `maestro init`

After generating `.maestro/dna.md` (Step 4b of init), generate the four steering files:

1. **Auto-populate** what can be inferred:
   - `structure.md`: directory layout from DNA scan, key abstractions from detected patterns
   - `tech.md`: stack table and dependencies from `package.json` / detected files
   - `standards.md`: linting rules from `.eslintrc` or `eslint.config.*`

2. **Mark gaps clearly.** Replace every un-inferable field with a placeholder:
   ```
   [TODO: fill in — cannot be inferred from code]
   ```

3. **Show the user what needs their input.** After creating the files, display:
   ```
   Steering files created. A few things need your input:

     product.md      Vision, personas, success metrics, non-goals
     tech.md         Performance constraints, security requirements
     standards.md    Coverage target, review process, deployment rules

   Edit these files directly at any time. Maestro will never overwrite your edits.
   ```

4. **Never prompt interactively** for steering content during init — the files are the prompt. The user fills them in at their own pace.

### Never Overwrite User-Edited Content

Before writing to any steering file, check for the presence of user content (non-placeholder, non-auto-generated text). If user content exists:
- Do NOT overwrite the file
- Only update the auto-generated section (below the `<!-- AUTO-GENERATED -->` divider in `structure.md`)
- Log the skip to `.maestro/context-log.md`: `[timestamp] Steering: skipped overwrite of structure.md — user content detected`

## Context Engine Integration

Steering files are **T1 context** — always included in every agent package regardless of tier:

| Agent Role | Receives Steering Files |
|------------|------------------------|
| orchestrator (T0) | All four files, full text |
| strategist (T1) | All four files, full text |
| architect (T2) | tech.md + structure.md (full), product.md + standards.md (summary) |
| implementer (T3) | All four files, trimmed to fit 2000-token budget |
| qa-reviewer (T3) | standards.md (full) + product.md summary |
| self-heal (T4) | tech.md constraints section only |

**Token budget:** Combined size of all four steering files must stay under 2000 tokens. When composing for T3/T4, the Context Engine trims each file to its most relevant sections before including.

**Inclusion rule in the context-engine composition pipeline:** Steering files are inserted at the top of Step 4 (Compose Package), before constraints and patterns, with priority score 1.0 — they are never excluded by the relevance filter.

## Maintenance Rules

### After Architecture Changes

When the `architecture` skill writes a new or updated `.maestro/architecture.md`:
1. Compare the new tech stack decisions against `tech.md`
2. If new decisions exist, append them to the Stack table with `[NEW yyyy-mm-dd]` annotation
3. Flag `tech.md` for user review: add a comment at the top: `<!-- NEEDS REVIEW: updated by architecture skill on yyyy-mm-dd -->`
4. Do NOT silently overwrite existing rows — append only

### After Retrospectives

When the `retrospective` skill proposes an improvement that affects project standards or architecture:
1. If approved by the user, update the relevant steering file
2. Note the change with an inline comment: `<!-- Updated by retrospective yyyy-mm-dd: [brief reason] -->`
3. Log the update to `.maestro/context-log.md`

### Direct User Edits

Users may edit steering files at any time. Maestro treats these files as authoritative:
- User edits always take precedence over auto-generated content
- The `<!-- AUTO-GENERATED -->` divider in `structure.md` protects user sections from refresh overwrites
- No skill may overwrite a steering file without first checking for user content

## Integration Points

| Integrates With | How |
|----------------|-----|
| `project-dna/SKILL.md` | DNA output seeds structure.md auto-generated section and tech.md stack table |
| `context-engine/SKILL.md` | Steering files are T1 context, included in every agent package |
| `init/` command | Step 4b triggers steering file generation immediately after dna.md |
| `architecture/SKILL.md` | After Step 7 (write architecture doc), architecture updates tech.md with new decisions |
| `retrospective/SKILL.md` | Approved improvements can update standards.md with new quality rules |

## File Locations

```
.maestro/
  steering/
    product.md      — What we're building (user-owned)
    structure.md    — Code organization (auto + user hybrid)
    tech.md         — Technical decisions (auto-seeded, user-maintained)
    standards.md    — Quality standards (auto-seeded from linter, user-maintained)
```
