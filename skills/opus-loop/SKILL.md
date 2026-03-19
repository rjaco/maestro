---
name: opus-loop
description: "Magnum Opus orchestration loop. Drives milestone-by-milestone execution with research, decomposition, implementation, evaluation, and self-improvement."
---

# Opus Loop

The mega-loop that drives Magnum Opus mode. Executes milestones sequentially, each containing multiple stories, with quality gates, auto-fix cycles, retrospectives, and North Star anchoring between milestones.

## EXECUTE, DON'T PLAN

**This skill EXECUTES. It does NOT produce plan documents.**

After decomposing a milestone into stories, the orchestrator MUST immediately
dispatch implementer agents via the Agent tool. Writing a plan file and
stopping is a violation of this skill's purpose.

The flow is: decompose → dispatch Agent (isolation: "worktree") → validate → QA → commit → next story.
There is NO step where you save a plan and wait. The loop is continuous.

If you find yourself writing a `.maestro/plans/*.md` file instead of
calling the Agent tool, STOP and re-read this section.

## Overview

```
For each milestone in roadmap:
  1. MILESTONE START   — Load vision, research, forecast cost
  2. DECOMPOSE         — Break into 2-8 stories with dependency graph
  3. DEV LOOP          — Execute stories via dev-loop (yolo within milestone)
  4. MILESTONE EVAL    — Tests, tsc, Lighthouse, acceptance criteria, Opus gate
  5. AUTO-FIX          — Generate fix stories if eval fails (max 3 cycles)
  6. CHECKPOINT        — Update state, roadmap, ledger. Pause or continue.

Between milestones:
  - North Star re-read (prevent drift)
  - Landscape check (process user notes)
  - Retrospective (learn from last milestone)
  - State persistence
```

## Milestone Lifecycle

### 1. MILESTONE START

Before beginning a milestone:

1. Read `.maestro/vision.md` — the North Star. Re-inject the original vision to prevent drift. Long autonomous runs accumulate context noise. The vision anchors every decision.
2. Read `.maestro/research/` files relevant to this milestone's domain (mapped via `research_inputs` in the milestone spec).
3. Read the milestone spec from `.maestro/milestones/MN-slug.md`.
4. Forecast cost for this milestone:
   - Count estimated stories from milestone spec
   - Apply per-story cost estimates from token-ledger historical data
   - If no history, use defaults: simple ~$0.30, medium ~$0.80, complex ~$2.00
5. Display milestone header:
   ```
   ========================================
   Milestone [N]/[total]: [name]
   ========================================
   Scope: [scope summary]
   Estimated stories: [N]
   Estimated cost: ~$[N]
   Research inputs: [list]
   ========================================
   ```
6. Update state: `current_milestone: N`, `phase: milestone_start`

### 2. DECOMPOSE

Break the milestone into implementable stories using the decompose skill.

- Input: milestone spec (scope, acceptance criteria) + project DNA + relevant research
- Output: `.maestro/stories/MN-NN-slug.md` (namespaced by milestone)
- Stories are numbered within the milestone context: M1-01, M1-02, etc.
- Dependency graph is scoped to this milestone
- Present story list to user only if `opus_mode` is `milestone_pause`; otherwise auto-approve

Update state: `total_stories: [count]`, `current_story: 0`, `phase: decompose`

### 3. DEV LOOP

Execute stories via the dev-loop skill. Within a milestone, stories run in yolo mode regardless of the Opus mode — checkpoints happen at the milestone boundary, not the story boundary.

For each story in dependency order:
1. Validate prerequisites
2. Delegate with right-sized context (include milestone scope + vision anchor)
3. Implement via background agent
4. After dispatching each agent, write a heartbeat to `.maestro/logs/heartbeat.json` with the current timestamp, phase, milestone, story, and action. This enables the daemon to detect stalls.
5. Self-heal (tsc, lint, tests — up to 3 fix attempts)
6. QA review (up to 5 iterations)
7. Git craft (commit)
8. Update state: `current_story: N`

Track per-story metrics for the milestone retrospective:
- Tokens used
- QA iterations needed
- Self-heal cycles
- Time elapsed

If a story fails all QA iterations or self-heal cycles, increment `consecutive_failures`. If consecutive_failures reaches `max_consecutive_failures` (5), trigger a safety valve PAUSE.

### 4. MILESTONE EVAL

After all stories in the milestone are complete, run a comprehensive evaluation.

Invoke the milestone-evaluator skill:

1. **Test suite**: Run the full test suite, not just story-specific tests. Catch integration issues.
2. **Type check**: `npx tsc --noEmit` — must be clean (ignore pre-existing errors documented in DNA).
3. **Lighthouse audit** (if milestone has UI components): Run Lighthouse on affected pages. Thresholds: Performance > 80, Accessibility > 90, Best Practices > 85.
4. **Acceptance criteria**: Check each criterion from the milestone spec against the implementation. Evidence-based: point to specific code, test output, or behavior that demonstrates the criterion is met.
5. **Opus quality gate**: Dispatch an Opus-model reviewer to examine the combined diff of all stories in this milestone. This catches cross-story integration issues that per-story QA misses.

Output: MILESTONE_PASSED or MILESTONE_FAILED with specific issues.

### 5. AUTO-FIX

If the milestone evaluation fails:

1. Parse the failure report into discrete, fixable issues.
2. Generate 1-3 targeted fix stories, each with:
   - Clear scope (one issue per story)
   - Acceptance criterion: the specific check that failed
   - Files to modify
3. Execute fix stories via dev-loop (yolo mode).
4. Re-run milestone evaluation.
5. Increment `fix_cycle`. If fix_cycle reaches `max_fix_cycles` (3): PAUSE.

```
Milestone [N] failed evaluation after [fix_cycle] fix cycles.

Unresolved issues:
  1. [issue description]
  2. [issue description]

Options:
  [1] I will fix these manually, then resume
  [2] Skip this milestone and continue
  [3] Abort the Opus session
```

### 6. CHECKPOINT

After a milestone passes evaluation:

1. Update `.maestro/state.local.md`:
   - `milestones.MN: completed`
   - `current_milestone: N+1`
   - `fix_cycle: 0`
   - `consecutive_failures: 0`
   - Token spend for this milestone
2. Update `.maestro/roadmap.md` with completion timestamp and actual cost.
3. Update `.maestro/token-ledger.md` with milestone summary row.
4. Reset story counter for the next milestone.

Checkpoint behavior depends on `opus_mode`:

| Mode | Behavior |
|------|----------|
| `full_auto` | Log one-line summary, continue immediately |
| `milestone_pause` | Show milestone summary, wait for GO / PAUSE / ABORT |
| `until_pause` | Continue until user says PAUSE |
| `budget_cap` | Check token_budget, continue if under budget |
| `time_cap` | Check time_budget_hours, continue if under limit |

Milestone summary (shown on pause):
```
Milestone [N]/[total] complete: [name]

  Stories: [completed]/[total] ([skipped] skipped)
  QA first-pass rate: [N]%
  Fix cycles: [N]
  Tokens: ~[N]K (~$[cost])
  Time: [N]h [N]m
  Cumulative: $[total_cost] / $[budget or "no budget"]

  Next: Milestone [N+1] — [name]
  Continue? [GO/PAUSE/ABORT/SKIP]
```

**Important**: Milestone checkpoint MUST use AskUserQuestion:
- Question: "Milestone [N/M] complete: [title]"
- Header: "Milestone"
- Options: Continue (Recommended) / Review diff / Pause / Abort

## Between Milestones

Critical maintenance tasks between milestones:

### North Star Re-read

Re-read `.maestro/vision.md`. Compare the current trajectory against the original vision. If the project has drifted (features added that do not serve the vision, or core requirements neglected), log a warning and adjust the next milestone's priorities.

### Process User Notes

Read `.maestro/notes.md`. For each note posted during the last milestone:
- **Context/information**: Incorporate into the next milestone's decomposition context
- **Redirect/reprioritize**: Invoke divergence-handler if the note fundamentally changes direction
- **Feedback**: Log to retrospective, adjust approach
- **Complement**: Acknowledge in the milestone summary

Clear processed notes (move to `.maestro/archive/notes-MN.md`).

### Retrospective + Self-Improvement

Run a mini-retrospective on the completed milestone:
- What went well (high QA first-pass rate, under budget)
- What went poorly (many fix cycles, QA rejections, self-heal failures)
- Lessons for the next milestone (adjust context tiers, model selections, story granularity)

**Self-improvement actions** (applied immediately for the next milestone):
1. If QA first-pass rate < 60%: escalate model for next milestone (sonnet → opus)
2. If self-heal cycles > 2 average: add more context (bump default tier T3 → T2)
3. If a skill was missing: invoke skill-factory to auto-generate it
4. If a pattern was repeated 3+ times: save to semantic memory
5. If context was insufficient: adjust live-docs fetch list

Log to `.maestro/logs/` via build-log skill. Save lessons to `.maestro/memory/semantic.md`.

### State Persistence

Write all state to disk. If the session is interrupted (crash, network loss, user closes terminal), the next `/maestro opus --resume` will pick up from the last checkpoint.

## Continuous Loop Mode

When `opus_mode` is `full_auto` or `until_pause`, the loop runs continuously without stopping:

```
while milestones remain AND no safety valve triggered:
    1. Start milestone
    2. Decompose into stories
    3. For each story:
        a. Dispatch implementer in worktree (isolation: "worktree")
        b. Wait for completion
        c. Run validation (code: tsc/lint/test, knowledge: output contracts)
        d. QA review
        e. Git craft (merge worktree, commit)
    4. Evaluate milestone
    5. Auto-fix if needed (up to 3 cycles)
    6. Run retrospective + self-improvement
    7. Apply lessons to next milestone
    8. Continue to next milestone
```

### Self-Improvement Loop

In continuous mode, Maestro actively improves itself between milestones:

```
After each milestone:
    1. Analyze: what failed, what was slow, what was wasteful
    2. Adjust: model selection, context tiers, validation rules
    3. Generate: new skills if recurring patterns detected
    4. Apply: changes take effect immediately for next milestone
    5. Log: track improvement trajectory in .maestro/logs/
```

This means milestone N+1 benefits from everything learned in milestone N. Over a 10-milestone Opus session, the orchestrator becomes significantly more efficient and accurate.

### Research-Improvement Loop

For research-heavy Opus sessions (competitive analysis, market research, content strategy):

```
while improvement criteria not met:
    1. Research: dispatch parallel research agents
    2. Synthesize: combine findings into actionable brief
    3. Evaluate: does the synthesis meet the acceptance criteria?
    4. If not: identify gaps, formulate new research queries
    5. Research again with refined queries
    6. Re-synthesize and re-evaluate
    7. Loop until criteria met or max iterations (5) reached
```

This enables deep research that refines itself — each round uses findings from the previous round to ask better questions.

### Knowledge Work Continuous Loop

For non-code Opus sessions (writing, marketing, strategy):

```
while content quality < threshold:
    1. Generate: create content/strategy/copy
    2. Validate: run output contract checks
    3. Review: editorial QA (readability, SEO, tone)
    4. If rejected: send feedback, regenerate
    5. If approved: commit and continue
    6. Between pieces: analyze patterns, improve templates
```

Validation uses content-validator and output-contracts instead of tests. Worktrees isolate each piece of content until it passes review.

## Safety Valves

| Valve | Threshold | Action |
|-------|-----------|--------|
| Token budget | `token_spend >= token_budget` | PAUSE, show spend, ask to extend |
| Time budget | Elapsed >= `time_budget_hours` | PAUSE, show elapsed, ask to extend |
| Consecutive failures | `consecutive_failures >= 5` | PAUSE, show failure pattern |
| Fix cycles | `fix_cycle >= 3` per milestone | PAUSE, show unresolved issues |
| Divergence | User fundamentally redirects vision | Invoke divergence-handler |
| Disk space | Worktree creation fails | PAUSE, suggest cleanup |

When any valve triggers, save state immediately before displaying the pause message. The session must be resumable regardless of what happens after the pause.

## Sub-Files

| File | Purpose |
|------|---------|
| `deep-interview.md` | 10-dimension adaptive vision interview |
| `mega-research.md` | 8-dimension parallel research sprint |
| `roadmap-generator.md` | Milestone generation from vision + research |
| `milestone-evaluator.md` | Milestone acceptance criteria evaluation |
| `conversation-channel.md` | Live message classification and routing |
| `divergence-handler.md` | Project pivot handling mid-flight |

## State Schema (Opus Fields)

These fields are added to `.maestro/state.local.md` when `layer: opus`:

```yaml
opus_mode: milestone_pause    # full_auto | milestone_pause | until_pause | budget_cap | time_cap
current_milestone: 1
total_milestones: 5
milestones:
  M1: completed
  M2: in_progress
  M3: pending
  M4: pending
  M5: pending
fix_cycle: 0
max_fix_cycles: 3
token_budget: 0               # 0 = unlimited
time_budget_hours: 0           # 0 = unlimited
consecutive_failures: 0
max_consecutive_failures: 5
```
