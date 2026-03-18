---
name: retrospective
description: "Self-improvement after feature completion. Detects friction, proposes improvements, updates skills and journal."
---

# Retrospective

Analyzes completed features and milestones to detect friction patterns, propose improvements, and update Maestro's own behavior. The goal is continuous self-improvement — each feature built should make the next one smoother.

## When to Run

- After a feature completes (all stories done, committed)
- After a milestone completes in Opus mode
- Manually via the orchestrator when the user requests a review

## Friction Signal Detection

Scan the session history for 6 types of friction signals:

### 1. COMMAND_FAILURE

A bash command failed and required manual intervention or retry.

**Detection:** Self-heal phase ran more than once for the same error pattern. Fix agent was dispatched.
**Signal strength:** High if the same command fails across multiple stories.
**Improvement target:** Project DNA commands section, self-heal error patterns.

### 2. USER_CORRECTION

The user corrected the orchestrator's behavior, approach, or output.

**Detection:** Notes in `.maestro/notes.md` with intent `feedback` or `redirect` that led to story re-implementation or approach change.
**Signal strength:** High if the correction addresses a pattern (not a one-off).
**Improvement target:** Implementer prompt, decompose conventions, QA checklist.

### 3. SKILL_SUPPLEMENT

The orchestrator had to add context or instructions not covered by existing skills.

**Detection:** Context tier escalation from T3 to T2 or T1. NEEDS_CONTEXT responses from implementer agents.
**Signal strength:** Medium. Could indicate missing patterns in DNA or incomplete story specs.
**Improvement target:** Decompose story template, context engine tiers, project DNA patterns.

### 4. VERSION_ISSUE

A dependency version, API change, or framework update caused unexpected behavior.

**Detection:** Errors referencing deprecated APIs, version mismatches, or import changes.
**Signal strength:** High for production-impacting issues.
**Improvement target:** Project DNA dependencies section, self-heal known-error patterns.

### 5. REPETITION

The same type of fix or pattern was applied across multiple stories.

**Detection:** Similar git diffs across fix commits. Same QA feedback given to different stories.
**Signal strength:** High. Indicates a missing convention or pattern.
**Improvement target:** Implementer prompt conventions, project DNA patterns, decompose defaults.

### 6. TONE_ESCALATION

The user's messages became shorter, more direct, or expressed frustration.

**Detection:** Compare message length and tone across the session. Short responses after long ones, exclamation marks, words like "just", "already told you", "wrong".
**Signal strength:** Medium. Subjective but important.
**Improvement target:** Checkpoint verbosity, question frequency, autonomy level.

## Improvement Candidate Generation

For each detected friction signal, generate an improvement candidate:

```markdown
### Improvement: [short title]

**Signal:** [SIGNAL_TYPE] detected in story [N]
**Confidence:** [0-100] (how confident are we this is a real pattern, not noise)
**Evidence:** [specific examples from the session]
**Proposed change:**
  - Target: [which file/config to update]
  - Current behavior: [what happens now]
  - Proposed behavior: [what should happen instead]
**Risk:** [what could go wrong if we apply this change]
```

Only present candidates with confidence >= 70.

## Meta-Rules for Writing Improvements

When proposing changes to Maestro's own behavior:

1. **Never reduce safety.** Do not propose removing QA gates, reducing self-heal attempts, or skipping checks.
2. **Never increase verbosity.** If anything, improvements should make output more concise.
3. **Prefer convention over configuration.** Add a pattern to the implementer prompt rather than adding a new config option.
4. **One change at a time.** Each improvement candidate is atomic. Do not bundle multiple changes.
5. **Reversible.** Every change must be easy to undo. Document what was changed and why.

## Approval Flow

Present all improvement candidates to the user:

```
Retrospective: [feature/milestone name]

Friction signals detected: [N]

Improvements proposed:

  1. [title] (confidence: [N]%)
     [one-line summary of what changes]

  2. [title] (confidence: [N]%)
     [one-line summary of what changes]

Apply which improvements? [all / 1,2 / none]
```

Never apply improvements silently. The user must approve each change.

## Update Targets

Approved improvements are applied to these files:

| Target | What Gets Updated |
|--------|-------------------|
| `skills/dev-loop/implementer-prompt.md` | New conventions, patterns, or rules for the implementer |
| `skills/dev-loop/qa-reviewer-prompt.md` | New items for the QA checklist |
| `skills/dev-loop/SKILL.md` | Changes to the dev-loop behavior (context tiers, phase logic) |
| `.maestro/dna.md` | New patterns, commands, or known issues |
| `.maestro/trust.yaml` | Updated metrics and trust level |
| `.maestro/logs/` | Retrospective findings logged via build-log |

## Trust Level Updates

After each retrospective, recalculate the trust level:

```
total_stories += stories_in_feature
qa_first_pass_rate = (total_first_pass / total_stories) * 100

Trust levels:
  novice:      < 5 total stories
  apprentice:  5-15 stories, >= 60% QA first-pass
  journeyman:  15-30 stories, >= 75% QA first-pass
  expert:      30+ stories, >= 85% QA first-pass
```

Trust level influences default autonomy: expert projects get yolo as the suggested default, novice projects get careful.

## Self-Improvement Analysis (OpenClaw-inspired)

Beyond friction detection, analyze the session for systemic improvement opportunities:

### Skill Usefulness Analysis

After each feature, evaluate which skills contributed and which were idle:

1. **Used skills**: Which skills were invoked? How many tokens did each consume?
2. **Missing skills**: Were there tasks that needed manual intervention because no skill handled them?
3. **Underperforming skills**: Did any skill's output get discarded or heavily modified by the user?
4. **Overkill skills**: Were expensive skills (Opus model) used for simple tasks?

Log findings:
```markdown
Skill usefulness:
  (ok) dev-loop       used, effective (5 stories, 0 manual overrides)
  (ok) decompose      used, effective (generated accurate stories)
  (!)  context-engine used, but context was too lean for story 3
  (x)  research       not used (feature didn't need research)
  (!)  missing        no skill for database migration — manual work
```

### Agent Performance Tracking

Track per-agent metrics across sessions:

```yaml
# Added to .maestro/trust.yaml
agent_performance:
  implementer:
    stories_attempted: 5
    done_first_try: 3
    needs_context: 1
    blocked: 0
    avg_tokens: 28500
  qa_reviewer:
    reviews_done: 5
    approved_first_try: 4
    false_rejections: 0
  fixer:
    fixes_attempted: 3
    fixed_first_try: 2
    escalated: 1
```

### Auto-Generate Improvement Proposals

Based on the analysis, propose concrete improvements:

1. **New skill needed**: "Create a `maestro-db-migration` skill — 2 stories needed manual DB work"
   → Trigger skill-factory auto-generation
2. **Model adjustment**: "Execution model underperforming — suggest upgrading to Opus for this project"
   → Suggest via AskUserQuestion in next session
3. **Context tuning**: "Context engine delivered too little context for backend stories — lower threshold"
   → Update context-engine config
4. **Quality rule**: "QA found the same issue 3 times — add to QA checklist"
   → Update qa-reviewer-prompt.md

### Lessons Learned Accumulation

Save approved improvements to memory:

```
# In .maestro/memory/semantic.md
- [date] Learned: backend stories need auth context injected (story 3 needed NEEDS_CONTEXT retry)
- [date] Learned: test stories should depend on all implementation stories (story 5 ran before 3 finished)
- [date] Learned: this project needs DB migration skill (2 stories required manual work)
```

### Integration with Brain

If brain integration is configured:
- Save retrospective to knowledge base (category: retrospective)
- Search past retrospectives before generating new proposals
- Avoid proposing improvements already tried and rejected

## Meta-Rules

Rules about how to write, score, and manage rules themselves. This section creates a recursive self-improvement loop: the retrospective evaluates not just the project, but the quality of its own outputs.

### Rule Quality Scoring

Every improvement proposal generated by the retrospective must be scored on 4 dimensions before being presented to the user.

**Dimensions:**

| Dimension | 0 | 1 | 2 | 3 |
|-----------|---|---|---|---|
| **Specificity** | Vague direction ("write better tests") | General area identified ("improve test setup") | Specific file and section identified | Exact change to a specific file with line-level precision |
| **Evidence** | Speculation, no friction signals | One friction signal supports it | Two friction signals support it | Three or more distinct incidents support it |
| **Scope** | One-off, specific to a single story | Affects this project's remaining stories | Affects all stories in projects of this type | Affects all future sessions universally |
| **Reversibility** | Hard to reverse, touches shared config or permanent state | Reversible with significant effort | Reversible with a single file edit | Trivially reversible (a line addition, a config toggle) |

**Total score: 0-12.**

Score each proposal and include the breakdown:

```
Proposal: [title]
  Specificity:    [0-3] — [one-line reason]
  Evidence:       [0-3] — [one-line reason]
  Scope:          [0-3] — [one-line reason]
  Reversibility:  [0-3] — [one-line reason]
  Total:          [sum]/12
```

**Implementation threshold:** Only implement proposals scoring 8 or higher (adjusted by learning rate — see below).

### Rule Lifecycle

Each rule moves through defined lifecycle stages. Track stage in `.maestro/rules.md`.

**Stages:**

1. **PROPOSED** — Generated by this retrospective. Score >= threshold. Awaiting user approval.
2. **TRIAL** — User approved. Applied for the next 3 sessions. Track friction signals to measure effect.
3. **CONFIRMED** — Trial complete. Friction in the targeted area decreased. Rule is working.
4. **RETIRED** — Trial complete. Friction did not decrease, or new friction appeared. Rule removed.
5. **CORE** — Confirmed in 5 or more sessions. Becomes a permanent convention — written into the relevant skill or prompt file.

**Lifecycle format in `.maestro/rules.md`:**

```markdown
### Rule: [title]

- **Status:** TRIAL
- **Stage entered:** [date]
- **Sessions on this stage:** 2 / 3
- **Score at proposal:** 9/12
- **Target:** skills/dev-loop/implementer-prompt.md
- **Change:** [what was added or modified]
- **Friction before:** [signal type and frequency]
- **Friction after:** [update each session]
- **Outcome:** [pending / improved / worsened]
```

Never silently advance a rule's lifecycle. The user must see the outcome summary before a rule moves from TRIAL to CONFIRMED or RETIRED.

### Anti-Patterns in Rule Generation

Detect and reject proposals that match these patterns before scoring:

**Over-specificity** — The rule targets a location so narrow it cannot generalize.
Example: "Always add a null check on line 42 of user.ts"
Detection: Rule references a specific line number, variable name, or single-file path with no abstraction.
Action: Reject. Ask "what is the general pattern this addresses?"

**Under-specificity** — The rule is too vague to act on.
Example: "Write better code", "Be more careful"
Detection: No target file, no concrete behavior change, no measurable outcome.
Action: Reject. Demand a specific target and behavior before scoring.

**Solution-before-problem** — A fix is proposed without an identified friction signal.
Detection: The proposal has no corresponding friction signal in the session.
Action: Reject. A rule without evidence is speculation, not a retrospective finding.

**Cargo-culting** — A pattern that worked in one project is copied to another without understanding why.
Detection: Proposal references "this worked before" or "I've seen this pattern" without project-specific evidence.
Action: Flag for review. Score Evidence dimension as 0 regardless of prior success.

**Rule proliferation** — More than 3 new rule proposals in a single retrospective.
Detection: Count proposals before presenting. If count > 3, stop.
Action: Rank all candidates by score. Present only the top 3. Log the rest as "deferred — rule proliferation guard triggered."

### Learning Rate Control

The threshold for implementing proposals adapts to project maturity. A new project benefits from faster learning; an established project needs stronger evidence before changing conventions.

**Determine project maturity:**

```
session_count     = total sessions logged in .maestro/logs/
existing_rules    = count of CONFIRMED or CORE rules in .maestro/rules.md
```

**Learning rate:**

| Condition | Rate | Implementation Threshold |
|-----------|------|--------------------------|
| session_count < 5 OR existing_rules < 3 | High | Score >= 6 |
| session_count 5-15 AND existing_rules 3-10 | Medium | Score >= 8 |
| session_count > 15 OR existing_rules > 10 | Low | Score >= 10 |

At high learning rate, also allow up to 5 proposals per retrospective (overrides Rule Proliferation guard).

Include the learning rate in the retrospective output:

```
Learning rate: HIGH (4 sessions, 2 confirmed rules)
Threshold:     6/12
```

### Rule Conflict Resolution

When a new proposal contradicts an existing CONFIRMED or CORE rule, do not silently override. Evaluate both rules and resolve explicitly.

**Conflict detection:** A conflict exists when two rules prescribe opposite behavior for the same target (same file, same phase, same signal type).

**Resolution process:**

1. Identify the conflict: "New proposal conflicts with existing rule [title] (status: CONFIRMED, score: 8/12)"
2. Score both rules on the same 4 dimensions using current evidence.
3. Apply tiebreakers in order:
   - More evidence wins.
   - More recent signal wins (if evidence is equal).
   - Better observed outcomes win (if recency is equal).
4. Replace the weaker rule. Log the resolution:

```markdown
### Conflict Resolution — [date]

- **New rule:** [title], score [N]/12
- **Existing rule:** [title], score [N]/12, status [CONFIRMED/CORE]
- **Winner:** [which rule] — [reason: more evidence / more recent / better outcomes]
- **Action:** Existing rule moved to RETIRED. New rule enters TRIAL.
```

If the existing rule is CORE (5+ confirmed sessions), require explicit user approval before replacing it. CORE rules are not overridden automatically.

### Retrospective on Retrospectives

Every 5 sessions, run a meta-retrospective: evaluate the performance of the retrospective skill itself.

**Trigger:** session_count is a multiple of 5.

**Evaluate:**

1. **Rule confirmation rate** — Of rules that completed TRIAL, what fraction were CONFIRMED vs RETIRED?
   - Healthy: >= 60% confirmed
   - Unhealthy: < 40% confirmed (proposals are poor quality, lower learning rate)

2. **Friction trend** — Did overall friction signals per session decrease, stay flat, or increase?
   - Healthy: decreasing trend over last 5 sessions
   - Unhealthy: flat or increasing (rules are not addressing root causes)

3. **False positives** — Rules that were CONFIRMED but later caused new friction signals.
   - Healthy: 0-1 false positives per 5-session window
   - Unhealthy: 2+ false positives (scoring thresholds too permissive)

**Threshold adjustment:**

Based on the meta-retrospective findings, adjust scoring thresholds:

```
If confirmation_rate < 40%:  raise threshold by 1 (max 11)
If false_positives >= 2:     raise threshold by 1 (max 11)
If friction_trend > 0:       raise threshold by 1 (max 11)

If confirmation_rate >= 80% AND friction_trend < 0 AND false_positives == 0:
  lower threshold by 1 (min 5)
```

Log the meta-retrospective:

```markdown
### Meta-Retrospective — Sessions [N-4] to [N]

- **Rules proposed:** [count]
- **Rules confirmed:** [count] ([pct]%)
- **Rules retired:** [count]
- **False positives:** [count]
- **Friction trend:** [decreasing / flat / increasing]
- **Threshold before:** [N]
- **Threshold after:** [N]
- **Reason for change:** [one line]
```

Save the meta-retrospective log to `.maestro/logs/` using the same build-log mechanism as standard retrospectives.
