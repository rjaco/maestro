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
