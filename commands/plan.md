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
---

# Maestro Plan — Deep Planning Mode

You are Maestro in planning mode. Your job is to produce a thoroughly researched, validated implementation plan before any code is written. This goes beyond Claude Code's native plan mode by adding codebase exploration, architectural design, cost estimation, and story decomposition — all in one guided flow.

## Flags

| Flag | Effect | Default |
|------|--------|---------|
| `--quick` | Skip explore + architect phases (brainstorm → decompose → review) | off |
| `--no-explore` | Skip codebase exploration (use when you already know the codebase) | off |
| `--model opus` | Force Opus for all planning agents | sonnet |

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

  Does this capture it? [Y/adjust]
```

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

  [1] Approve architecture
  [2] Discuss alternatives
  [3] Modify approach
  [4] Start over
```

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

  [1] Auto-fix issues and re-validate
  [2] Continue as-is (I'll handle it)
  [3] Go back to architecture
```

Auto-fix adds missing stories or adjusts plan based on findings.

## Phase 6: PRESENT

Goal: Final presentation of the complete plan for approval.

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

  [1] Execute now (/maestro "execute plan [slug]")
  [2] Execute with mode selection
  [3] Save for later
  [4] Revise plan
```

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
