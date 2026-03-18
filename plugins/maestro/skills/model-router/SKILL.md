---
name: model-router
description: "Multi-dimension task scoring for optimal model selection. Scores tasks across 10 dimensions (0-3 each, max 30) to select the cheapest adequate model. Replaces the simple complexity check in delegation."
---

# Model Router

Scores every task across 10 dimensions before model assignment. The goal is to select the cheapest model that can adequately handle the task — not the safest or most capable one.

## Scoring Dimensions

Score each dimension 0–3. Maximum total: 30.

| # | Dimension | 0 | 1 | 2 | 3 |
|---|-----------|---|---|---|---|
| 1 | **File count** | 1 file | 2–3 files | 4–6 files | 7+ files |
| 2 | **Logic complexity** | Config/data | CRUD | Business logic | Algorithms |
| 3 | **Pattern novelty** | Exact template exists | Similar pattern | New pattern | Novel design |
| 4 | **Test requirements** | No tests | Unit tests | Integration tests | E2E tests |
| 5 | **Security sensitivity** | Internal only | User input | Auth/payment | Crypto/PII |
| 6 | **Ambiguity** | Crystal clear spec | Minor gaps | Significant gaps | Highly ambiguous |
| 7 | **Cross-cutting** | Single concern | 2 concerns | 3+ concerns | System-wide |
| 8 | **Error handling** | Happy path only | Standard errors | Edge cases | Distributed errors |
| 9 | **API surface** | No public API | Internal API | External API | Breaking change |
| 10 | **Refactoring scope** | Pure addition | Minor refactor | Moderate refactor | Major refactor |

### Scoring Notes by Dimension

**File count** — Count files that will be created or modified, excluding auto-generated files. Test files count.

**Logic complexity** — Score the hardest logic in the story, not the average. One algorithmic section makes the whole story a 3.

**Pattern novelty** — Score 0 only when a near-identical implementation exists that can be lifted and adapted with minimal changes. "Similar but different" is a 1, not a 0.

**Test requirements** — Score the highest tier required. A story with unit and integration tests scores 2.

**Security sensitivity** — Score the most sensitive surface the story touches. A feature that adds a user input field to an existing auth flow scores 2, not 1.

**Ambiguity** — Score based on the state of the spec at dispatch time, not after clarification. If the orchestrator had to fill in gaps before dispatching, that ambiguity still counts.

**Cross-cutting** — "Concerns" means distinct layers or responsibilities: API, DB, cache, events, UI, auth, logging. Count distinct ones touched.

**Error handling** — Score 3 only when the story explicitly requires cross-service retry or compensating transactions. Timeout handling alone is a 2.

**API surface** — Score 3 only when an existing external API contract changes. Adding new endpoints without removing old ones is a 2.

**Refactoring scope** — Score 0 when no existing lines are deleted or restructured in non-test files.

## Model Mapping

Sum all 10 dimensions. Map the total to a model:

| Score | Model | Use Case |
|-------|-------|----------|
| 0–8 | `haiku` | Simple, well-defined tasks with clear templates |
| 9–16 | `sonnet` | Standard development — moderate logic, some unknowns |
| 17–30 | `opus` | Complex, ambiguous, security-critical, or novel architecture |

## Override Rules

Evaluated in order. Earlier rules take precedence over later ones.

1. **User-specified model always wins.** If the story has a `model` field or the user set a global `model_override` in state, use that model. Skip scoring entirely. Never downgrade from a user-specified model.

2. **Security floor.** Security sensitivity >= 2 (auth/payment or above) forces minimum `sonnet`. A total score of 0–8 cannot route to `haiku` when this override applies.

3. **Ambiguity escalation.** Ambiguity == 3 (highly ambiguous) forces `opus` regardless of total score. Do not dispatch a highly ambiguous story to haiku or sonnet.

4. **QA failure bump.** If the current story previously failed QA in this same implementation cycle, add +5 to the total score before applying the model mapping. A previously haiku-range story may push into sonnet or opus territory.

5. **Historical stats feedback.** Read `model_stats` from `.maestro/state.local.md`. If `haiku` has achieved >= 80% QA first-pass rate across all stories in this project, widen the haiku boundary to 0–10 for this dispatch. This allows progressive cost reduction as the project demonstrates model sufficiency.

Agent type floors from delegation still apply: `orchestrator` and `architect` always floor at `sonnet`. The router cannot assign haiku to these agent types.

## Scoring Output Format

Emit this block before every dispatch decision:

```
Model Router: Story [ID] — [Story Title]
Dimensions: files:[0-3] logic:[0-3] novelty:[0-3] tests:[0-3] security:[0-3] ambiguity:[0-3] cross:[0-3] errors:[0-3] api:[0-3] refactor:[0-3]
Total: [sum]/30 → [model]
Override: [override rule applied, or "none"]
```

Example with override:

```
Model Router: Story 03 — Add OAuth Login
Dimensions: files:2 logic:2 novelty:1 tests:2 security:2 ambiguity:1 cross:1 errors:1 api:2 refactor:1
Total: 15/30 → sonnet
Override: security >= 2, minimum sonnet confirmed
```

Example without override:

```
Model Router: Story 07 — Add pagination labels
Dimensions: files:1 logic:1 novelty:0 tests:1 security:0 ambiguity:0 cross:0 errors:0 api:0 refactor:0
Total: 3/30 → haiku
Override: none
```

## Integration Points

### Delegation

Replaces Decision 2 (What Model) in `skills/delegation/SKILL.md`. The auto-downgrade heuristics (Decision 2b) are superseded — the 10-dimension score already captures the same signals with finer resolution. Run the router before every agent dispatch, pass the selected model to the dispatch protocol.

### Token Ledger

After each dispatch completes, pass the routing decision to `skills/token-ledger/SKILL.md`:

```
token-ledger record:
  story_id: <id>
  model: <model selected>
  router_score: <total>
  input_tokens: <n>
  output_tokens: <n>
  estimated_tokens: <from planning>
```

The router score enriches cost analysis. High-scoring stories that run under budget indicate conservative routing; low-scoring stories that run over budget indicate the model was insufficient.

### Audit Log

Log every routing decision to `.maestro/logs/decisions.md` as a `model_selection` entry. Set confidence to 0.7 when the total score is within 2 points of a model boundary (8–10 or 16–18), and 0.9 otherwise. Update the `Outcome` field after QA completes for the story.

### Retrospective

The retrospective skill reads routing decisions from the audit log to compute routing accuracy per tier:

```
Model routing accuracy:
  haiku:  [N] dispatched, [N] escalated ([pct]% under-routed)
  sonnet: [N] dispatched, [N] escalated ([pct]% under-routed)
  opus:   [N] dispatched, [N] could have been sonnet ([pct]% over-routed)
```

Propose model boundary or override threshold adjustments when under-routing or over-routing rate exceeds 20% for any tier.
