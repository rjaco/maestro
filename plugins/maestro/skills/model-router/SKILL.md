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

---

## Historical Performance Tracking

After each agent dispatch completes (including QA outcome), record performance data to `.maestro/model-performance.md`. The delegation skill reads this file at routing time to adjust model selection based on observed outcomes.

### Performance Log Format

The performance log is a Markdown file maintained by the orchestrator. Each run appends or updates the relevant row. The file header contains the last-updated timestamp.

```markdown
## Model Performance Log
Updated: [timestamp]

| Task Type      | Model  | Dispatches | Success Rate | Avg Tokens | QA First-Pass |
|----------------|--------|-----------|-------------|------------|---------------|
| implementation | sonnet | 15        | 87%         | 12K        | 80%           |
| implementation | haiku  | 5         | 40%         | 4K         | 20%           |
| review         | haiku  | 20        | 95%         | 3K         | N/A           |
| planning       | opus   | 8         | 100%        | 25K        | N/A           |
| research       | sonnet | 10        | 90%         | 18K        | N/A           |
```

**Column definitions:**

- **Task Type** — One of the canonical types from the classification table below.
- **Model** — The model that was dispatched (`haiku`, `sonnet`, or `opus`).
- **Dispatches** — Total number of times this task-type/model combination has been dispatched.
- **Success Rate** — Percentage of dispatches that completed without a BLOCKED or NEEDS_CONTEXT outcome. Retries count as separate dispatches.
- **Avg Tokens** — Rolling average of total tokens (input + output) consumed per dispatch.
- **QA First-Pass** — Percentage of implementation dispatches that passed QA on the first attempt. Set to `N/A` for non-implementation task types where QA is not applicable.

### Task Type Classification

Before recording or reading performance data, classify the task into one of the canonical types below. Use the examples as a guide; when a story spans multiple types, pick the dominant one.

| Type            | Examples                                         | Default Model |
|-----------------|--------------------------------------------------|---------------|
| implementation  | Writing code, creating files, adding features    | sonnet        |
| review          | Code review, QA validation, audit               | haiku         |
| planning        | Architecture decisions, story decomposition      | opus          |
| research        | Web research, competitor analysis, fact-finding  | sonnet        |
| documentation   | README, API docs, inline comments, changelogs   | haiku         |
| testing         | Test generation, test execution, coverage        | sonnet        |

The default model column represents the model used when no historical data exists for the combination. It does not override the 10-dimension scoring result — it only applies when the performance log has zero dispatches for the combination being evaluated.

### Adaptive Selection Algorithm

When routing a new task, the orchestrator applies the following algorithm after the 10-dimension score is computed but before any override rules are evaluated:

1. **Look up historical data.** Query `.maestro/model-performance.md` for the (task type, proposed model) row.

2. **Check sample sufficiency.** If the row has fewer than 10 dispatches, historical data is considered insufficient. Skip adaptive adjustment and proceed with the scored model.

3. **Evaluate under-performance threshold.** If the proposed model has a success rate below 60% for this task type, apply an automatic upgrade:
   - `haiku` → `sonnet`
   - `sonnet` → `opus`
   - `opus` stays `opus` (no higher tier available)

   Log the upgrade in the routing output block with reason `historical: success_rate < 60%`.

4. **Evaluate downgrade opportunity.** If both of the following are true, flag a potential downgrade for cost savings. Do not apply the downgrade automatically — present it as a recommendation in the routing output:
   - The proposed model has a success rate above 90% for this task type.
   - The next-cheaper model has a success rate above 80% for this task type (and has at least 10 dispatches).

   Log the recommendation in the routing output block as `historical: downgrade_candidate`.

5. **Apply override rules.** Historical adjustments are applied before override rules (§ Override Rules). Override rules may still escalate after a historical downgrade recommendation.

6. **Record outcome.** After the dispatch completes and QA runs, update the performance log row with the new dispatch count, recalculated success rate, updated token average, and QA first-pass result (if applicable).

### Routing Output Block — Extended Format

When historical data influences the routing decision, extend the standard output block with a `History` line:

```
Model Router: Story [ID] — [Story Title]
Dimensions: files:[0-3] logic:[0-3] novelty:[0-3] tests:[0-3] security:[0-3] ambiguity:[0-3] cross:[0-3] errors:[0-3] api:[0-3] refactor:[0-3]
Total: [sum]/30 → [scored model]
History: [task type] / [proposed model] — [N] dispatches, [success rate]% success → [adjustment or "no change"]
Override: [override rule applied, or "none"]
Final: [model]
```

Example with historical upgrade:

```
Model Router: Story 12 — Parse uploaded CSV
Dimensions: files:1 logic:1 novelty:0 tests:1 security:0 ambiguity:0 cross:0 errors:0 api:0 refactor:0
Total: 3/30 → haiku
History: implementation / haiku — 5 dispatches, 40% success → upgraded to sonnet (success_rate < 60%)
Override: none
Final: sonnet
```

Example with downgrade candidate:

```
Model Router: Story 19 — Update changelog entry
Dimensions: files:1 logic:0 novelty:0 tests:0 security:0 ambiguity:0 cross:0 errors:0 api:0 refactor:0
Total: 1/30 → haiku
History: documentation / haiku — 18 dispatches, 94% success, haiku also at 94% → downgrade_candidate (already at minimum tier)
Override: none
Final: haiku
```

### Performance Data File Location

The performance log lives at `.maestro/model-performance.md` in the project root. This file is:

- **Loaded** by the delegation skill at the start of every model routing decision.
- **Updated** by the orchestrator after every dispatch outcome is known (post-QA).
- **Not committed** to version control by default — it is a local operational file, similar to `.maestro/state.local.md`.
- **Bootstrapped** automatically if it does not exist. The orchestrator creates an empty table with zero dispatches for all task-type/model combinations before the first dispatch of a new project.

If the file is missing or unreadable at routing time, the adaptive algorithm is skipped entirely. Log a warning in the audit log and proceed with the scored model.

### User Override

The user can always override both the scored model and any historical adjustment. Override mechanisms, in priority order:

1. **Story-level `model` field** — Set in the story YAML/Markdown front matter. Skips scoring and historical lookup entirely.
2. **Global `model_override` in state** — Set via `/maestro model <model>`. Applies to all dispatches until cleared.
3. **Per-session override via `/maestro model` command** — Interactively select a model. Takes precedence over historical data for the duration of the session.

User preferences always take priority over historical data. The adaptive algorithm never downgrades below a user-specified model, and never upgrades above one without surfacing an explicit confirmation prompt.

### Interaction with Existing Override Rules

Historical adjustments integrate with the existing override rules (§ Override Rules) as follows:

| Situation | Outcome |
|-----------|---------|
| Historical upgrade + security floor also applies | Both escalate independently; the higher result wins |
| Historical upgrade + ambiguity == 3 | Both force `opus`; result is `opus` |
| Historical upgrade + QA failure bump | Both apply; score adjusted first, then historical, then QA bump |
| Historical downgrade candidate + security floor | Security floor suppresses downgrade; recommendation is not emitted |
| User override present | All historical logic is skipped |
