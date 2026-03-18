---
name: explain-mode
description: "Educational mode that explains each Maestro phase as it runs. Teaches users how the orchestrator works by narrating decisions in real-time."
---

# Explain Mode

When enabled, Maestro narrates each phase transition with educational context. Useful for new users learning how the orchestrator works, or for understanding why specific decisions were made.

## Activation

Enabled automatically when:
- Trust level is `novice` (first 5 stories on a project)
- User runs `/maestro demo`
- User explicitly sets `--careful` mode (which already pauses at each phase)

Can be toggled via config:
```yaml
explain_mode: true  # or false
```

## Phase Explanations

### VALIDATE

```
--- Phase: VALIDATE ---
Checking that this story's prerequisites are met.

What I'm checking:
  - Story 01 (schema) is marked DONE — needed because
    this story modifies tables defined there
  - The file src/lib/db.ts exists — I'll import from it
  - No conflicting worktrees from failed runs

Result: All prerequisites met. Proceeding to DELEGATE.
```

### DELEGATE

```
--- Phase: DELEGATE ---
Building the context package for the implementer agent.

What I'm doing:
  - Reading project DNA for conventions (named exports,
    cn() for class merging, Server Components default)
  - Selecting T3 context tier (4-8K tokens) — standard
    for this story complexity
  - Choosing Sonnet model (configured for execution tasks)
  - Injecting live docs for Next.js App Router API
  - Adding 2 semantic memories about this project

Context size: 5,200 tokens. Dispatching...
```

### IMPLEMENT

```
--- Phase: IMPLEMENT ---
The implementer agent is writing code for this story.

What it received:
  - Story spec with 3 acceptance criteria
  - Project conventions (from DNA)
  - Current Next.js API reference (from live-docs)
  - 2 relevant project memories

It will follow TDD: write tests first, then implementation,
then refactor. You'll see the result at the next phase.
```

### SELF-HEAL

```
--- Phase: SELF-HEAL ---
Running quality gates on the implementer's output.

Checks:
  1. TypeScript compilation (tsc --noEmit)
  2. Linter (eslint)
  3. Test suite (vitest)

If any fail, I'll dispatch a fixer agent (up to 3 times)
with just the error message + affected file.
```

### QA REVIEW

```
--- Phase: QA REVIEW ---
Dispatching an independent reviewer to catch issues.

The reviewer is a DIFFERENT agent from the implementer.
It's read-only — can't modify code, only report findings.

It checks:
  - All acceptance criteria implemented correctly
  - Edge cases handled (null, empty, concurrent)
  - Error handling is graceful and informative
  - Tests cover important paths
  - Code follows project conventions

If it finds issues (confidence >= 80%), the story goes
back to IMPLEMENT with feedback.
```

### GIT CRAFT

```
--- Phase: GIT CRAFT ---
Creating a documentation-quality commit.

The commit message includes:
  - What changed and why
  - Which acceptance criteria were met
  - Files created and modified

Commit score: rated on tests, conventions, message
quality, and code cleanliness (0-100).
```

### CHECKPOINT

```
--- Phase: CHECKPOINT ---
Story complete! Here's the summary.

In checkpoint mode, you decide what happens next.
In yolo mode, I'd automatically continue.
In careful mode, you already saw each phase.
```

## Integration

- The dev-loop checks `explain_mode` config at each phase transition
- If enabled, prepend the explanation before the phase output
- Explanations are suppressed in yolo mode (no one is watching)
- Demo command uses explain mode throughout
