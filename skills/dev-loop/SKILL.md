---
name: dev-loop
description: "Execute the 7-phase implementation cycle for each story: validate, delegate, implement, self-heal, QA review, git craft, checkpoint. Use after decomposition to build stories sequentially."
---

# Dev Loop

The core execution engine. For each story in dependency order, executes a 7-phase implementation cycle. Uses background agents for implementation while the orchestrator stays responsive.

## Overview

```
For each story in dependency order:
  Phase 1: VALIDATE    — Prerequisites check
  Phase 2: DELEGATE    — Build context package, select model
  Phase 3: IMPLEMENT   — Dispatch implementer agent (background, worktree)
  Phase 4: SELF-HEAL   — Run checks, auto-fix failures (up to 3x)
  Phase 5: QA REVIEW   — Dispatch QA reviewer agent (read-only)
  Phase 6: GIT CRAFT   — Documentation-quality commit
  Phase 7: CHECKPOINT  — Mode-dependent user interaction
```

## North Star Anchoring

At every phase transition, re-inject the original feature goal to prevent drift. Long autonomous runs naturally accumulate context noise. The North Star keeps agents aligned.

Format injected at each phase:
```
NORTH STAR: [Original feature description]
CURRENT STORY: [N of M] — [Story title]
CURRENT PHASE: [Phase name]
```

## Between Stories

Before starting each new story:
1. Check `.maestro/notes.md` for user messages posted during the previous story's execution
2. Incorporate relevant notes (scope changes, clarifications, priority shifts)
3. If notes contradict the current story spec, PAUSE and ask the user

## Phase 1: VALIDATE

Check all prerequisites before dispatching an implementer.

**Checks:**
- All stories in `depends_on` are marked DONE in state
- Required files from the story spec exist on disk
- Story spec is complete (has acceptance criteria, file lists, context)
- No conflicting worktrees from a previous failed run

**On failure:**
- Missing dependency: skip this story, log reason, continue to next eligible story
- Missing files: check if a previous story should have created them. If so, flag the dependency gap
- Incomplete spec: PAUSE, show what is missing, ask user to fill in

**Output:** VALIDATED or BLOCKED (with reason)

## Phase 2: DELEGATE

Build the right-sized context package for the implementer agent.

### Context Tiers

| Tier | Size | Use Case |
|------|------|----------|
| T1 | 15-25K tokens | Full story: spec + all project rules + architecture + examples |
| T2 | 8-15K tokens | Standard story: spec + relevant rules + patterns + interfaces |
| T3 | 4-8K tokens | Simple story: spec + key conventions + file references |
| T4 | 1-3K tokens | Fix agent: just the error message + affected file |

Default to **T3** for implementer agents. Escalate to T2 or T1 only on NEEDS_CONTEXT responses.

### Context Package Assembly

The implementer prompt (see `implementer-prompt.md`) is filled with:

1. **Story Spec** — The full story markdown from `.maestro/stories/NN-slug.md`
2. **Project Rules** — Relevant subset of `CLAUDE.md` (not the entire file; only sections that apply to this story's type and files)
3. **Coding Patterns** — Extracted from `.maestro/dna.md`: naming conventions, file structure, import patterns
4. **Interface Definitions** — Type definitions and function signatures the story depends on
5. **Files to Reference** — From the story's Reference list, read and include key sections
6. **QA History** — If this is a re-dispatch after QA rejection, include all previous QA feedback

**Exclude from context:**
- Other stories (the implementer does not need the full backlog)
- Roadmap, vision, strategy documents
- Research and competitive analysis
- Architecture beyond the interfaces this story touches

### Model Selection

Use the story's `model_recommendation` field. Override rules:
- If story failed QA 2+ times with `sonnet`, escalate to `opus`
- If story is `haiku`-recommended but has QA history, escalate to `sonnet`
- Never downgrade from the story's recommendation

## Phase 3: IMPLEMENT

Dispatch the implementer as a background agent in an isolated worktree.

### Agent Configuration

```yaml
name: implementer
model: [from Phase 2 model selection]
tools: [Read, Edit, Write, Bash, Grep, Glob]
isolation: worktree
memory: project
maxTurns: 50
```

### Dispatch

Use `run_in_background: true` so the orchestrator stays responsive. The user can:
- Ask questions about the feature
- Post notes to `.maestro/notes.md`
- Check progress
- Request a PAUSE

### Response Protocol

The implementer reports one of four statuses:

| Status | Meaning | Orchestrator Action |
|--------|---------|-------------------|
| `DONE` | Story implemented and self-reviewed | Proceed to Phase 4 |
| `DONE_WITH_CONCERNS` | Implemented but has non-blocking concerns | Read concerns. If truly non-blocking, proceed to Phase 4. If blocking, treat as NEEDS_CONTEXT |
| `NEEDS_CONTEXT` | Missing information to proceed | Context Engine escalation: bump tier (T3 to T2 to T1), add requested context, re-dispatch |
| `BLOCKED` | Cannot proceed (missing dependency, unclear spec, tooling issue) | Assess the blocker. If model capability issue, re-dispatch with more capable model. If spec issue, PAUSE and ask user |

### TDD Enforcement

The implementer follows TDD discipline (enforced via the prompt):
1. Write a failing test that captures the acceptance criterion
2. Implement the minimum code to make the test pass
3. Refactor if needed
4. Repeat for each criterion

## Phase 4: SELF-HEAL

Run automated checks and fix failures.

### Check Sequence

```bash
# 1. TypeScript compilation
npx tsc --noEmit

# 2. Linting
npm run lint

# 3. Test suite (affected tests, then full suite)
npm test
```

### Auto-Fix Loop

If any check fails:
1. Dispatch a **T4 fix agent** (1-3K context: just the error output + affected file)
2. Fix agent makes targeted corrections
3. Re-run the failing check
4. Repeat up to **3 times**

Fix agent configuration:
```yaml
name: fixer
model: sonnet
tools: [Read, Edit, Bash]
maxTurns: 10
```

### Escalation

After 3 failed auto-fix attempts:
- **PAUSE** execution
- Show all error output to the user
- Ask for guidance: fix manually, skip story, or abort feature

Do NOT continue to QA with failing checks.

## Phase 5: QA REVIEW

Dispatch an independent QA reviewer to catch issues the implementer missed.

### Agent Configuration

```yaml
name: qa-reviewer
model: opus
tools: [Read, Bash, Grep, Glob]
maxTurns: 30
```

The QA agent is **read-only** — it must not edit files. It uses the prompt template from `qa-reviewer-prompt.md`.

### QA Context Package

- Story spec (acceptance criteria as the review checklist)
- Diff against main branch (`git diff main...HEAD` from the worktree)
- Test output (from Phase 4)
- Relevant project rules (style, security, conventions)

### Confidence Scoring

The QA agent scores each finding 0-100. Only issues with **confidence >= 80** are reported. This prevents noise from subjective preferences.

### QA Verdicts

| Verdict | Action |
|---------|--------|
| `APPROVED` | Proceed to Phase 6 |
| `REJECTED` | Back to Phase 3 with QA feedback appended to context. Increment QA iteration counter |

### QA Iteration Limit

Maximum **5 QA iterations** per story. If still rejected after 5 rounds:
- **PAUSE** execution
- Show all accumulated QA feedback
- Ask user: fix manually, force-approve, skip, or abort

## Phase 6: GIT CRAFT

Create a documentation-quality commit for the completed story.

### Commit Format

```
type(scope): concise description

- Files changed: list of created/modified files
- Tests: N tests added, all passing
- Acceptance criteria:
  [x] Criterion 1
  [x] Criterion 2
  [x] Criterion 3

Story: NN-slug
```

**Type** follows conventional commits: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`.

**Scope** is derived from the story's `type` field and primary directory affected.

### Merge Strategy

If the story was implemented in a worktree:
1. Verify no merge conflicts with main working tree
2. Merge the worktree branch into the feature branch
3. Clean up the worktree

If conflicts exist, PAUSE and present the conflict to the user.

## Phase 7: CHECKPOINT

Behavior depends on the execution mode.

### Mode: yolo

Auto-continue to the next story. No user interaction. Log a one-line summary:
```
[3/7] DONE: 03-frontend-ui (35K tokens, 2m14s)
```

### Mode: checkpoint

Show a summary and ask for direction:
```
Story 3/7 complete: Frontend Dashboard UI

Files changed: 4 created, 2 modified
Tests: 8 added, all passing
Tokens used: 34,200 (this story) / 127,800 (total)
Time: 2m14s

[GO] Continue to next story
[PAUSE] I want to review before continuing
[ABORT] Stop execution, keep what we have
[MODE] Change mode for remaining stories
```

### Mode: careful

Show detailed phase-by-phase results:
```
Story 3/7: Frontend Dashboard UI — DETAILED REPORT

Phase 1 VALIDATE: PASSED (dependencies 01, 02 met)
Phase 2 DELEGATE: T3 context (4,200 tokens), model: sonnet
Phase 3 IMPLEMENT: DONE (first attempt, 28,100 tokens)
Phase 4 SELF-HEAL: PASSED (tsc clean, lint clean, 8/8 tests pass)
Phase 5 QA REVIEW: APPROVED (first review, 0 issues)
Phase 6 GIT CRAFT: feat(ui): add dashboard layout with chart widgets

[APPROVE] Accept and continue
[REVIEW] I want to inspect the changes in detail
[REDO] Re-implement this story with different parameters
[ABORT] Stop execution
```

### Mode Changes at Checkpoint

The user can switch modes at any checkpoint. Common patterns:
- Start `careful`, switch to `checkpoint` after gaining confidence
- Start `checkpoint`, switch to `yolo` for the remaining simple stories
- Switch to `careful` when approaching complex or risky stories

### Magnum Opus Checkpoints

In Magnum Opus mode, checkpoints also show milestone progress:
```
Milestone 2/5: Core Features — 4/6 stories complete
Overall: 11/23 stories done | $4.80 spent | 2h 15m elapsed
```

## Error Recovery Reference

| Situation | Action |
|-----------|--------|
| QA rejected 5 times | PAUSE. Show all feedback. Ask user |
| Self-heal failed 3 times | PAUSE. Show errors. Ask user |
| ABORT requested | Revert uncommitted changes. Keep completed stories. Clean up worktrees |
| SKIP requested | Mark story as SKIPPED in state. Check if any downstream stories depend on it. If yes, warn user those will also be blocked |
| Agent returns BLOCKED | Assess blocker. Escalate model or escalate to user |
| Agent returns NEEDS_CONTEXT | Bump context tier. Add requested info. Re-dispatch |
| Merge conflict | PAUSE. Show conflict. Ask user to resolve |
| Token budget exceeded | PAUSE. Show spend. Ask user to extend budget or stop |

## Token Tracking

If cost tracking is enabled (`.maestro/config.md` or `dna.md`), log per-phase token usage:

```
.maestro/state.local.md:
  story_03:
    phase_2_delegate: 4200
    phase_3_implement: 28100
    phase_4_selfheal: 0
    phase_5_qa: 6300
    total: 38600
```

## State Management

Track execution state in `.maestro/state.local.md`:

```yaml
feature: "Dashboard with budget tracking"
mode: checkpoint
current_story: 3
stories:
  01-data-schema: DONE
  02-api-routes: DONE
  03-frontend-ui: IN_PROGRESS
  04-integration-tests: PENDING
tokens_total: 127800
started_at: "2026-03-17T10:30:00Z"
```

This file is `.gitignore`d — it tracks local execution state only.
