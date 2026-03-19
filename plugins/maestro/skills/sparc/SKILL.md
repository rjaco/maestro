---
name: sparc
description: "SPARC structured development lifecycle — Specification, Pseudocode, Architecture, Refinement, Completion. Optional workflow for complex features."
---

# SPARC Methodology

A 5-phase structured development lifecycle for complex features. SPARC front-loads design thinking — specification and architecture are done before a single line of code is written, which prevents expensive mid-implementation pivots.

**SPARC is optional.** Simple tasks (bug fixes, config changes, documentation) use the standard dev-loop directly. Invoke SPARC only when complexity warrants it.

## Complexity Gate

SPARC is invoked when ANY of these conditions is true:

| Signal | Threshold |
|--------|-----------|
| Files likely affected | > 5 |
| Domains crossed (auth, payments, data, UI, etc.) | > 2 |
| New external integrations | any |
| User explicitly requests SPARC | always |

The classifier skill determines complexity automatically based on story metadata. When the gate triggers, the orchestrator switches to `mode: sparc` before entering the dev-loop.

Simple features that don't meet the threshold skip SPARC entirely and proceed directly to the dev-loop.

## The 5 Phases

### Phase 1: Specification

**Goal:** Define exactly what needs to be built, with no ambiguity.

**Output:** `.maestro/sparc/{feature}/spec.md`

**What to produce:**

```markdown
# Specification: {feature}

## Problem Statement
{What problem does this solve? Why now?}

## Requirements
{Numbered list of concrete requirements}

## Acceptance Criteria
{Gherkin-style or numbered criteria — each must be testable}

## Out of Scope
{Explicit exclusions to prevent scope creep}

## Constraints
{Technical, time, cost, compatibility constraints}

## Open Questions
{Unresolved decisions that must be answered before pseudocode}
```

**Gate:** A spec reviewer agent scores the spec 0.0–1.0 for completeness, testability, and clarity. The spec must score >= 0.95 to proceed. Below 0.95, the spec is returned to the author with specific improvement notes.

**Spec reviewer criteria:**
- Every requirement maps to at least one acceptance criterion (completeness)
- Every acceptance criterion is testable — binary pass/fail (testability)
- No requirement uses vague language: "fast", "easy", "good", "better" (clarity)
- Open questions are resolved or explicitly deferred with a rationale

### Phase 2: Pseudocode

**Goal:** Design the solution in natural language before writing any code.

**Output:** `.maestro/sparc/{feature}/pseudocode.md`

**What to produce:**

```markdown
# Pseudocode: {feature}

## Algorithm Overview
{High-level description of the approach}

## Core Logic

### {Component 1}
```
FUNCTION {name}(inputs):
  1. Validate inputs — check for {conditions}
  2. Fetch {data} from {source}
  3. FOR EACH {item} in {collection}:
     a. Apply {transform}
     b. Accumulate {result}
  4. Handle edge case: {condition} → {action}
  5. Return {output}
```

## Data Flow
{Input → Step 1 → Step 2 → Output, with types at each stage}

## Edge Cases
{Numbered list of edge cases and how each is handled}

## Error Handling
{What can fail, how each failure is surfaced}
```

**Rules:**
- No actual code — natural language with structured format only
- Must be understandable without prior context
- Every spec requirement must appear at least once in the pseudocode

**Gate:** Pseudocode must cover all spec requirements. A coverage check verifies each requirement maps to a pseudocode step. Uncovered requirements block progression.

### Phase 3: Architecture

**Goal:** Design the technical implementation approach.

**Output:** `.maestro/sparc/{feature}/architecture.md`

**What to produce:**

```markdown
# Architecture: {feature}

## File Structure
{New files to create, existing files to modify}

## Interfaces
{Function signatures, type definitions, API contracts}

## Data Models
{New or modified data structures, schemas, database tables}

## API Design
{Endpoints, request/response shapes, status codes}

## Integration Points
{How this connects to existing code — imports, hooks, events}

## State Management
{What state is owned by this feature, where it lives}

## Error Boundaries
{Where errors are caught, how they propagate}

## Testing Strategy
{Unit vs integration vs e2e, what gets tested at each layer}
```

**Gate:** Architecture must be reviewable and implement all pseudocode steps. An architect reviewer checks:
- Every pseudocode step maps to one or more files/functions in the architecture
- No circular dependencies introduced
- Interfaces are concrete enough to implement without guessing
- Testing strategy covers the acceptance criteria

### Phase 4: Refinement

**Goal:** Build and iterate using TDD until all acceptance criteria pass.

This phase IS the standard dev-loop, running inside the SPARC context. The architecture doc serves as the implementer's blueprint.

**What changes vs. standard dev-loop:**

1. Implementer receives the full SPARC output as context (spec + pseudocode + architecture)
2. TDD is mandatory — tests are written against the spec's acceptance criteria before implementation
3. Each dev-loop iteration references the architecture to stay on course
4. Self-heal runs with architecture context — errors are diagnosed against the design, not just the stacktrace

**Gate:** All tests pass. QA reviewer approves against the original spec's acceptance criteria.

### Phase 5: Completion

**Goal:** Final validation and shipping.

**Steps:**

1. Production validator runs (`scripts/production-validate.sh`) — blocks on any failures
2. Documentation updated to reflect the new feature
3. SPARC artifacts committed alongside the implementation: `.maestro/sparc/{feature}/` is included in the commit
4. Git craft commit includes SPARC metadata in the commit body:

```
feat: {feature name}

SPARC phases completed: spec(0.97), pseudocode, architecture, refinement(3 cycles), completion
Stories: {list}
Spec: .maestro/sparc/{feature}/spec.md
```

## Mode Integration

The dev-loop accepts `mode: sparc`. When set:

1. Phases 1–3 (Specification, Pseudocode, Architecture) run before the dev-loop starts
2. Phase 4 (Refinement) is the dev-loop itself, enriched with SPARC context
3. Phase 5 (Completion) runs after the dev-loop exits with a passing QA review

**Setting SPARC mode:**

In a story file:
```yaml
mode: sparc
```

Via orchestrator:
```
/maestro run --mode sparc {story}
```

The orchestrator can also auto-promote a story to SPARC mode if the complexity gate triggers after story decomposition.

## SPARC Artifact Storage

All SPARC artifacts live under `.maestro/sparc/{feature}/`:

```
.maestro/sparc/
  auth-refresh/
    spec.md          # Phase 1 output
    pseudocode.md    # Phase 2 output
    architecture.md  # Phase 3 output
    review.md        # Gate review notes (auto-generated)
  payment-webhooks/
    spec.md
    pseudocode.md
    architecture.md
    review.md
```

Artifacts are committed with the feature. Future engineers can trace design decisions back to the spec.

## Integration Points

- **Invoked by:** orchestrator (when complexity gate triggers or user requests)
- **Reads from:** story spec, scout-explorer recon reports (if available), project DNA
- **Writes to:** `.maestro/sparc/{feature}/`
- **Feeds into:** dev-loop (enriched context), git-craft (commit metadata), production-validator (phase 5)
- **Depends on:** classifier skill (complexity gate), spec reviewer agent, architect reviewer agent
