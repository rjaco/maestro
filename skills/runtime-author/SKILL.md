---
name: runtime-author
description: "Autonomously detect recurring gaps during execution and generate new project-scoped skills on-the-fly without user intervention. Triggered by repeated QA rejections, repeated NEEDS_CONTEXT escalations, or unmatched orchestrator patterns."
---

# Runtime Author

Monitors Maestro execution signals for recurring gaps and autonomously authors new skills to close them. Unlike the `skill-factory` (which generates profile-based specialist skills from project DNA), the Runtime Author reacts to live execution data — it creates targeted "gotcha checker", "context provider", and "workflow" skills the moment a pattern repeats three times.

Generated skills are project-scoped (`.maestro/runtime-skills/`), validated by `skill-validator` before registration, and scored by the `context-engine` like any other skill.

## When to Use

- Called by the `retrospective` skill when it detects repeated friction signals
- Called by the orchestrator when it recognizes a workflow pattern with no matching skill
- Never called manually during normal dev-loop execution — this skill is an autonomous system trigger

## Gap Detection Triggers

The Runtime Author monitors three signal streams. Each stream requires **three or more occurrences** of the same pattern before authoring begins. A single occurrence or a pair is noise; three is a signal.

### Trigger 1 — Repeated QA Rejection

**Signal source:** `.maestro/logs/` — QA reviewer outputs labeled REJECTED or NEEDS_REVISION.

**Detection algorithm:**

1. Parse the `feedback_category` field from each QA rejection log entry.
2. Group by normalized category (case-insensitive, strip punctuation).
3. When any category accumulates 3 or more rejections across distinct stories, fire this trigger.
4. Extract: category label, the 3+ source stories, the common pattern in the feedback text.

**Output skill type:** `gotcha-checker` — a pre-flight check skill the implementer runs before submitting work for QA.

**Example pattern that triggers this:**
```
Story M2-03 QA: "missing error boundary around async components"
Story M2-05 QA: "missing error boundary around async components"
Story M3-01 QA: "no error boundary — async fetch not wrapped"
→ Trigger fires: category "error-boundary-missing", 3 stories
```

---

### Trigger 2 — Repeated NEEDS_CONTEXT Escalation

**Signal source:** Implementer agent status reports with `STATUS: NEEDS_CONTEXT`.

**Detection algorithm:**

1. Parse each NEEDS_CONTEXT report and extract the `missing_context_type` (e.g., "database schema", "auth middleware interface", "API route pattern").
2. Normalize the type label (keyword-based deduplication: "DB schema" and "database schema" are the same type).
3. When the same context type appears missing across 3 or more distinct stories, fire this trigger.
4. Extract: context type label, the 3+ source stories, a description of what was needed.

**Output skill type:** `context-provider` — a skill that pre-fetches the repeatedly-missing context and injects it into the context package for relevant story types.

**Example pattern that triggers this:**
```
Story M1-04 NEEDS_CONTEXT: "auth middleware interface not provided"
Story M2-01 NEEDS_CONTEXT: "need auth middleware signature"
Story M2-06 NEEDS_CONTEXT: "auth middleware — where is it defined?"
→ Trigger fires: context type "auth-middleware-interface", 3 stories
```

---

### Trigger 3 — Pattern Without Matching Skill

**Signal source:** Orchestrator task logs and retrospective skill outputs.

**Detection algorithm:**

1. During retrospective analysis, the `retrospective` skill flags workflows that required manual orchestrator intervention because no skill handled them.
2. If the same workflow type is flagged across 3 or more features or milestones, pass the pattern description to the Runtime Author.
3. The pattern must be described concretely: what steps were performed, what the inputs were, what the outputs were.

**Output skill type:** `workflow` — a skill encoding the repeated multi-step process so the orchestrator can invoke it by name in future sessions.

**Example pattern that triggers this:**
```
Feature 2 retro: "manually ran DB seed + migrate before every test story"
Feature 3 retro: "same DB reset sequence needed before integration tests"
Feature 4 retro: "DB reset again — no skill for this"
→ Trigger fires: workflow pattern "pre-test-db-reset", 3 features
```

---

## Authoring Process

When a trigger fires, the Runtime Author executes these steps in order. All steps are autonomous — no user approval required unless the generated skill fails validation.

### Step 1: Extract Pattern Data

Collect from the trigger signal:
- `skill_type`: one of `gotcha-checker`, `context-provider`, `workflow`
- `trigger_source`: which trigger fired (QA_REJECTION | NEEDS_CONTEXT | PATTERN_WITHOUT_SKILL)
- `pattern_label`: normalized slug for the pattern (e.g., `error-boundary-missing`, `auth-middleware-interface`, `pre-test-db-reset`)
- `source_stories`: array of story IDs that contributed (minimum 3)
- `evidence_summary`: 1-3 sentence description of the recurring gap
- `confidence`: float 0.0-1.0, calculated as:
  - 3 occurrences → 0.75
  - 4 occurrences → 0.85
  - 5+ occurrences → 0.95

### Step 2: Generate Skill Name

Construct the skill name following this convention:

```
runtime-[skill_type]-[pattern_label]
```

Examples:
- `runtime-gotcha-error-boundary-missing`
- `runtime-context-auth-middleware-interface`
- `runtime-workflow-pre-test-db-reset`

Check `.maestro/runtime-skills/` for an existing skill with this name. If one exists, append to its `source_stories` field and update its `confidence` rather than creating a duplicate.

### Step 3: Generate SKILL.md Content

Produce the skill file using the standard auto-generated format:

```markdown
---
name: "[runtime-skilltype-pattern-label]"
description: "[one-line description of the gap this skill closes]"
auto_generated: true
trigger: "[QA_REJECTION | NEEDS_CONTEXT | PATTERN_WITHOUT_SKILL]"
confidence: [0.75 | 0.85 | 0.95]
created: "[YYYY-MM-DD]"
source_stories: ["[id1]", "[id2]", "[id3]"]
---

# [Human-Readable Skill Title]

Auto-generated by Maestro Runtime Author on [date].
Source: [trigger description — one sentence]

## Problem

[What recurring gap this skill fills. Describe the symptom that kept appearing,
not the fix. 2-4 sentences.]

## Solution

[Concrete steps to follow. For gotcha-checkers: a checklist the implementer runs
before submitting. For context-providers: what to fetch and where to find it.
For workflows: the numbered steps of the repeated process.]

## When to Apply

[The conditions under which this skill is relevant. Be specific enough that the
context-engine's keyword filter can match it against incoming stories.]
```

**Content rules for each skill type:**

**gotcha-checker:** The `## Solution` section must contain a numbered checklist of verification steps. Each item must be specific enough to be actionable without re-reading the original QA feedback. Include the exact pattern to check for and the exact fix.

**context-provider:** The `## Solution` section must identify: (a) which file(s) contain the missing context, (b) what specifically to extract (function signatures, type definitions, schema fields), and (c) which story types should receive this context automatically.

**workflow:** The `## Solution` section must be a numbered sequence of steps. Each step must specify the tool or command, the expected output, and the error handling if the step fails.

### Step 4: Validate with Skill Validator

Before writing to disk, run the generated SKILL.md content through `skill-validator` with `source: auto-generated`.

**Validation outcome handling:**

| Outcome | Action |
|---------|--------|
| ACCEPTED (no warnings) | Proceed to Step 5 |
| ACCEPTED (with warnings) | Proceed to Step 5; log warnings to skill-authoring.md |
| REJECTED | Attempt one auto-fix pass: remove offending content, regenerate affected sections, re-validate. If still REJECTED after one pass: discard, log failure to skill-authoring.md, halt this authoring run |

The auto-fix pass is permitted to:
- Rewrite the description if it fails SK-11
- Add missing sections if it fails SK-12
- Remove any path references that triggered SK-06

The auto-fix pass must NOT:
- Lower the specificity of the skill's content to pass quality checks
- Add fabricated evidence to inflate the description

### Step 5: Write to Disk

Write the validated SKILL.md to the project-scoped runtime skills directory:

```
.maestro/runtime-skills/[skill-name]/SKILL.md
```

This path is project-scoped, not global. Runtime skills created for one project are not shared with other projects.

After writing, register the skill in `.maestro/skills-registry.md`:

```markdown
| [skill-name] | [date] | runtime-author | [trust-score] | 0 |
```

### Step 6: Log the Authoring Event

Append to `.maestro/logs/skill-authoring.md`:

```markdown
## [YYYY-MM-DD HH:MM] — [skill-name]

- **Trigger:** [QA_REJECTION | NEEDS_CONTEXT | PATTERN_WITHOUT_SKILL]
- **Pattern:** [pattern_label]
- **Source stories:** [id1], [id2], [id3]
- **Confidence:** [value]
- **Validation:** [ACCEPTED | ACCEPTED with warnings | REJECTED after auto-fix]
- **Output:** [path to written file, or "discarded"]
- **Summary:** [1-sentence description of what the skill does]
```

If the log file does not exist, create it with the heading:

```markdown
# Skill Authoring Log

Generated by the Maestro Runtime Author. Each entry records one autonomous skill creation event.
```

---

## Context Engine Integration

Runtime skills are loaded by the `context-engine` using the same relevance scoring as built-in skills. No special handling is required.

**How the context-engine finds runtime skills:**

The context-engine scans `.maestro/runtime-skills/` in addition to `skills/` when building context packages. Each runtime skill's frontmatter `description` and `## When to Apply` section are indexed for keyword matching.

**Relevance scoring for runtime skills:**

Runtime skills are scored on the same 0.0-1.0 scale as built-in skills. They receive a confidence-based initial weight:

```
relevance_score = keyword_match_score * skill.confidence
```

A runtime skill with `confidence: 0.75` needs stronger keyword overlap than a built-in skill to be included at the same tier threshold. This prevents low-confidence runtime skills from crowding out reliable built-in context.

**Tier placement:** Runtime skills are included at the same tier as the built-in skill they most resemble:
- `gotcha-checker` skills → T3 (implementer tier)
- `context-provider` skills → T3 (implementer tier)
- `workflow` skills → T2 (architect tier) for complex multi-step workflows, T3 for simple ones

---

## Maestro Doctor Integration

`/maestro doctor` lists runtime skills under a dedicated section:

```
Runtime Skills (.maestro/runtime-skills/)
  runtime-gotcha-error-boundary-missing    confidence: 0.85  used: 3x  created: 2026-03-18
  runtime-context-auth-middleware          confidence: 0.95  used: 7x  created: 2026-03-10
  runtime-workflow-pre-test-db-reset       confidence: 0.75  used: 1x  created: 2026-03-17
```

If `.maestro/runtime-skills/` is empty or does not exist, the section reads:

```
Runtime Skills   none generated yet
```

---

## Deduplication and Staleness

**Deduplication:** Before generating a new skill, check all existing runtime skills for semantic overlap. If an existing skill already covers the pattern (same trigger type, similar pattern label), update the existing skill's `source_stories` and recalculate `confidence` rather than creating a new one.

**Staleness:** A runtime skill becomes a candidate for retirement if it has not been invoked in the last 20 stories. The `retrospective` skill flags stale runtime skills for the user's review. The user decides whether to retire or keep them — the Runtime Author never deletes skills autonomously.

---

## Limitations

- The Runtime Author does not generate skills for one-off failures. Three identical occurrences is the minimum — this is a hard floor, not a soft guideline.
- Generated skills describe what to do, not how the underlying code works. They are process skills, not implementation guides.
- Runtime skills generated from QA rejections are additive (checklist items to add) — they do not modify existing QA reviewer prompts. The `retrospective` skill handles prompt updates separately.
- If the `skill-validator` is unavailable, the Runtime Author halts and logs a warning rather than writing an unvalidated skill.
