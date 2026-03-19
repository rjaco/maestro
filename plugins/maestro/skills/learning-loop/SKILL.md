---
name: learning-loop
description: "4-phase continuous learning cycle (RETRIEVE→JUDGE→DISTILL→CONSOLIDATE) that runs between milestones. Converts signals from QA feedback, self-heal errors, context escalations, user corrections, and token efficiency into persisted lessons in .maestro/memory/memories.md, SOUL.md, and trust.yaml."
---

# Learning Loop

A 4-phase cycle that runs after each milestone completes. Converts raw signals from the completed work into durable lessons — patterns the system will apply in every future session. Inspired by the RETRIEVE→JUDGE→DISTILL→CONSOLIDATE pipeline.

## When to Run

- After a milestone completes (all stories done, committed)
- Manually when the orchestrator detects a high-density signal cluster mid-feature
- Never during active story implementation — learning runs between milestones, not inside them

## Phase 1: RETRIEVE

Gather every signal produced during the milestone. A signal is any observation that could indicate something the system should do differently.

### Signal Sources

**QA Feedback**
- Collect all QA rejection verdicts from the milestone's stories
- For each rejection: extract the pattern (what was wrong), the story type, and the model used
- Include re-submissions: a story rejected twice on the same issue is a stronger signal than one rejected once

**Self-Heal Errors**
- Collect all errors that triggered the self-heal phase
- For each: error class, number of fix attempts, final resolution, and whether the same class appeared in prior milestones
- Errors that required 3+ fix attempts are weighted higher — they indicate the system lacks an existing pattern for that failure

**Context Escalations**
- Collect all NEEDS_CONTEXT responses from implementer agents
- For each: what was missing, which story type, whether the orchestrator could resolve it or had to ask the user
- Escalations the user had to resolve are stronger signals than ones the orchestrator resolved internally

**User Corrections**
- Read `.maestro/notes.md` for entries with intent `feedback` or `redirect` written during this milestone
- Include explicit verbal corrections captured during checkpoints
- These are the highest-priority signals — a correction means the system did something the user found wrong enough to stop and fix

**Token Efficiency**
- Read token actuals from `.maestro/state.local.md` or the token ledger for the milestone
- Flag stories where actual tokens exceeded estimate by more than 50%
- Flag stories where a higher-tier model was used but the story could have been haiku (low complexity, first-pass QA)
- Flag stories where the model was insufficient (escalated or QA-failed repeatedly)

### RETRIEVE Output Format

```markdown
## RETRIEVE: Milestone [name] — [date]

### QA Feedback Signals
- [story_id] rejected: [pattern description] (1st rejection / 2nd rejection)
- [story_id] rejected: [pattern description]

### Self-Heal Signals
- [story_id] error: [error class] — [N fix attempts] — [resolved / unresolved]

### Context Escalation Signals
- [story_id] NEEDS_CONTEXT: [what was missing] — [orchestrator resolved / user resolved]

### User Correction Signals
- [date] correction: [description] — [from notes.md / from checkpoint]

### Token Efficiency Signals
- [story_id] over-budget: [actual]t vs [estimate]t ([pct]% over)
- [story_id] model mismatch: used [model], complexity was [haiku/sonnet]-range
```

## Phase 2: JUDGE

Evaluate each signal. Not all signals are worth learning from — some are noise, one-offs, or already covered by existing rules.

### Confidence Scoring

Score each signal on 3 factors:

| Factor | Score | Criteria |
|--------|-------|----------|
| **Frequency** | 3 | Signal appeared 3+ times in this milestone |
| | 2 | Signal appeared 2 times |
| | 1 | Signal appeared once |
| **Cross-story** | 1 | Signal appeared in 2+ different story types |
| | 0 | Signal appeared in only one story type |
| **Prior occurrence** | 1 | Same signal appeared in a prior milestone |
| | 0 | First time seen |

**Total confidence: 0–5.**

Threshold: signals with confidence >= 3 proceed to DISTILL. Signals below 3 are logged but not acted on.

### Novelty Check

Before scoring, check `.maestro/memory/memories.md` for existing lessons that cover the same pattern. If an exact match exists:

- Increment the existing lesson's occurrence count
- Do not generate a duplicate lesson
- If the existing lesson has `status: trial`, the new occurrence elevates it to `confirmed`

### Relevance Check

Determine scope before DISTILL:

| Scope | Criteria | Target |
|-------|----------|--------|
| **Universal** | Applies to any story type in any project | `.maestro/SOUL.md` learned patterns |
| **Project-wide** | Applies to all stories in this project | `.maestro/memory/memories.md` (lesson tier) |
| **Story-type** | Applies only to stories of a specific type (e.g., API endpoints) | `.maestro/memory/memories.md` (scoped) |
| **One-off** | Unique to one story's circumstances | Log only — no lesson generated |

One-off signals are logged to `.maestro/logs/learning-loop.md` as `noise` but do not proceed to DISTILL.

### JUDGE Output Format

```markdown
## JUDGE: Milestone [name] — [date]

| Signal | Frequency | Cross-story | Prior | Confidence | Verdict |
|--------|-----------|-------------|-------|------------|---------|
| QA: missing null check | 3 | yes | yes | 5 | DISTILL |
| Self-heal: barrel export error | 2 | no | no | 2 | log only |
| Token: over-budget API stories | 2 | yes | no | 3 | DISTILL |
| User: always named exports | 1 | yes | no | 2 | log only (user correction — override: DISTILL) |

Note: User corrections bypass the confidence threshold. All user corrections proceed to DISTILL at confidence 1.0.
```

User corrections always bypass the threshold. The user explicitly took time to correct the system — that is sufficient evidence regardless of frequency.

## Phase 3: DISTILL

Convert each high-confidence signal into a concrete, actionable rule.

### Rule Format

```markdown
### Rule: [short title]

- **Pattern**: [what the system did wrong or suboptimally]
- **Rule**: [imperative: "Always X", "Never Y", "When Z, do W"]
- **Source**: [qa_rejection | self_heal | context_escalation | user_correction | token_efficiency]
- **Confidence**: [0-5 or 1.0 for user corrections]
- **Scope**: [universal | project-wide | story-type: X]
- **Status**: proposed
```

### Signal-to-Rule Conversion Patterns

**QA pattern → quality rule**

The pattern reveals what the QA reviewer consistently flags. Convert to a pre-implementation check.

```
Signal: QA rejected 3 stories for missing null checks on optional relations
Rule: "Before reporting DONE, verify all optional relation accesses are guarded with optional chaining"
Target: skills/dev-loop/implementer-prompt.md (pre-DONE checklist)
```

**Error pattern → setup rule**

The error reveals a configuration step the implementer consistently omits.

```
Signal: Self-heal ran 3x for "cannot find module" after barrel export edits
Rule: "When editing index.ts barrel exports, run tsc --noEmit before marking the story complete"
Target: .maestro/dna.md (known error patterns)
```

**Token efficiency pattern → model routing rule**

The overspend reveals a mismatch between task type and assigned model.

```
Signal: API endpoint stories using sonnet consistently ran 60% over token budget
Rule: "Stories of type 'API endpoint CRUD' score at most 2 on logic complexity — floor at sonnet but flag for haiku review after 3 consecutive successes"
Target: trust.yaml (model_stats adjustment) + model-router notes
```

**User correction → convention rule**

User corrections are encoded verbatim as project conventions.

```
Signal: User correction "always use named exports, never default"
Rule: "Always use named exports. Never use default exports."
Target: CLAUDE.md (project conventions)
```

### DISTILL Output Format

```markdown
## DISTILL: Milestone [name] — [date]

### Rule: Guard optional relations before access
- **Pattern**: Implementer accessed nested relations without null checks; QA rejected 3 times
- **Rule**: Always use optional chaining when accessing nested relations (e.g., `user?.profile?.avatar`)
- **Source**: qa_rejection (3 occurrences, cross-story)
- **Confidence**: 5
- **Scope**: project-wide
- **Status**: proposed

### Rule: Run tsc after barrel exports
- **Pattern**: Adding to index.ts without type-checking caused self-heal loops
- **Rule**: When editing any barrel export file (index.ts), run `tsc --noEmit` before marking DONE
- **Source**: self_heal (2 occurrences)
- **Confidence**: 3
- **Scope**: project-wide
- **Status**: proposed
```

## Phase 4: CONSOLIDATE

Persist approved rules to long-term memory and update downstream config.

### Auto-Apply vs Propose

| Confidence | Action |
|------------|--------|
| 1.0 (user correction) | Auto-apply immediately. No approval needed. |
| 4–5 | Auto-apply. Log as `permanent`. Notify user at next checkpoint. |
| 3 | Propose to user before applying. |
| < 3 (reached DISTILL via override) | Propose to user before applying. |

### Write Targets

**`.maestro/memory/memories.md`** — Lesson-tier entries for project-scoped and story-type-scoped rules.

```markdown
## Lessons

### [date] [confidence: 5] [scope: project-wide]
**Pattern**: Missing null guard on optional relations
**Lesson**: Always use optional chaining for nested relation access (`user?.profile?.avatar`)
**Source**: qa_rejection x3 (milestone: auth-feature)
**Status**: permanent
**Occurrences**: 3
```

**`.maestro/SOUL.md` learned patterns section** — Universal rules only. Edit the `## Learned Patterns` section. If no such section exists in `.maestro/SOUL.md`, append it.

```markdown
## Learned Patterns

- [date] When editing barrel exports, run tsc --noEmit before marking DONE (confidence: 4, source: self_heal)
```

**`trust.yaml`** — Performance adjustments from token efficiency signals.

```yaml
model_stats:
  haiku:
    qa_first_pass_rate: 0.82
    stories_attempted: 11
    avg_token_efficiency: 0.94    # actual/estimate ratio; < 1.0 = under budget
  sonnet:
    qa_first_pass_rate: 0.76
    stories_attempted: 21
    avg_token_efficiency: 1.31    # over budget — learning loop flagged this
  learning_adjustments:
    - date: 2026-03-18
      signal: "API endpoint stories 60% over budget on sonnet"
      action: "Added complexity floor note to model-router for story type: api-endpoint-crud"
```

**CLAUDE.md** — Project conventions from user corrections only. Append under the relevant section. Do not create new sections without user approval.

### Stale Rule Pruning

On each CONSOLIDATE phase, scan `.maestro/memory/memories.md` for stale rules:

A rule is stale when:
- `status: trial` and it was written more than 10 milestones ago with no new occurrences
- `status: permanent` and the pattern it addresses has not appeared in the last 15 milestones

For stale rules: do not delete automatically. Mark `status: review` and present to the user at the next checkpoint:

```
Learning Loop: 1 stale rule flagged for review
Rule:   "Always run tsc after barrel exports" (permanent, last seen 15 milestones ago)
Action: retain / retire
```

If the user retires it, remove it from `memories.md` and log the removal to `.maestro/logs/learning-loop.md`.

### CONSOLIDATE Output Format

```
Learning Loop: Milestone [name]
Signals retrieved:  [N]
Signals judged:     [N proceed to DISTILL] / [N logged only]
Rules distilled:    [N]
Rules auto-applied: [N] (confidence >= 4 or user correction)
Rules proposed:     [N] (confidence 3)
Stale rules flagged: [N]

Applied:
  (permanent) Guard optional relations — written to .maestro/memory/memories.md
  (permanent) Run tsc after barrel exports — written to .maestro/SOUL.md learned patterns
Proposed:
  (pending) API endpoint model hint — update trust.yaml [apply? yes / no]
```

## Log Format

All learning-loop runs are appended to `.maestro/logs/learning-loop.md`:

```markdown
## Learning Loop Run — [date] — Milestone: [name]

**Phases completed**: RETRIEVE → JUDGE → DISTILL → CONSOLIDATE
**Duration**: [elapsed]

**Signal summary**: [N] retrieved, [N] judged high-confidence, [N] distilled, [N] consolidated
**Stale rules reviewed**: [N]

**Rules written this run**:
- [rule title] → [target file]
- [rule title] → [target file]

**Rules proposed (pending user approval)**:
- [rule title] → [confidence] → [target file]

**Signals logged as noise**: [N]
```

## Integration Points

| Skill | Integration |
|-------|-------------|
| **dev-loop** | dev-loop triggers learning-loop after each milestone completes (all stories done, committed). Passes the milestone name and story list as context. |
| **self-correct** | self-correct operates within a single session; learning-loop persists cross-session. User corrections captured by self-correct (confidence >= 0.7) are appended to `.maestro/SOUL.md` `## Learned Traits`; learning-loop RETRIEVE reads that section at the start of each run and ingests any entries dated within the current milestone as `user_correction` signals so they survive across milestone boundaries. |
| **retrospective** | retrospective runs at the feature level; learning-loop runs at the milestone level. retrospective produces improvement candidates; learning-loop produces lessons. Both write to `memories.md` — use distinct headings (`## Improvements` vs `## Lessons`) to avoid collisions. |
| **token-ledger** | learning-loop reads per-story token actuals from token-ledger to produce token efficiency signals in RETRIEVE. |
| **trust.yaml** | CONSOLIDATE writes `learning_adjustments` and updates `model_stats` averages. model-router reads `model_stats` to adjust haiku tier boundary. |
| **soul** | Universal rules from DISTILL are written to `.maestro/SOUL.md` `## Learned Patterns`. `.maestro/SOUL.md` governs base agent behavior — universal rules here propagate to all future sessions automatically. |

### Error Pattern Signals

During the RETRIEVE phase, also scan:
- `.maestro/patterns/learned-errors.yaml` for auto-generated patterns
- `.maestro/logs/pattern-learning.log` for recent pattern additions

During CONSOLIDATE:
- Review auto-generated patterns with confidence < 0.5
- Either promote (boost confidence) or deprecate based on success rate
- Merge similar patterns (same error type, similar fix strategy)

### Data Contract with self-correct

- **Output location**: `.maestro/SOUL.md` — `## Learned Traits` section
- **Format**: Markdown list entries
- **Written by**: `self-correct` (after each conversation turn that contains a correction or confirmation signal)
- **Read by**: `learning-loop` RETRIEVE phase (at the start of each milestone run)
- **Fields**:
  - Correction entry: `- [YYYY-MM-DD] {trait_description} (source: "{raw_signal}")`
  - Confirmation entry: `- [YYYY-MM-DD] CONFIRMED: {trait_description}`
  - Confidence: inferred from signal type — explicit "never/always" → 1.0, direct correction → 0.9, confirmation → 0.85
- **Selection rule**: learning-loop ingests only entries whose date falls within the current milestone's date range. Entries from prior milestones are considered already processed.
- **Deduplication**: if a `## Learned Traits` entry matches an existing lesson in `.maestro/memory/memories.md` (by subject), learning-loop increments the lesson's occurrence count instead of creating a duplicate rule.
