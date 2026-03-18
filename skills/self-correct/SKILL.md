---
name: self-correct
description: "Self-correction loop that captures correction signals from user feedback, QA rejections, and self-heal failures, then permanently writes learnings to skill files, CLAUDE.md, and project memory."
---

# Self-Correct

Captures correction signals as they occur and permanently encodes learnings into project files. Inspired by claude-reflect (Feb 2026). Each correction is irreversible — written into CLAUDE.md, skill files, DNA, and memory — so the same mistake cannot recur across sessions.

## Correction Signal Sources

### 1. User Corrections

Explicit feedback during any dev-loop phase.

**Trigger phrases:** "No, use X instead of Y", "Don't do that", "Always use...", "Never use...", "I already told you..."

**Default confidence:** 1.0. **Detection:** Scan user messages at each checkpoint and `.maestro/notes.md` for intent `feedback` or `redirect`.

### 2. QA Rejections

Patterns in QA feedback indicating recurring mistakes across stories.

**Trigger conditions:** Same violation in 2+ separate QA reviews; a finding referencing a convention not in CLAUDE.md; a re-implementation that applies the identical fix.

**Default confidence:** 0.6 (single rejection) / 0.8 (3+ identical rejections). **Detection:** After each QA verdict, compare against `.maestro/corrections.md` and increment occurrence count if matched.

### 3. Self-Heal Failures

Error patterns requiring 3+ fix attempts before resolution.

**Trigger condition:** Fix agent loop runs 3 times on the same error class without success.

**Default confidence:** 0.4. **Detection:** Track fix attempt counts per error class in `.maestro/state.local.md`.

### 4. Manual Overrides

User explicitly overrides agent behavior mid-execution.

**Trigger conditions:** User edits a file the implementer just wrote; user changes `model_override` mid-session; user rolls back a git-craft commit; user replaces QA-approved output.

**Default confidence:** 0.9. **Detection:** Compare file mtimes before/after user interaction windows; check state diffs between checkpoints.

## Correction Log Format

All corrections are appended to `.maestro/corrections.md` (audit trail and deduplication index).

```markdown
## Correction Log (.maestro/corrections.md)

### [date] [confidence: 0.9] From: user_correction
**Pattern**: Agent used default exports in components
**Correction**: Never use default exports — always named exports
**Applied to**: CLAUDE.md (project conventions)
**Status**: permanent

### [date] [confidence: 0.8] From: qa_rejection (3 occurrences)
**Pattern**: Missing null check before nested property access
**Correction**: Always guard optional chaining before accessing nested relations
**Applied to**: skills/dev-loop/implementer-prompt.md, memory/semantic.md
**Status**: permanent

### [date] [confidence: 0.4] From: self_heal_failure
**Pattern**: npm run build fails after adding a new barrel export
**Correction**: After editing index.ts, run tsc --noEmit before committing
**Applied to**: .maestro/dna.md (known error patterns)
**Status**: logged (below auto-apply threshold)
```

**Status values:** `permanent` (written to target), `proposed` (awaiting approval), `logged` (below threshold).

## Learning Application Targets

| Target | When to Write | What Gets Added |
|--------|--------------|-----------------|
| **CLAUDE.md** | Project-wide coding convention, naming rule, or anti-pattern | Short imperative rule under the relevant section |
| **Skill files** | Missing or incorrect instruction in a specific skill | New bullet in the relevant checklist; audit comment appended to file bottom |
| **Memory** | Confidence >= 0.7 and fact is project-specific | `memory.save_semantic(text, "quality_rule", confidence)` |
| **DNA** | New command pattern, known error class, or build behavior | Entry under `Known Errors` or `Commands` in `.maestro/dna.md` |

Skill file audit comment format:
```
<!-- self-correct: [date] added "always guard null relations" — source: qa_rejection x3 -->
```

## Auto-Apply Workflow

**Step 1 — Score confidence:**

| Source | Base | Adjustment |
|--------|------|------------|
| Explicit user statement | 1.0 | — |
| Manual override | 0.9 | -0.1 if ambiguous cause |
| QA rejection (3+ times) | 0.8 | +0.1 if cross-story pattern |
| QA rejection (single) | 0.6 | — |
| Self-heal failure | 0.4 | +0.1 if same error class seen before |

**Step 2 — Apply threshold:**

| Confidence | Action |
|------------|--------|
| >= 0.7 | Auto-apply to matched targets. Log as `permanent`. Notify user at next checkpoint. |
| 0.4–0.69 | Propose to user at next checkpoint. Apply only on approval. |
| < 0.4 | Log to `.maestro/corrections.md` as `logged`. No write. |

**Step 3 — Write to targets (auto-applied):**
1. Match targets by scope (project-wide → CLAUDE.md; phase-specific → skill file; build behavior → DNA).
2. Write the correction to each matched target.
3. Append audit comment to skill files.
4. Call `memory.save_semantic()` for confidence >= 0.7.
5. Update `.maestro/corrections.md` status to `permanent`.

**Proposal format (confidence 0.4–0.69):**
```
Self-Correct: 1 correction proposal
Pattern:    [description]
Evidence:   [source and occurrence count]
Confidence: [score]
Target:     [file]
Apply?      [yes / no / modify]
```

## Pattern Detection

**Occurrence counting:** On each new signal, fuzzy-match the `Pattern` field against existing entries in `.maestro/corrections.md`. If matched, increment occurrence count and re-evaluate confidence (count >= 3 elevates confidence by one tier).

**Escalation:** When the same correction appears 3+ times across sessions, auto-escalate to `permanent` regardless of original confidence. Write to all applicable targets.

**Conflict detection:** Before writing, search the target file for contradicting rules. If found, do not auto-apply — flag to user:
```
Conflict detected:
  New:      "Always use named exports"
  Existing: "Use default exports for page components" (CLAUDE.md)
  Which rule applies?
```
User resolution required before either rule is applied or retained.

**Per-agent mistake tracking** in `.maestro/state.local.md`:
```yaml
correction_stats:
  implementer:
    sonnet: { corrections: 4, patterns: ["null guard", "default exports"] }
    haiku:  { corrections: 7, patterns: ["null guard", "barrel exports"] }
```
If a model accumulates 3+ corrections of the same pattern, delegation biases away from that model for stories likely to trigger it.

## Skill Evolution

When a correction identifies a missing instruction in a skill file:

1. Match the correction to the relevant skill by phase and content area.
2. Draft the addition as an imperative ("Always X", "Never Y", "When Z, do W").
3. Propose to user if confidence < 0.8. Auto-apply if confidence >= 0.8.
4. Append the instruction to the relevant checklist block.
5. Append audit comment to the skill file and log to `.maestro/corrections.md` under `## Skill Modifications`.

## Integration Points

| Skill | Integration |
|-------|-------------|
| **dev-loop** | After Phase 5 QA verdict: `capture(verdict, source="qa_rejection")`. After Phase 4 self-heal fails 3x: `capture(error, source="self_heal_failure")`. |
| **retrospective** | Each approved improvement candidate passes through `capture()` with `source="retrospective"` and the candidate's confidence score. Ensures retrospective learnings are written, not just noted. |
| **memory** | `self-correct` calls `memory.save_semantic()` for confidence >= 0.7. Memory handles decay and retrieval weighting. Self-correct only writes. |
| **delegation** | At dispatch time, reads `correction_stats` to bias model selection. A model with 3+ pattern corrections incurs one simplicity-signal penalty for relevant stories. |
