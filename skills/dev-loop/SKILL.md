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

Update heartbeat: write current timestamp, phase name (`validate`), and milestone/story to `.maestro/logs/heartbeat.json`.

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

Update heartbeat: write current timestamp, phase name (`delegate`), and milestone/story to `.maestro/logs/heartbeat.json`.

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
7. **Live Docs** — If the story involves a framework/library, invoke the `live-docs` skill to fetch current API docs and inject relevant signatures (max 2000 tokens)
8. **Memory** — If `.maestro/memory/semantic.md` exists, inject relevant project memories (max 500 tokens)

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

Update heartbeat: write current timestamp, phase name (`implement`), and milestone/story to `.maestro/logs/heartbeat.json`. Include `last_action: "dispatched implementer for [story-id]"` and increment `agent_dispatches`.

Dispatch the implementer as a background agent in an isolated worktree. **This applies to ALL story types** — both code and knowledge work. Worktree isolation prevents half-done changes from polluting the main tree.

### Agent Configuration

For **code stories**:
```yaml
name: implementer
model: [from Phase 2 model selection]
tools: [Read, Edit, Write, Bash, Grep, Glob]
isolation: worktree
memory: project
maxTurns: 50
```

For **knowledge work stories**:
```yaml
name: implementer
model: [from Phase 2 model selection]
tools: [Read, Write, Bash, Grep, Glob, WebSearch, WebFetch]
isolation: worktree
memory: project
maxTurns: 30
```

Knowledge work agents get `WebSearch` and `WebFetch` for research-heavy tasks but fewer turns (content creation is faster than code).

### Dispatch

**MANDATORY**: Always use `isolation: "worktree"` on the Agent tool call. This creates an isolated git worktree where the implementer works without affecting the main tree.

```
Agent(
  subagent_type: "maestro:maestro-implementer",
  isolation: "worktree",
  run_in_background: true,
  prompt: "[story spec + context package + North Star]"
)
```

The orchestrator stays responsive while the agent works. The user can:
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

### Code Stories: TDD Enforcement

The implementer follows TDD discipline (enforced via the prompt):
1. Write a failing test that captures the acceptance criterion
2. Implement the minimum code to make the test pass
3. Refactor if needed
4. Repeat for each criterion

### Knowledge Work Stories: Output-Driven Execution

The implementer follows output contract discipline:
1. Read the output contract from the generating skill
2. Create the output file with correct frontmatter and all required sections
3. Fill each section with substantive content
4. Self-check against the contract before reporting DONE
5. No TDD — validation happens in Phase 4 via content-validator

### Agent Timeout & Watchdog

Every agent dispatch MUST have a timeout and heartbeat monitoring to prevent infinite waits.

#### Timeout Configuration

| Story Type | Default Timeout | Max Timeout |
|-----------|----------------|-------------|
| Simple (haiku) | 3 minutes | 5 minutes |
| Standard (sonnet) | 5 minutes | 10 minutes |
| Complex (opus) | 10 minutes | 20 minutes |

Override via `.maestro/config.yaml`:
```yaml
timeouts:
  agent_default: 300  # 5 minutes in seconds
  agent_max: 1200     # 20 minutes
```

#### Heartbeat Monitoring

The orchestrator checks `.maestro/logs/heartbeat.json` during agent execution:
1. Agent writes heartbeat every 30 seconds (timestamp + current action)
2. If heartbeat is stale (>90 seconds old), the agent is considered hung
3. On stale heartbeat:
   a. Log warning to `.maestro/logs/agent-watchdog.log`
   b. Wait one additional 30-second cycle
   c. If still stale, terminate the agent and trigger retry

#### Retry with Exponential Backoff

When an agent times out or is terminated:
1. First retry: wait 30 seconds, then re-dispatch
2. Second retry: wait 60 seconds, then re-dispatch
3. Third retry: wait 120 seconds, then re-dispatch with escalated model (sonnet → opus)
4. After third retry failure: PAUSE and ask user

Backoff formula: `delay = 30 * 2^(retry_count - 1)` seconds

#### Circuit Breaker

Track consecutive agent failures in `.maestro/state.local.md`:
```yaml
consecutive_agent_failures: 0
circuit_breaker_threshold: 5
circuit_breaker_state: closed  # closed | open | half-open
```

State machine:
- **closed**: Normal operation. Increment counter on failure, reset on success.
- **open**: After 5 consecutive failures, STOP dispatching agents. PAUSE execution. Alert user. Wait for manual intervention or 10-minute cooldown.
- **half-open**: After cooldown, allow ONE dispatch. If it succeeds, reset to closed. If it fails, back to open.

## Phase 3.5: TEST GENERATION (optional)

If the `test-gen` skill is available and the story type is `code`:

1. Analyze files created/modified by the implementer
2. Generate appropriate tests:
   - New functions → unit tests
   - New API endpoints → integration tests
   - New components → component/render tests
3. Follow existing test patterns from DNA
4. Write test files alongside implementation
5. Track coverage delta

Skip this phase if:
- Story already includes test stories (depends_on includes a test story)
- Story type is `test` (it IS a test story)
- Story type is `knowledge_work` (uses output contracts instead)

## Phase 4: SELF-HEAL

Update heartbeat: write current timestamp, phase name (`self_heal`), and milestone/story to `.maestro/logs/heartbeat.json`.

Run automated checks and fix failures. The check sequence depends on story type.

### Story Type Detection

Determine the story type from the story's `type` field or by analyzing the files:

| Story Type | Detection | Validation Path |
|-----------|-----------|-----------------|
| `code` / `backend` / `frontend` / `fullstack` / `infrastructure` / `test` | Default | Code quality gates (tsc, lint, tests) |
| `knowledge_work` / `content` / `marketing` / `research` / `strategy` | Layer 4 classifier | Output contract validation |
| `markdown` | All files are `.md` | Markdown structure validation |

### Code Story Validation

```bash
# 1. TypeScript compilation
npx tsc --noEmit

# 2. Linting
npm run lint

# 3. Test suite (affected tests, then full suite)
npm test
```

### Knowledge Work Validation

For non-code stories (content, marketing, research, strategy, markdown):

1. **Load output contract** from the generating skill's `output_contract` definition
2. **Run content-validator** checks:
   - Frontmatter schema validation (required fields, types)
   - Required sections present and non-empty
   - Heading hierarchy (H1 → H2 → H3, no skips)
   - Word count within bounds
   - Cross-file references resolve
3. **If SEO content**: readability score, keyword presence, meta tags
4. **Report** using same pass/fail format as code checks

```
Content validation:
  (ok) Frontmatter: all required fields present
  (ok) Sections: 5/5 required sections found
  (ok) Headings: hierarchy valid
  (ok) Word count: 1,247 (target: 800-3000)
  (x)  Cross-ref: link to research.md — file not found
```

If validation fails, dispatch fixer agent with the specific failures.

### Check Sequence (Code)

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

Update heartbeat: write current timestamp, phase name (`qa_review`), and milestone/story to `.maestro/logs/heartbeat.json`.

Dispatch an independent QA reviewer to catch issues the implementer missed.

### Review Mode Selection

For **code stories**, select review depth based on trust level:

| Trust Level | Review Mode | What Happens |
|-------------|-------------|-------------|
| Novice / Apprentice | **Multi-review** | 3 parallel reviewers (correctness, security, performance) via `multi-review` skill |
| Journeyman | **Standard** | Single QA reviewer |
| Expert | **Standard** | Single QA reviewer |
| `--careful` mode | **Multi-review** | Always 3 parallel reviewers regardless of trust |

For **knowledge work stories**, use output contract validation:
- Load the output contract from the generating skill
- Run `content-validator` checks (frontmatter, structure, word bounds, SEO)
- Report violations as QA findings

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

Update heartbeat: write current timestamp, phase name (`git_craft`), and milestone/story to `.maestro/logs/heartbeat.json`.

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

### Commit Score

After creating the commit, evaluate it using the `commit-score` skill:

- Tests included? (0-25)
- Conventions followed? (0-25)
- Message quality? (0-25)
- Clean code? (0-25)

Show the score in the checkpoint summary. Track in `.maestro/trust.yaml` under `commit_scores`.

## Phase 7: CHECKPOINT

Update heartbeat: write current timestamp, phase name (`checkpoint`), and milestone/story to `.maestro/logs/heartbeat.json`. Include `last_action: "story [story-id] complete"`.

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

**Important**: The checkpoint decision MUST use AskUserQuestion, not plain text menus:
- Question: "Story [N/M] complete: [title]. What next?"
- Header: "Checkpoint"
- Options: Continue (Recommended) / Review changes / Skip next / Abort

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

If cost tracking is enabled (`.maestro/config.yaml` or `dna.md`), log per-phase token usage:

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

## State Integrity Protocol

Every write to `.maestro/state.local.md` MUST follow this safety sequence:

### On Write
1. **Backup**: Copy current `state.local.md` to `state.local.md.bak` before any modification
2. **Write**: Update the state file with new values
3. **Checksum**: Compute SHA256 of the written content and store as `state_checksum` in the frontmatter
4. **Verify**: Re-read the file and confirm the checksum matches

### On Read
1. Read `state.local.md`
2. Extract `state_checksum` from frontmatter
3. Compute SHA256 of the file content (excluding the `state_checksum` line itself)
4. If checksums match: proceed normally
5. If checksums mismatch or file is corrupt:
   a. Log warning to `.maestro/logs/state-recovery.log`
   b. Check for `state.local.md.bak`
   c. If backup exists and is valid, restore from backup
   d. If no valid backup, PAUSE and alert user

### Checksum Computation
```bash
# Compute checksum (exclude the state_checksum line to avoid circular dependency)
grep -v '^state_checksum:' .maestro/state.local.md | sha256sum | cut -d' ' -f1
```

### Recovery Log Format
```
[2026-03-19T10:30:00Z] WARN: State file corruption detected (checksum mismatch)
[2026-03-19T10:30:00Z] INFO: Restored from state.local.md.bak
```
