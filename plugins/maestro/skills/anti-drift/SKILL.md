---
name: anti-drift
description: Post-task goal alignment verification — detects drift at story, milestone, and vision levels with auto-correction
---

# Anti-Drift Verification

Detects when agent work drifts from its original goals. Operates at three levels: story (per-implementer), milestone (per-milestone completion), and vision (every 3 milestones). All drift scores are logged to `.maestro/logs/drift.md`.

## When to Run

| Level | Trigger | Integration Point |
|-------|---------|-------------------|
| Story drift | After implementer reports `STATUS: DONE` | dev-loop Phase 4.6 (after truth-verifier, before QA) |
| Milestone drift | After all stories in a milestone complete | opus-loop Step 4 (before milestone evaluation) |
| Vision drift | Every 3 milestones completed | opus-loop between-milestone maintenance |

Never skip. Drift accumulates silently — a single undetected drift at story level can cascade through a milestone.

---

## Level 1: Story Drift (dev-loop integration)

Runs as **Phase 4.6** in the dev-loop — after truth-verifier confirms claims are accurate, before QA review dispatches.

### Inputs

- Story spec (`.maestro/stories/NN-slug.md`) — contains acceptance criteria
- Git diff of the implementer's changes (`git diff {base-commit}..HEAD` from the worktree)
- Implementer status report (passed in from Phase 3)

### Step 1: Parse Acceptance Criteria

Extract every acceptance criterion from the story spec. Criteria appear as:
- Numbered items under an `## Acceptance Criteria` or `## AC` heading
- Inline `AC1:`, `AC2:` prefixes in the spec body

For each criterion, extract:
- ID (AC1, AC2, ...)
- Description text
- Any measurable condition (file created, test passes, UI element present)

### Step 2: Evaluate Each Criterion Against the Diff

For each criterion, determine PASS or FAIL using this heuristic cascade:

1. **Test name match** — scan the diff for test names containing key words from the criterion. If a test was added and passes → PASS.
2. **File content match** — if the criterion names a specific behavior or output, grep the changed files for that behavior. Found → PASS.
3. **File creation/modification** — if the criterion requires a specific file, verify it was created or modified in the diff. Matched → PASS.
4. **Status report match** — if the implementer's status report lists this AC as PASS and truth-verifier VERIFIED it → PASS.
5. **Cannot evaluate** — if none of the above apply → mark as UNVERIFIED (not FAIL).

Only mark FAIL when there is positive evidence the criterion was missed — a file that should exist but does not, a test that should pass but fails, a required section absent from a created file.

### Step 3: Calculate Story Drift Score

```
drift_score = (failed_criteria / total_criteria) × 100
```

UNVERIFIED criteria do not count as failed — they are excluded from the calculation.

If all criteria are UNVERIFIED (no automatable checks), drift score = 0 with a LOW_CONFIDENCE flag.

### Story Drift Decision Rules

| Drift Score | Action |
|-------------|--------|
| 0–30 | Proceed to QA. Include drift report as context. |
| 31–100 | Flag for re-implementation. Inject correction context (see Correction Context). Do NOT proceed to QA. |

### Story Drift Output Block

Append to the dev-loop execution log and pass to QA as context:

```
DRIFT CHECK — STORY LEVEL
Story: [story-id]
Criteria evaluated: [N total, M failed, K unverified]
Drift score: [X] / 100
Decision: PROCEED | RE-IMPLEMENT

Failed criteria:
  - AC2: [description] — expected [X], found [Y]

Unverified criteria:
  - AC4: [description] — reason: [visual/no automatable check]
```

---

## Level 2: Milestone Drift (opus-loop integration)

Runs **before** the opus-loop milestone evaluation (Step 4), after all stories in the milestone are committed.

### Inputs

- Milestone spec (`.maestro/milestones/MN-slug.md`) — milestone goal and acceptance criteria
- Combined diff of all stories in the milestone (`git diff {milestone-base}..HEAD`)
- Story-level drift scores from the dev-loop logs
- Individual story specs (to detect contradictions between stories)

### Step 1: Re-read the Milestone Spec

Load the milestone spec. Extract:
- The milestone goal (top-level objective)
- All milestone-level acceptance criteria
- Expected file and system changes

### Step 2: Verify Combined Changes Achieve the Milestone Goal

For each milestone acceptance criterion, run the same heuristic cascade as story drift evaluation (test match → file content match → file existence → cannot evaluate).

Additionally check: does the combined set of changes produce the behavior the milestone goal describes? This is a higher-level semantic check — not just "does file X exist" but "does the system do Y."

### Step 3: Check for Cross-Story Contradictions

For each pair of stories in the milestone, compare their diffs:

- Did Story B delete or overwrite something Story A created? Flag if Story A's creation was load-bearing for its AC.
- Did Story B change a shared interface in a way that breaks Story A's expectations? Flag.
- Did Story B introduce a config or flag that Story A's test now incorrectly tests? Flag.

Mark each contradiction as a CONFLICT. Conflicts add to the drift score.

### Step 4: Calculate Milestone Drift Score

```
ac_drift = (failed_milestone_criteria / total_milestone_criteria) × 100
conflict_penalty = min(conflicts × 10, 40)   # capped at 40 points
drift_score = min(ac_drift + conflict_penalty, 100)
```

### Milestone Drift Decision Rules

| Drift Score | Action |
|-------------|--------|
| 0–30 | Proceed to milestone evaluation. Include drift report. |
| 31–100 | Generate targeted fix stories before evaluation. Inject correction context. |

### Milestone Drift Output Block

```
DRIFT CHECK — MILESTONE LEVEL
Milestone: [MN-slug]
Stories: [N completed]
Criteria evaluated: [N total, M failed, K unverified]
Conflicts detected: [N]
Drift score: [X] / 100
Decision: PROCEED | FIX_REQUIRED

Failed criteria:
  - [description] — gap: [what is missing]

Cross-story conflicts:
  - Story [A] vs Story [B]: [description of contradiction]
```

---

## Level 3: Vision Drift (opus-loop between-milestone)

Runs **every 3 milestones** during the between-milestone maintenance phase of the opus-loop.

### Inputs

- `.maestro/vision.md` — the North Star, the original project vision
- All milestone specs completed so far (`.maestro/milestones/MN-slug.md`)
- `.maestro/logs/drift.md` — accumulated drift history
- `.maestro/roadmap.md` — current planned trajectory

### Step 1: Re-read the Vision

Load `.maestro/vision.md`. Identify:
- The core North Star goal (what the project ultimately achieves)
- Key constraints (what the project must never become)
- Success criteria at the vision level

### Step 2: Assess Project Trajectory

Compare what has been built (from completed milestone specs and their diffs) against what the vision calls for:

1. **Coverage** — which vision goals have been addressed by completed milestones?
2. **Scope creep** — did any milestone or story introduce features that are not traceable to a vision goal?
3. **Feature drift** — are there recurring patterns in cross-story conflicts or story-level drift that indicate a systematic misalignment?
4. **Neglected goals** — are there vision goals that no completed or planned milestone addresses?

### Step 3: Calculate Vision Drift Score

```
coverage_gap = (vision_goals_unaddressed / total_vision_goals) × 50
scope_creep = min(untraced_features_count × 10, 30)
neglect_penalty = (neglected_critical_goals / total_critical_goals) × 20
drift_score = min(coverage_gap + scope_creep + neglect_penalty, 100)
```

### Step 4: Recommend Course Corrections

If drift_score > 30, produce concrete recommendations:

- For neglected vision goals: suggest a new milestone or story to address the gap
- For scope creep: flag specific features for removal or demotion
- For systematic drift: recommend revising the decomposition approach for future milestones

### Vision Drift Decision Rules

| Drift Score | Action |
|-------------|--------|
| 0–20 | Log and continue. No corrections needed. |
| 21–40 | Log recommendations. Inject into next milestone's decomposition context. |
| 41–100 | Trigger divergence-handler. PAUSE if `opus_mode` is not `full_auto`. |

### Vision Drift Output Block

```
DRIFT CHECK — VISION LEVEL
Milestones completed: [N]
Vision goals assessed: [N total, M covered, K neglected]
Untraced features: [N]
Drift score: [X] / 100
Decision: CONTINUE | RECOMMEND | DIVERGENCE

Neglected vision goals:
  - [goal description] — no milestone addresses this

Scope creep detected:
  - Feature "[name]" in Milestone [M] — no traceable vision goal

Recommendations:
  - [concrete action]
```

---

## Correction Context Injection

When any drift level produces drift > 40, inject a correction context block into the next agent's dispatch prompt.

```
DRIFT ALERT — [STORY | MILESTONE | VISION] LEVEL
Drift score: [X] / 100

The previous [implementer | milestone] drifted from the original goals.

Specific gaps:
  - [AC or goal] was not addressed: [evidence]
  - [AC or goal] was contradicted by: [evidence]

Course correction required:
  - [concrete instruction for what to do differently]

Original goal (re-anchor):
  [paste the relevant section of story spec or milestone goal]
```

This context is prepended to the agent prompt — not appended. It must be the first thing the agent reads.

---

## Drift Log

All drift scores are appended to `.maestro/logs/drift.md` in chronological order.

```markdown
## [timestamp] Story Drift — [story-id]

- Criteria: [N total, M failed, K unverified]
- Drift score: [X] / 100
- Decision: PROCEED | RE-IMPLEMENT
- Failed: [list]

## [timestamp] Milestone Drift — [MN-slug]

- Criteria: [N total, M failed]
- Conflicts: [N]
- Drift score: [X] / 100
- Decision: PROCEED | FIX_REQUIRED

## [timestamp] Vision Drift — After Milestone [N]

- Vision goals: [N total, M covered, K neglected]
- Untraced features: [N]
- Drift score: [X] / 100
- Decision: CONTINUE | RECOMMEND | DIVERGENCE
- Recommendations: [list]
```

### Drift Trend Analysis

When writing a vision drift entry, also compute the trend over the last 3 milestone cycles:

```
Story drift trend: [avg score M(N-2)] → [avg score M(N-1)] → [avg score MN]
Milestone drift trend: [M(N-2)] → [M(N-1)] → [MN]
```

If either trend is strictly increasing (drift getting worse each milestone), escalate to WARN even if the current score is below the action threshold.

---

## Integration Points

**dev-loop/SKILL.md** — story drift runs as Phase 4.6, between truth-verifier (Phase 4.5) and QA review (Phase 5). If drift > 30, skip QA and return the story for re-implementation with correction context injected.

**opus-loop/SKILL.md** — milestone drift runs before Step 4 (milestone evaluation). Vision drift runs every 3 milestones in the between-milestone maintenance block, after the retrospective and before the next milestone start.

**truth-verifier/SKILL.md** — anti-drift consumes the truth-verifier output. UNVERIFIED truth-verifier claims are treated as UNVERIFIED drift criteria (not FAIL). CONTRADICTED truth-verifier claims automatically produce FAIL entries for any AC they map to.

**audit-log/SKILL.md** — log a `drift_correction` decision entry whenever drift > 40, with the failed criteria as input state and the correction context as the decision.

**divergence-handler/SKILL.md** — vision drift with score > 40 triggers the divergence handler, which manages project pivots mid-flight.

**self-correct/SKILL.md** — if the same implementer agent produces story drift > 30 on 2+ consecutive stories, trigger a self-correct signal targeting that agent's system prompt patterns.
