---
name: demo
description: "Interactive demo of Maestro — shows all phases without making real changes"
argument-hint: ""
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Maestro Demo

A guided walkthrough of all Maestro phases using a dummy feature ("Add a greeting endpoint"). No files are created, no agents are dispatched, no commits are made. The demo simulates each phase so the user can see exactly how Maestro works before using it on real code.

Estimated runtime: ~2 minutes.

## Setup

Before starting, display the intro banner:

```
+---------------------------------------------+
| Maestro Demo                                |
+---------------------------------------------+
  (i) This demo walks through a simulated build
  (i) No real changes will be made to your code
  (i) Feature: "Add a greeting endpoint"

  Phases: classify > forecast > decompose >
          validate > delegate > implement >
          self-heal > QA > git-craft >
          checkpoint
```

Pause briefly between each phase to let the user read the output.

## Phase 1: CLASSIFY

Show what the classifier would do:

```
[maestro] Phase 1/10: CLASSIFY

  classify > [CLASSIFY] > forecast > decompose > validate > delegate > implement > self-heal > qa > git-craft > checkpoint

+---------------------------------------------+
| Classification                              |
+---------------------------------------------+
  Input       "Add a greeting endpoint"
  Layer       3 (Execution)
  Type        feature
  Complexity  simple
  Confidence  95%

  (ok) Routed to: standard dev-loop
  (i)  No research sprint needed
  (i)  No architecture review needed
```

## Phase 2: FORECAST

Show the cost and time estimate:

```
[maestro] Phase 2/10: FORECAST

  classify > forecast > [FORECAST] > decompose > validate > delegate > implement > self-heal > qa > git-craft > checkpoint

+---------------------------------------------+
| Forecast                                    |
+---------------------------------------------+
  Stories    ~2 (1 backend, 1 test)
  Tokens     ~45K
  Cost       ~$1.05
  Models     80% Sonnet / 20% Opus
  Mode       checkpoint

  (i) Tip: --yolo saves ~15% tokens
```

Explain: "In a real run, Maestro would ask you to approve this forecast before proceeding."

## Phase 3: DECOMPOSE

Show the story breakdown:

```
[maestro] Phase 3/10: DECOMPOSE

  classify > forecast > decompose > [DECOMPOSE] > validate > delegate > implement > self-heal > qa > git-craft > checkpoint

+---------------------------------------------+
| Decomposition: 2 stories                    |
+---------------------------------------------+

  Story 1/2: greeting-endpoint
    Type        backend
    Model       sonnet
    Depends on  (none)
    Files       src/routes/greeting.ts (create)
                src/routes/index.ts (modify)
    Criteria    GET /api/greeting returns { message: "Hello, World!" }
                Accepts ?name= query param
                Returns 400 if name > 50 chars

  Story 2/2: greeting-tests
    Type        test
    Model       sonnet
    Depends on  01-greeting-endpoint
    Files       tests/greeting.test.ts (create)
    Criteria    Tests default greeting
                Tests custom name param
                Tests validation error
```

## Phase 4: VALIDATE

Show the prerequisite check for story 1:

```
[maestro] Phase 4/10: VALIDATE (Story 1/2: greeting-endpoint)

  [======>               ] 0/2 stories

  validate > [VALIDATE] > delegate > implement > self-heal > qa > git-craft > checkpoint

+---------------------------------------------+
| Validate: 01-greeting-endpoint              |
+---------------------------------------------+
  (ok) No dependencies to check
  (ok) src/routes/index.ts exists
  (ok) Story spec complete
  (ok) No conflicting worktrees

  Result: VALIDATED
```

## Phase 5: DELEGATE

Show context package assembly:

```
[maestro] Phase 5/10: DELEGATE (Story 1/2: greeting-endpoint)

  validate > delegate > [DELEGATE] > implement > self-heal > qa > git-craft > checkpoint

+---------------------------------------------+
| Delegate: 01-greeting-endpoint              |
+---------------------------------------------+
  Context tier  T3 (simple story)
  Context size  ~4,200 tokens
  Model         sonnet
  Tools         Read, Edit, Write, Bash, Grep, Glob
  Isolation     worktree

  Context package includes:
    (ok) Story spec (acceptance criteria)
    (ok) Project conventions from CLAUDE.md
    (ok) Existing route pattern from src/routes/
    (ok) TypeScript config
```

## Phase 6: IMPLEMENT

Show what the implementer agent would do:

```
[maestro] Phase 6/10: IMPLEMENT (Story 1/2: greeting-endpoint)

  validate > delegate > implement > [IMPLEMENT] > self-heal > qa > git-craft > checkpoint

+---------------------------------------------+
| Implement: 01-greeting-endpoint             |
+---------------------------------------------+
  (i) Agent dispatched in background worktree
  (i) TDD sequence:

  Step 1: Write failing test for default greeting
  Step 2: Implement GET /api/greeting handler
  Step 3: Test passes
  Step 4: Write failing test for ?name= param
  Step 5: Add query param support
  Step 6: Test passes
  Step 7: Write failing test for validation
  Step 8: Add 400 response for name > 50 chars
  Step 9: All tests pass
  Step 10: Register route in index.ts

  Agent status: DONE
  Tokens used: ~18,400
  Time: ~45s
```

## Phase 7: SELF-HEAL

Show the automated check sequence:

```
[maestro] Phase 7/10: SELF-HEAL (Story 1/2: greeting-endpoint)

  validate > delegate > implement > self-heal > [SELF-HEAL] > qa > git-craft > checkpoint

+---------------------------------------------+
| Self-Heal: 01-greeting-endpoint             |
+---------------------------------------------+
  (ok) TypeScript compilation   npx tsc --noEmit
  (ok) Linting                  npm run lint
  (ok) Tests                    3/3 passing

  Result: ALL CHECKS PASSED (no fixes needed)
```

Explain: "If any check had failed, Maestro would dispatch a fix agent (up to 3 attempts). If all 3 fail, it pauses and asks you for help."

## Phase 8: QA REVIEW

Show what the QA reviewer would check:

```
[maestro] Phase 8/10: QA REVIEW (Story 1/2: greeting-endpoint)

  validate > delegate > implement > self-heal > qa > [QA] > git-craft > checkpoint

+---------------------------------------------+
| QA Review: 01-greeting-endpoint             |
+---------------------------------------------+
  Reviewer     opus (read-only agent)
  Reviewing    git diff main...HEAD

  Checklist:
    (ok) GET /api/greeting returns correct JSON   confidence: 95
    (ok) Query param ?name= works                 confidence: 92
    (ok) Validation rejects name > 50 chars        confidence: 90
    (ok) No security issues                        confidence: 88
    (ok) Follows project conventions                confidence: 85

  Verdict: APPROVED (first attempt)
```

Explain: "If rejected, Maestro would send the feedback back to the implementer and re-run. Up to 5 QA iterations before pausing."

## Phase 9: GIT CRAFT

Show the commit that would be created:

```
[maestro] Phase 9/10: GIT CRAFT (Story 1/2: greeting-endpoint)

  validate > delegate > implement > self-heal > qa > git-craft > [GIT-CRAFT] > checkpoint

+---------------------------------------------+
| Git Craft: 01-greeting-endpoint             |
+---------------------------------------------+
  Commit message:

  feat(api): add greeting endpoint

  - Files changed: src/routes/greeting.ts (create),
    src/routes/index.ts (modify)
  - Tests: 3 tests added, all passing
  - Acceptance criteria:
    [x] GET /api/greeting returns { message: "Hello, World!" }
    [x] Accepts ?name= query param
    [x] Returns 400 if name > 50 chars

  Story: 01-greeting-endpoint
```

## Phase 10: CHECKPOINT

Show the checkpoint interaction:

```
[maestro] Phase 10/10: CHECKPOINT (Story 1/2: greeting-endpoint)

  validate > delegate > implement > self-heal > qa > git-craft > checkpoint > [CHECKPOINT]

+---------------------------------------------+
| Story 1/2 complete: greeting-endpoint       |
+---------------------------------------------+
  Phase     QA approved (first attempt)
  Files     1 created, 1 modified
  Tests     3 new, all passing
  Commit    feat(api): add greeting endpoint
  Tokens    24,600 (story) / 24,600 (total)
  Time      1m 02s (story) / 1m 02s (total)
```

Explain: "In checkpoint mode, Maestro would ask: Continue, Review, Change mode, or Abort. In yolo mode, it auto-continues. In careful mode, you see every phase in detail."

## Skip Story 2

After showing the full cycle for story 1, summarize story 2 briefly:

```
[maestro] Story 2/2: greeting-tests would follow the same cycle

  (i) Validate: check that story 1 is DONE
  (i) Delegate: T3 context, model sonnet
  (i) Implement: write 3 test cases
  (i) Self-heal: run checks
  (i) QA: verify test coverage
  (i) Git craft: test(api): add greeting endpoint tests
  (i) Checkpoint: final summary
```

## Completion Summary

Show the feature completion summary:

```
+---------------------------------------------+
| Feature complete                            |
+---------------------------------------------+
  Feature   Add a greeting endpoint
  Stories   2 completed, 0 skipped
  QA rate   100% first-pass
  Tokens    ~45K
  Cost      ~$1.05
  Time      ~2m 00s
  Commits   2

  Trust     Novice (2 stories, 100% QA rate)

  (i) This was a demo — no real changes were made
```

## Post-Demo

After the completion summary, use AskUserQuestion to ask what the user wants to do next:

- **Question**: "Ready to build something real?"
- **Options**:
  1. "Yes, let's go" -- respond with: "Great! Type `/maestro \"your feature description\"` to start building."
  2. "Show me the commands first (/maestro help)" -- invoke `/maestro help` to display the topic list
  3. "Not yet" -- respond with: "No rush. Run `/maestro demo` again anytime, or `/maestro help` when you have questions."
