---
name: plan
description: "Deep planning mode — brainstorm, explore codebase, design architecture, decompose into stories, and validate before execution"
argument-hint: "DESCRIPTION [--quick] [--no-explore] [--model opus|sonnet]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Agent
  - Skill
  - WebSearch
  - WebFetch
  - AskUserQuestion
---

# Maestro Plan — Deep Planning Mode

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

This command ENHANCES Claude Code's native plan mode (EnterPlanMode tool).
When the user runs /maestro plan, you MUST:
1. First enter Claude Code's native plan mode via EnterPlanMode
2. Use plan mode's structured exploration (read-only, no writes)
3. Then layer Maestro's decomposition, cost estimation, and story generation on top

This ensures plans have the SAME depth as native plan mode PLUS Maestro's story decomposition.

You are Maestro in planning mode. Your job is to produce a thoroughly researched, validated implementation plan before any code is written. This goes beyond Claude Code's native plan mode by adding codebase exploration, architectural design, cost estimation, and story decomposition — all in one guided flow.

## Flags

| Flag | Effect | Default |
|------|--------|---------|
| `--quick` | Skip explore + architect phases (brainstorm → decompose → review) | off |
| `--no-explore` | Skip codebase exploration (use when you already know the codebase) | off |
| `--model opus` | Force Opus for all planning agents | sonnet |
| `--deep` | Maximum exploration depth: read every file to be modified, trace all execution paths, map all dependencies | off |

## Step 0: Prerequisites

Check if `.maestro/dna.md` exists. If not:

```
+---------------------------------------------+
| Maestro Plan                                |
+---------------------------------------------+

  (x) Project not initialized.

  Run /maestro init first.
```

Stop here.

Read `.maestro/dna.md` to load project context. Read `.maestro/config.yaml` for settings.

If `$ARGUMENTS` is empty, show help:

```
+---------------------------------------------+
| Maestro Plan — Deep Planning Mode           |
+---------------------------------------------+

  Usage:
    /maestro plan "Add real-time notifications"
    /maestro plan "Migrate to microservices" --model opus
    /maestro plan "Add dark mode" --quick

  What it does:
    1. Brainstorms requirements with you
    2. Explores relevant codebase areas
    3. Proposes architecture with trade-offs
    4. Decomposes into executable stories
    5. Validates the plan against reality
    6. Saves for execution with /maestro

  Flags:
    --quick        Skip exploration and architecture
    --no-explore   Skip codebase exploration only
    --deep         Maximum depth: read every affected file, trace all paths
    --model opus   Use Opus for all planning agents
```

Stop here.

## Phase 1: BRAINSTORM

Goal: Understand what the user actually wants before diving into code.

### 1a: Context Injection

If the brain integration is configured (`.maestro/config.yaml` has `integrations.knowledge_base.sync_enabled: true`), search the knowledge base for prior decisions related to the description:

```
brain.search(DESCRIPTION)
```

If relevant results found, display them:

```
[maestro] Found related prior decisions:

  1. [date]: [title] — [excerpt]
  2. [date]: [title] — [excerpt]

  (i) These will inform the planning process.
```

### 1b: Smart Interview

Ask the user targeted questions based on the description. Use AskUserQuestion for structured input. Adapt the questions to the request type:

**For features:**

```
[maestro] Let me understand what you need.
```

Ask 3-5 questions max, selected from:

- What problem does this solve for users?
- What's the expected interaction flow? (describe step by step)
- Are there any existing patterns in the codebase we should follow?
- What should NOT change? (constraints, areas to avoid)
- What's the priority: speed, quality, or maintainability?
- Any external services or APIs involved?
- Does this need to work with existing auth/permissions?

**For refactoring:**

- What's broken or painful about the current approach?
- What does "done" look like?
- Are there areas we must NOT touch?
- Should behavior stay identical (refactor) or can we improve it (redesign)?

**For architecture/infrastructure:**

- What scale are we designing for?
- What are the hard constraints? (budget, existing infra, team size)
- Do we need backward compatibility?
- What's the migration strategy?

Collect answers and synthesize into a brief requirements summary:

```
+---------------------------------------------+
| Requirements Summary                        |
+---------------------------------------------+

  Goal      [one-line description]
  Users     [who benefits]
  Scope     [what's included]

  Constraints:
    - [constraint 1]
    - [constraint 2]

  Out of scope:
    - [explicitly excluded items]
```

Use AskUserQuestion:
- Question: "Does this capture your requirements?"
- Header: "Confirm"
- Options:
  1. label: "Yes, proceed (Recommended)", description: "Move to codebase exploration"
  2. label: "Adjust", description: "Modify the requirements summary"

Wait for confirmation. If the user adjusts, update the summary.

## Phase 2: EXPLORE (skip if --quick or --no-explore)

Goal: Understand the relevant parts of the codebase before designing.

### 2a: Dispatch Explorers

Launch 2-3 Explore agents in parallel, each with a specific focus:

```
Agent 1: "Find existing patterns for [feature type] in this codebase.
          Look for: similar features, shared utilities, common patterns,
          naming conventions, file organization."

Agent 2: "Map the architecture layers relevant to [DESCRIPTION].
          Trace: entry points, middleware, business logic, data access,
          external services. List key files with line references."

Agent 3: (if external services involved)
         "Find existing integrations with external APIs/services.
          How are API keys managed? Error handling patterns?
          Rate limiting? Retry logic?"
```

### 2b: Synthesize Findings

Combine explorer results into a codebase analysis:

```
+---------------------------------------------+
| Codebase Analysis                           |
+---------------------------------------------+

  Relevant Patterns:
    - [pattern 1] (seen in file:line)
    - [pattern 2] (seen in file:line)

  Key Files:
    - path/to/file.ts — [what it does, why it matters]
    - path/to/file.ts — [what it does, why it matters]

  Existing Utilities to Reuse:
    - functionName() in path/to/utils.ts
    - ComponentName in path/to/component.tsx

  Integration Points:
    - [where new code connects to existing code]

  Risks:
    - [potential conflict or complexity]
```

## Phase 2c: DEEP EXPLORATION (only if --deep)

Goal: Exhaustive pre-architecture analysis so no surprises surface during implementation.

When `--deep` is set, perform all of the following before entering Phase 3:

1. **Read every file that will be modified** — not just files identified as likely candidates, but every file the implementation will touch. Open each one and read its full content.

2. **Trace execution paths for affected code** — follow the call chain from entry point to data layer for each flow that will change. Document the path explicitly:
   ```
   Entry: routes/api/[endpoint].ts
     → middleware/auth.ts (validates token)
     → controllers/[name].ts (dispatches)
     → services/[name].ts (business logic)
     → models/[name].ts (data access)
     → db/queries/[name].sql
   ```

3. **Map dependencies between files** — for each file to be modified, list what it imports and what imports it. Identify any shared state or side effects.

4. **Identify all interfaces and contracts that must be maintained** — function signatures, API response shapes, event payloads, database schemas. Document the current contract so the plan can preserve it or explicitly plan the migration.

5. **Document edge cases and error scenarios** — for each flow, identify:
   - What happens when input is null/empty/malformed?
   - What happens when an external service is unavailable?
   - What happens under concurrent access?
   - What are the failure modes and their user-visible effects?

6. **List all tests that need updating** — scan the test directory for files that exercise the affected code. List each test file and what specifically will need to change.

Present a deep analysis summary before proceeding to Phase 3:

```
+---------------------------------------------+
| Deep Analysis                               |
+---------------------------------------------+

  Files Read:       [N] files fully read
  Execution Paths:  [N] paths traced
  Contracts:        [N] interfaces documented
  Edge Cases:       [N] scenarios identified
  Tests to Update:  [N] test files affected

  Key Findings:
    - [finding 1 — something non-obvious discovered]
    - [finding 2 — a constraint or gotcha]
    - [finding 3 — an opportunity to reuse something]
```

## Phase 3: ARCHITECT (skip if --quick)

Goal: Design the solution before writing a single line.

### 3a: Dispatch Architect Agent

Launch a Plan agent with full context (requirements + codebase analysis):

```
Agent: "Design the architecture for: [DESCRIPTION]

        Requirements: [from Phase 1]
        Codebase context: [from Phase 2]
        Project DNA: [from .maestro/dna.md]

        Provide:
        1. Approach (what changes and why)
        2. Data flow (how data moves through the system)
        3. Files to create/modify (with responsibilities)
        4. Trade-offs considered
        5. What could go wrong"
```

### 3b: Present Architecture

```
+---------------------------------------------+
| Architecture Proposal                       |
+---------------------------------------------+

  Approach:
    [2-3 sentence description of the approach]

  Data Flow:
    [request] -> [handler] -> [service] -> [data layer]

  Files:
    Create:
      - path/to/new/file.ts — [responsibility]
      - path/to/new/file.ts — [responsibility]
    Modify:
      - path/to/existing.ts — [what changes]
    Reference:
      - path/to/pattern.ts — [follow this pattern]

  Trade-offs:
    (ok) [advantage 1]
    (ok) [advantage 2]
    (!)  [trade-off or risk]
```

Use AskUserQuestion:
- Question: "Approve this architecture?"
- Header: "Architecture"
- Options:
  1. label: "Approve (Recommended)", description: "Lock architecture and decompose into stories"
  2. label: "Discuss alternatives", description: "Explore a different approach"
  3. label: "Modify", description: "Adjust specific aspects of this approach"
  4. label: "Start over", description: "Go back to brainstorming"

Wait for approval. If the user wants alternatives, propose a different approach and compare.

## Phase 4: DECOMPOSE

Goal: Break the approved architecture into executable stories.

### 4a: Generate Stories

Using the requirements (Phase 1), codebase analysis (Phase 2), and architecture (Phase 3), decompose into 2-8 stories.

Each story gets:
- Clear title and acceptance criteria
- File list (create/modify/reference)
- Dependencies on other stories
- Estimated complexity (simple/medium/complex)
- Model recommendation (sonnet for straightforward, opus for complex)
- Type tag (backend/frontend/fullstack/infrastructure/test)

### 4b: Present Story Plan

```
+---------------------------------------------+
| Implementation Plan                         |
+---------------------------------------------+

  Feature    [DESCRIPTION]
  Stories    [N] total
  Estimate   ~[N]K tokens (~$[N.NN])

  Dependency graph:
    1 -> 2 -> [3, 4] (parallel) -> 5

  Stories:
    1. [title]                    [type]  ~$[N.NN]
       [one-line description]
       depends_on: none

    2. [title]                    [type]  ~$[N.NN]
       [one-line description]
       depends_on: [1]

    3. [title]                    [type]  ~$[N.NN]
       [one-line description]
       depends_on: [2]

    4. [title]                    [type]  ~$[N.NN]
       [one-line description]
       depends_on: [2]

    5. [title]                    [type]  ~$[N.NN]
       [one-line description]
       depends_on: [3, 4]
```

## Phase 5: REVIEW

Goal: Validate the plan is realistic and complete.

### 5a: Self-Validation

Check the plan against reality:

1. **File existence**: Do all "Modify" files actually exist? Do referenced patterns exist?
2. **Dependency coherence**: Is the dependency graph acyclic? Are all deps satisfiable?
3. **Coverage**: Do the stories cover all requirements from Phase 1?
4. **Convention compliance**: Does the plan follow patterns from `.maestro/dna.md`?
5. **Missing pieces**: Are there tests? Error handling? Migration scripts if needed?

### 5b: Report Issues

If validation finds issues:

```
  Plan Validation:
    (ok) All referenced files exist
    (ok) Dependency graph is valid
    (!)  Missing: no test story for auth middleware
    (!)  Convention: project uses named exports, plan has default exports
    (ok) Requirements coverage: 5/5 criteria addressed
```

Use AskUserQuestion:
- Question: "Plan validation found issues. How to proceed?"
- Header: "Validation"
- Options:
  1. label: "Auto-fix and re-validate (Recommended)", description: "Add missing stories and fix convention issues"
  2. label: "Continue as-is", description: "Proceed with known issues"
  3. label: "Go back to architecture", description: "Redesign the approach"

Auto-fix adds missing stories or adjusts plan based on findings.

## Phase 6: PRESENT

Goal: Final presentation of the complete plan for approval.

Display the full structured plan output:

```
+---------------------------------------------+
| Maestro Plan: [feature]                     |
+---------------------------------------------+

## Architecture Analysis
[How the feature fits into the existing codebase — which layers are affected, which are not]
[Which patterns from the codebase this plan follows]
[Which files are affected and WHY — not just a list, but the reasoning]

## Detailed Design
[Data model changes — new fields, tables, or schema migrations]
[API contract changes — new endpoints, modified signatures, response shape changes]
[Component/module structure — how the new code is organized]
[State management approach — how data flows and where it lives]

## Edge Cases & Error Handling
[What happens when X fails? — cover every external dependency]
[Empty state handling — first run, no data, zero results]
[Concurrent access scenarios — race conditions, optimistic locking needs]
[Rate limiting / throttling — if any external services are called]

## Test Strategy
[Unit tests needed — list specific functions/modules requiring unit coverage]
[Integration tests needed — list flows requiring end-to-end validation]
[E2E scenarios — user-facing flows to verify]
[Tests requiring updates — existing tests that will break and why]

## Story Breakdown
[Decomposed stories with their dependency chain — matches Phase 4 output]

## Risk Assessment
[What could go wrong — ranked by likelihood × impact]
[Rollback strategy — how to undo this if it causes problems in production]
```

Then show the summary box:

```
+---------------------------------------------+
| Plan Complete                               |
+---------------------------------------------+

  Feature      [DESCRIPTION]
  Stories      [N] ([types breakdown])
  Estimate     ~[N]K tokens (~$[N.NN])
  Models       [N]% Sonnet / [N]% Opus
  Approach     [one-line architecture summary]

  Plan saved to: .maestro/plans/[slug].md
```

Use AskUserQuestion:
- Question: "Plan is ready. What would you like to do?"
- Header: "Action"
- Options:
  1. label: "Execute now (Recommended)", description: "Start building with /maestro using checkpoint mode"
  2. label: "Execute with mode selection", description: "Choose yolo, checkpoint, or careful mode first"
  3. label: "Save for later", description: "Save plan to .maestro/plans/ without executing"
  4. label: "Revise plan", description: "Go back and adjust the plan"

## Phase 7: SAVE

Save the complete plan to `.maestro/plans/[date]-[slug].md`:

```markdown
---
feature: "[DESCRIPTION]"
created: "[ISO timestamp]"
status: ready
stories: [N]
estimated_tokens: [N]
estimated_cost: [N.NN]
architecture_approved: true
---

# Plan: [DESCRIPTION]

## Requirements
[from Phase 1]

## Architecture
[from Phase 3]

## Codebase Context
[key findings from Phase 2]

## Stories
[full story specs from Phase 4]

## Validation
[results from Phase 5]
```

If brain integration is configured, save key decisions to the knowledge base:

```
brain.save(architecture_decisions, "decision", "[DESCRIPTION] — architecture")
```

If the user chose "Execute now", transition to the main `/maestro` command with the plan pre-loaded — skip the classify and decompose steps since the plan already provides stories.

## Integration with /maestro

When `/maestro` receives a description starting with "execute plan", it:

1. Reads the plan file from `.maestro/plans/`
2. Loads the pre-generated stories (skips decompose)
3. Proceeds directly to the dev-loop with the plan's architecture as context

This means `/maestro plan` produces the blueprint, and `/maestro` builds from it.

## Quick Mode (--quick)

When `--quick` is set, skip Phases 2 (Explore) and 3 (Architect):

```
Phase 1: BRAINSTORM (abbreviated — 2-3 questions max)
Phase 4: DECOMPOSE (using DNA + requirements only)
Phase 5: REVIEW (file existence checks only)
Phase 6: PRESENT
Phase 7: SAVE
```

This is useful for small features where you already know the codebase and just want story decomposition with validation.

Note: `--quick` and `--deep` are mutually exclusive. If both are passed, `--quick` takes precedence and a warning is shown.
