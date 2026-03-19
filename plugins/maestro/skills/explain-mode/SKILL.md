---
name: explain-mode
description: "Educational mode that explains each Maestro phase as it runs. Teaches users how the orchestrator works by narrating decisions in real-time, including why each phase exists."
---

# Explain Mode

When enabled, Maestro narrates each phase transition with educational context. Each explanation covers both **what** is happening and **why** the phase exists — so users build a mental model of the orchestrator, not just a list of steps.

## Activation

Enabled automatically when:
- Trust level is `novice` (first 5 stories on a project)
- User runs `/maestro demo`
- User explicitly sets `--careful` mode (which already pauses at each phase)

Toggle on or off at any time:
```
/maestro explain on
/maestro explain off
```

Can also be set via config:
```yaml
explain_mode: true  # or false
```

Command takes precedence over config. Config takes precedence over auto-detection.

## Auto-Disable

Explain mode auto-disables after **3 completed features** (not stories — features).

When the third feature's CHECKPOINT fires, append to terminal output:

```
[Explain Mode] You've run 3 features with explanations on.
You know the flow now — turning explain mode off.
Run `/maestro explain on` to re-enable it any time.
```

Then set `explain_mode: false` in `.maestro/config.yaml`.

Auto-disable does not fire if the user explicitly enabled explain mode via `/maestro explain on` — only for sessions where it was enabled automatically (trust level, demo, careful mode). Track this with a state flag:

```yaml
# .maestro/state.local.md
explain_mode_auto: true   # set when auto-enabled; cleared on explicit /maestro explain on
explain_features_count: 0 # incremented at each feature CHECKPOINT while auto-enabled
```

## Phase Explanations

Each explanation is 2-3 sentences max. Lead with what is happening, then why this phase matters.

### VALIDATE

```
--- Phase: VALIDATE ---
Checking that this story's prerequisites are met before spending tokens on it.

What I'm checking:
  - Story 01 (schema) is marked DONE — needed because
    this story modifies tables defined there
  - The file src/lib/db.ts exists — I'll import from it
  - No conflicting worktrees from failed runs

Why this phase exists: starting implementation on a story whose dependencies
aren't done wastes tokens and produces broken code. A fast upfront check is
cheaper than a failed build.

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

Why this phase exists: the implementer agent has no memory of prior conversations.
Delegation constructs everything it needs to produce correct, convention-following
code in a single shot — the better the context, the fewer self-heal loops.

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

Why this phase exists: implementation is isolated in a subagent so failures
stay contained and the orchestrator stays responsive. The agent follows TDD —
tests first, then code, then refactor — to ensure acceptance criteria are
verifiable, not just plausibly correct.
```

### SELF-HEAL

```
--- Phase: SELF-HEAL ---
Running quality gates on the implementer's output.

Checks:
  1. TypeScript compilation (tsc --noEmit)
  2. Linter (eslint)
  3. Test suite (vitest)

Why this phase exists: automated checks catch mechanical errors (type mismatches,
lint violations, broken tests) before a human — or another agent — has to read
the code. If any check fails, a fixer agent retries with just the error and the
affected file, up to 3 times.
```

### QA REVIEW

```
--- Phase: QA REVIEW ---
Dispatching an independent reviewer to catch issues the implementer may have missed.

The reviewer is a DIFFERENT agent from the implementer.
It's read-only — can't modify code, only report findings.

It checks:
  - All acceptance criteria implemented correctly
  - Edge cases handled (null, empty, concurrent)
  - Error handling is graceful and informative
  - Tests cover important paths
  - Code follows project conventions

Why this phase exists: the implementer is optimistic by design — it tries to
satisfy the story. An independent reviewer with no stake in the output is better
at finding gaps. If it finds issues (confidence >= 80%), the story goes back to
IMPLEMENT with specific feedback.
```

### GIT CRAFT

```
--- Phase: GIT CRAFT ---
Creating a documentation-quality commit.

The commit message includes:
  - What changed and why
  - Which acceptance criteria were met
  - Files created and modified

Why this phase exists: a well-written commit is how future developers (and future
you) understand why a change was made. Commit score is rated on tests, conventions,
message quality, and code cleanliness (0-100) — this score influences model routing
decisions for similar future stories.
```

### CHECKPOINT

```
--- Phase: CHECKPOINT ---
Story complete! Here's the summary.

Why this phase exists: a deliberate pause between stories lets you course-correct —
adjust the next story's spec, raise a concern, or simply confirm the work looks
right before the next dispatch. In yolo mode this pause is skipped; in careful mode
you've already seen each phase individually.

In checkpoint mode, you decide what happens next.
In yolo mode, I'd automatically continue.
In careful mode, you already saw each phase.
```

## Integration

- The dev-loop checks `explain_mode` config at each phase transition.
- If enabled, prepend the explanation before the phase output.
- Explanations are suppressed in yolo mode (no one is watching).
- Demo command enables explain mode throughout, bypassing auto-disable.
- At feature CHECKPOINT, increment `explain_features_count` if `explain_mode_auto` is true; trigger auto-disable at count 3.
