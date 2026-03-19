---
name: spec-first
description: "Plan-first safety net (Pillar 4). Enforces a structured spec document before any dev-loop starts. Auto-generates spec from a one-line description, validates completeness, and elevates the spec to T1 context for all agents."
---

# Spec-First

A spec is mandatory before any feature build begins. This skill enforces the discipline: no code is written until a validated spec exists. It auto-generates a spec from a one-line description using the researcher agent, validates completeness, and injects the spec as T1 context into every agent downstream.

Research shows that a well-formed 2,000-word spec outperforms 50,000 lines of code context as agent input. Specs prevent scope creep, reduce QA rejection loops, and make every agent's job unambiguous.

## When This Skill Activates

The spec-first gate fires whenever `/maestro build <description>` is called. It inserts itself between the user's feature request and the `decompose` skill.

```
User: /maestro build "add dark mode toggle"
  |
  v
[spec-first gate]
  |-- spec exists and is active? --> skip generation, validate, proceed
  |-- spec exists but is draft? --> validate completeness, activate if valid
  |-- no spec exists? --> auto-generate, validate, activate
  |
  v
decompose (receives active spec as input)
  |
  v
dev-loop (spec injected as T1 context for all agents)
```

## Auto-Generation Flow

When no spec exists for the requested feature:

### Step 1: Spawn Researcher Agent

Dispatch a researcher agent (model: `sonnet`) with the user's one-line description:

```yaml
name: researcher
model: sonnet
tools: [Read, Glob, Grep, WebSearch, WebFetch]
maxTurns: 20
prompt: |
  Generate a structured feature spec for: "[user description]"

  Read .maestro/dna.md to understand the project's tech stack, patterns, and constraints.
  Read .maestro/state.md for current project context.
  If a CLAUDE.md or architecture.md exists, read the relevant sections.

  Fill every section of the spec template at templates/spec.md.
  Output only the completed spec document (no preamble).
  The spec must be concrete enough that an engineer unfamiliar with the codebase
  could implement the feature correctly after reading only the spec.
```

### Step 2: Save Draft

Write the researcher's output to `.maestro/specs/{slug}.md` with frontmatter:

```markdown
---
name: "[feature name]"
status: draft
created: [ISO date]
author: auto-generated
priority: medium
source: "[original one-line description]"
---
```

Where `{slug}` is the feature name converted to kebab-case.

### Step 3: Validate Completeness

Run the completeness check (see "Spec Validation" below). If the spec passes, auto-activate. If it fails, show the user what is missing and ask them to fill in the gaps before proceeding.

### Step 4: Present to User

Show the generated spec with a summary before activating:

```
Spec generated: "Dark Mode Toggle"

  Problem:     Defined (42 words)
  AC:          5 acceptance criteria
  Architecture: 2 decisions captured
  Constraints: 3 constraints
  Non-goals:   2 items
  DoD:         3 success metrics

  [ACTIVATE] Looks good, start building
  [EDIT]     I want to adjust the spec first
  [ABORT]    Cancel
```

Use AskUserQuestion for this decision:
- Question: "Spec generated for '[feature]'. Activate and start building?"
- Header: "Spec Ready"
- Options: Activate (Recommended) / Edit first / Abort

## Spec Validation

Before a spec can move from `draft` to `active`, it must pass the completeness gate:

| Section | Requirement | Failure Mode |
|---------|------------|-------------|
| Problem Statement | Non-empty, >= 20 words | "Problem section is missing or too brief" |
| Acceptance Criteria | >= 3 criteria, all testable | "Fewer than 3 acceptance criteria" |
| Architecture Decisions | >= 1 decision captured | "No architecture decisions recorded" |
| Constraints | Present (may be "none") | "Constraints section missing" |
| Non-Goals | Present (may be "none") | "Non-goals section missing — adds scope clarity" |
| Definition of Done | >= 1 success metric | "No success metrics defined" |

Run the gate:

```
Spec validation: "Dark Mode Toggle"
  (ok) Problem: 47 words
  (ok) Acceptance Criteria: 5 criteria
  (ok) Architecture: 2 decisions
  (ok) Constraints: "CSS variables only, no JS-based theming"
  (ok) Non-Goals: "Mobile-specific theming, per-component overrides"
  (ok) Definition of Done: 3 metrics

  Result: VALID — ready to activate
```

If any check fails, list all failures together before asking the user to fix them. Do not activate a spec with failing gates.

## Context Injection

Once a spec is `active`, it is the highest-priority context artifact in the system.

| Context Tier | Source | Token Budget |
|-------------|--------|-------------|
| T1 | Active spec | Always included, no budget cap |
| T2 | Project DNA, CLAUDE.md | Included per story type |
| T3 | Story-specific files, interfaces | Included per story |
| T4 | Fix context (errors only) | Fix agents only |

The spec overrides conflicting signals from lower tiers. If the spec says "use CSS variables only" and a T3 pattern suggests a different approach, the spec wins.

### Agents Receiving the Spec

| Agent | Spec Sections Received | Purpose |
|-------|----------------------|---------|
| `orchestrator` | Full spec | Source of truth for all decisions |
| `decompose` | Problem + AC + Architecture + Constraints | Maps requirements to stories |
| `implementer` | Problem + relevant AC + Architecture + Constraints | Scopes the story's implementation |
| `qa-reviewer` | AC + Non-Goals + DoD | Validates against spec, catches scope creep |
| `strategist` | Problem + Non-Goals + Constraints | Prevents pivot away from original intent |

## Spec Lifecycle

```
draft → active → implementing → complete
                      |
                      v
               [all AC checked off]
```

| Status | Meaning | Who sets it |
|--------|---------|------------|
| `draft` | Being generated or edited | spec-first skill |
| `active` | Validated, immutable, ready to build | `/maestro spec activate` or spec-first auto-activation |
| `implementing` | Dev-loop has started against this spec | Maestro automatically at first story dispatch |
| `complete` | All acceptance criteria verified | `/maestro spec complete <slug>` |

**Immutability rule:** Once a spec is `active`, its Acceptance Criteria are frozen. To add scope, create `{slug}-v2.md` and link it to the original. Never edit active AC in place.

## Integration with /maestro build

The full flow when a user runs `/maestro build "description"`:

```
1. spec-first checks .maestro/specs/ for an active spec
2. If none: auto-generate → validate → present → activate
3. Decompose reads the active spec's AC → creates stories with satisfies: [AC-N]
4. Dev-loop loads spec as T1 at every phase
5. QA reviewer checks each story against spec AC
6. Stories not traceable to an AC are flagged as out-of-scope
7. On completion: /maestro spec complete <slug> verifies all AC are checked
```

## Traceability Chain

Every story produced by decompose must cite the spec requirements it satisfies:

```yaml
---
id: 3
slug: dark-mode-css-variables
satisfies: [AC-1, AC-3]
---
```

Stories that cannot be traced to a spec AC are rejected at the validate phase with:

```
Story "dark-mode-css-variables" satisfies: [AC-1, AC-3]
  (ok) AC-1: covered
  (x)  AC-3: no code in story diff touches this criterion
  Story returned to implementer — AC-3 must be addressed
```

## Bypass

For exploratory or prototype work, the spec-first gate can be bypassed:

```
/maestro build "description" --no-spec
```

This flag is logged in `.maestro/audit-log.md` with a reason prompt. The orchestrator asks for a bypass reason before proceeding:

```
Bypassing spec-first gate. Reason? (e.g., prototype, spike, hotfix)
```

Bypasses should be rare. They are appropriate for spikes, hotfixes under time pressure, and exploratory throwaway work.

## State

Track spec-first state in `.maestro/state.local.md`:

```yaml
spec_first:
  active_spec: .maestro/specs/dark-mode-toggle.md
  generated_at: "2026-03-18T09:15:00Z"
  generation_tokens: 4200
  validation: passed
  bypass_count: 0
```

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `spec` | spec-first enforces the gate; `spec` handles lifecycle and context injection — they are complementary |
| `decompose` | Receives active spec as primary input; maps AC to stories |
| `dev-loop` | Consumes spec as T1 context in every phase |
| `qa-reviewer` | Uses spec AC as the review checklist |
| `context-engine` | Loads spec from `.maestro/specs/` when composing agent packages |
| `research` | Researcher agent is dispatched by spec-first to generate the initial spec draft |
