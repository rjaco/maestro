---
name: audit-log
description: "Structured decision audit log for post-hoc review and learning. Captures agent decisions as first-class artifacts — distinct from build-log (what happened) and memory (what to remember)."
---

# Audit Log

Records every significant agent decision as a structured, queryable artifact. The build-log tracks events; memory tracks lessons; the audit log tracks *choices* — what was considered, what was picked, and whether it worked.

## Log Location

All entries append to `.maestro/logs/decisions.md`.

## Entry Format

```markdown
### [ISO-8601 timestamp] [agent-id] [decision-type]
- **Input state**: [what the agent was given when the decision was made]
- **Decision**: [what the agent chose]
- **Alternatives considered**: [other options evaluated, separated by " / "]
- **Confidence**: [0.0–1.0]
- **Rationale**: [why this choice over the alternatives]
- **Outcome**: pending
```

The `Outcome` field starts as `pending` and is updated after execution:
- `success` — the decision led to the intended result
- `failure` — the decision led to a failure or required rollback
- `partial` — mixed result; include a note

Example:

```markdown
### 2026-03-18T14:32:01Z implementer-a3f1 model_selection
- **Input state**: Story 03 — "Add pagination to user list"; 3 files to modify; follows existing pattern
- **Decision**: sonnet
- **Alternatives considered**: haiku / opus
- **Confidence**: 0.85
- **Rationale**: 3-file change with existing pattern; haiku underpowered for conditional logic; opus unnecessary
- **Outcome**: success
```

## Decision Types

Log an entry for each of the following decision categories:

| Type | Who logs it | What to capture |
|------|-------------|-----------------|
| `model_selection` | delegation | which model and why; signals that drove the choice |
| `story_ordering` | decompose | dependency sort order; why this story precedes another |
| `context_tier` | delegation / context-engine | tier selected (T0–T4); token budget; signals used |
| `self_heal_approach` | dev-loop self-heal phase | error type; fix strategy chosen; strategies rejected |
| `qa_verdict` | dev-loop QA phase | approved or rejected; which criteria failed; severity |
| `escalation` | opus-loop / delegation | why a task was escalated (model, context, or user); trigger condition |
| `skip_decision` | opus-loop / dev-loop | why a story was skipped or deferred; dependency or blocker cited |
| `architecture_choice` | decompose / architect agent | approach selected; alternatives; key trade-offs |

## Logging Protocol

**When to log:** At the moment the decision is made, before execution begins.

**Lightweight target:** 3–5 lines per entry. Do not narrate — record facts.

**Append-only:** Never modify or delete past entries. Update only the `Outcome` field after execution completes.

**Outcome update:** When a phase or story resolves, find the matching `pending` entry and update its `Outcome` line in-place. This is the only permitted mutation.

**Minimum logging points by skill:**
- `delegation/SKILL.md` — log `model_selection` and `context_tier` per dispatch
- `dev-loop/SKILL.md` — log `self_heal_approach` per fix attempt and `qa_verdict` per review
- `decompose/SKILL.md` — log `story_ordering` after the dependency graph is set
- `opus-loop/SKILL.md` — log `escalation` and `skip_decision` when either occurs

## Querying Patterns

The log is plain markdown. Filter with standard text tools or instruct an agent to scan it.

**By decision type** — extract all `model_selection` entries:
```
grep -A6 "model_selection" .maestro/logs/decisions.md
```

**By outcome** — find all failures:
```
grep -B6 "Outcome.*failure" .maestro/logs/decisions.md
```

**By confidence** — find low-confidence decisions (< 0.5):
```
grep -B2 "Confidence: 0\.[0-4]" .maestro/logs/decisions.md
```

**By time range** — filter a session by ISO prefix:
```
grep -A6 "2026-03-18" .maestro/logs/decisions.md
```

**By agent** — isolate one agent's decisions:
```
grep -A6 "implementer-a3f1" .maestro/logs/decisions.md
```

## Retrospective Analysis

The `retrospective` skill reads `decisions.md` to compute these metrics after each feature or milestone.

### Decision Accuracy

```
accuracy = count(Outcome: success) / count(Outcome != pending)
```

Report by decision type to surface which categories are least reliable.

### Overconfidence Detection

```
flag entries where Confidence >= 0.8 AND Outcome == failure
```

High confidence paired with failure indicates a systematic blind spot. Propose a convention update or model upgrade for the affected decision type.

### Underconfidence Detection

```
flag entries where Confidence <= 0.4 AND Outcome == success
```

Consistent underconfidence wastes tokens on unnecessary escalations. Identify the decision type and tighten the threshold.

### Pattern Detection

```
flag decision types where failure_rate > 30% over last 10 entries
```

Three or more failures of the same type within a feature signals a broken heuristic. Surface as a high-confidence retrospective improvement candidate.

### Retrospective Summary Block

Append to the retrospective output:

```markdown
## Decision Audit Summary

- Total decisions logged: [N]
- Outcomes resolved: [N] / [N] (pending: [N])
- Accuracy: [N]%
- Overconfidence flags: [N] (Confidence >= 0.8, Outcome = failure)
- Underconfidence flags: [N] (Confidence <= 0.4, Outcome = success)
- Failing patterns: [list decision types with > 30% failure rate]
```
