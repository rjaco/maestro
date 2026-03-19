---
name: consensus
description: Multi-agent consensus mechanisms — weighted voting, quorum checks, and conflict resolution for decision quality
---

# Consensus Mechanisms

Structured decision-making protocols for multi-agent systems. When a single agent's opinion is not sufficient — due to stakes, ambiguity, or trust level — consensus mechanisms aggregate multiple agent perspectives into a reliable, auditable outcome.

## When to Use Each Pattern

| Pattern | Use When |
|---------|----------|
| **Weighted Voting** | Code review outcomes, QA verdicts, implementation approach selection |
| **Quorum Check** | Architecture decisions, breaking changes, scope expansions, security policy changes |
| **Conflict Resolution** | Any vote that fails to reach threshold, or where agents give directly contradictory rationales |

Consensus is invoked by the orchestrator — never by the agents themselves. Agents submit structured votes; the orchestrator runs the mechanism and records the outcome.

---

## Pattern 1: Weighted Voting

Multiple agents cast APPROVE or REJECT votes weighted by their role. The orchestrator computes a weighted approval score and compares it against a 60% threshold.

### Role Weights

| Agent Role | Weight |
|-----------|--------|
| Reviewer / QA agent | 3x |
| Architect agent | 2x |
| Implementer agent | 1x |

Rationale: QA and reviewer agents are explicitly optimized for catching issues. Their judgment on correctness, security, and quality should carry the most weight. Architect agents bring structural context. Implementers have domain depth but natural confirmation bias toward their own work.

### Vote Schema

Each agent returns a structured vote at the end of its response:

```
VOTE: APPROVE
CONFIDENCE: 87
RATIONALE: All acceptance criteria met. No security concerns found. Edge case handling is correct.
```

Or:

```
VOTE: REJECT
CONFIDENCE: 92
RATIONALE: Missing input validation on the /api/users endpoint. Confidence score for OWASP A03 violation is 91.
```

Fields:
- `VOTE`: `APPROVE` or `REJECT` (required)
- `CONFIDENCE`: integer 0-100 (required — only votes with confidence >= 60 are counted)
- `RATIONALE`: free text (required — used in conflict resolution and decision log)

### Scoring Formula

```
weighted_approve = sum(weight * confidence) for each APPROVE vote
weighted_reject  = sum(weight * confidence) for each REJECT vote
total_weight     = weighted_approve + weighted_reject

approval_score   = weighted_approve / total_weight
```

If `approval_score >= 0.60`: decision passes.
If `approval_score < 0.60`: decision fails. Trigger conflict resolution.

Low-confidence votes (confidence < 60) are excluded entirely — they add noise without signal.

### Example: Three-Reviewer Code Review

Agents dispatched: correctness reviewer (QA, weight 3), security reviewer (QA, weight 3), performance reviewer (QA, weight 3).

```
Agent            Role      Weight  Vote     Confidence  Weighted Score
correctness-qa   reviewer  3       APPROVE  88          264
security-qa      reviewer  3       REJECT   91          273
performance-qa   reviewer  3       APPROVE  74          222
```

Computation:
- weighted_approve = 264 + 222 = 486
- weighted_reject  = 273
- total_weight     = 759
- approval_score   = 486 / 759 = 0.640 (64%)

Result: PASSES threshold (>= 60%), but security REJECT is flagged in the decision log and surfaced to the orchestrator as a concern. The orchestrator will include the security finding in the QA report even though the overall vote passed.

### Dispatch Protocol

```
// Dispatch N reviewer agents in parallel (single message, multiple Agent calls):

Agent(
  subagent_type: "maestro:maestro-qa-reviewer",
  description: "Correctness review — consensus vote",
  run_in_background: true,
  model: "opus",
  prompt: "[story spec + diff + correctness focus prompt + VOTE SCHEMA INSTRUCTIONS]"
)

Agent(
  subagent_type: "maestro:maestro-qa-reviewer",
  description: "Security review — consensus vote",
  run_in_background: true,
  model: "opus",
  prompt: "[story spec + diff + security focus prompt + VOTE SCHEMA INSTRUCTIONS]"
)

Agent(
  subagent_type: "maestro:maestro-qa-reviewer",
  description: "Performance review — consensus vote",
  run_in_background: true,
  model: "opus",
  prompt: "[story spec + diff + performance focus prompt + VOTE SCHEMA INSTRUCTIONS]"
)
```

Each agent prompt must include the vote schema instructions so the agent returns a parseable vote block.

Vote schema instructions to inject at the end of every reviewer prompt:
```
At the end of your review, output a vote block in exactly this format:
VOTE: [APPROVE or REJECT]
CONFIDENCE: [0-100]
RATIONALE: [one sentence — the single most important reason for your vote]
```

---

## Pattern 2: Quorum Check

A decision only proceeds when N of M agents explicitly agree. This is a count-based threshold, not a weighted score. Used when the decision is categorical (yes/no with high stakes) and every dissenting voice matters.

### Default Threshold

**2/3 majority** — at least ceil(2/3 * M) agents must agree.

| Total Agents (M) | Required Agreement (N) |
|-----------------|----------------------|
| 2 | 2 (100%) |
| 3 | 2 (67%) |
| 4 | 3 (75%) |
| 5 | 4 (80%) |
| 6 | 4 (67%) |

### When to Apply Quorum Check

- Architecture decisions (new patterns, framework changes, data model restructuring)
- Breaking changes (removed endpoints, schema migrations, changed public APIs)
- Scope expansions (adding stories to a milestone in-flight)
- Security policy changes (new auth model, permission structure changes)

### Quorum Vote Schema

Quorum votes are simpler — they require explicit agreement, not a score:

```
QUORUM_VOTE: AGREE
RATIONALE: The proposed architecture aligns with existing patterns and the performance tradeoff is acceptable given projected load.
```

Or:

```
QUORUM_VOTE: DISAGREE
RATIONALE: Switching to event sourcing here introduces operational complexity not justified by the feature requirements.
```

### Dispatch Protocol

For architecture decisions, dispatch agent types that represent different perspectives:

```
// Example: 3-agent quorum for architecture decision

Agent(
  subagent_type: "maestro:maestro-implementer",
  description: "Architecture review — quorum vote [implementer perspective]",
  run_in_background: true,
  model: "opus",
  prompt: "[architecture proposal + implementation context + QUORUM VOTE SCHEMA]"
)

Agent(
  subagent_type: "maestro:maestro-qa-reviewer",
  description: "Architecture review — quorum vote [QA/risk perspective]",
  run_in_background: true,
  model: "opus",
  prompt: "[architecture proposal + risk context + QUORUM VOTE SCHEMA]"
)

Agent(
  subagent_type: "maestro:maestro-researcher",
  description: "Architecture review — quorum vote [research/alternatives perspective]",
  run_in_background: true,
  model: "sonnet",
  prompt: "[architecture proposal + alternative approaches + QUORUM VOTE SCHEMA]"
)
```

### Outcome Handling

If quorum reached: log the decision and proceed.
If quorum not reached: escalate to conflict resolution (Pattern 3).

---

## Pattern 3: Conflict Resolution

When voting fails to reach threshold (weighted voting < 60%) or quorum is not reached, conflict resolution escalates the decision in two stages.

### Stage 1: Model Escalation

Dispatch a single higher-tier model with all agent rationales. The escalation model is given the full picture — every vote, every rationale — and asked to render a judgment.

Model escalation ladder:

```
haiku → sonnet → opus
```

The escalation model is always one tier above the highest model used in the original vote. If opus agents already voted, skip to Stage 2.

Escalation prompt structure:
```
CONFLICT RESOLUTION REQUEST

Decision: [what was being decided]
Threshold required: [60% weighted approval / 2/3 quorum]
Actual result: [approval_score or agree_count / total]

Agent votes:
  [Agent 1 — Role — Weight]: APPROVE (confidence 88)
  Rationale: [...]

  [Agent 2 — Role — Weight]: REJECT (confidence 91)
  Rationale: [...]

  [Agent 3 — Role — Weight]: APPROVE (confidence 74)
  Rationale: [...]

Your task: Evaluate the rationales above. Identify whether any REJECT rationale describes a genuine blocking issue. Render a final judgment:

ESCALATION_VERDICT: [APPROVE or REJECT]
VERDICT_RATIONALE: [2-3 sentences explaining which rationales were most compelling and why]
```

If the escalation agent returns APPROVE: decision proceeds. Log the escalation.
If the escalation agent returns REJECT: advance to Stage 2.

### Stage 2: Human Escalation

Present all agent rationales plus the escalation verdict to the human. This is a PAUSE — no automated decision is made.

```
CONSENSUS FAILED — Human review required

Decision: [what was being decided]

Agent votes:
  correctness-qa   APPROVE (88): All criteria met, edge cases handled
  security-qa      REJECT (91): Missing rate limiting on POST /api/orders
  performance-qa   APPROVE (74): No N+1 issues, queries are indexed

Escalation (opus): REJECT
Escalation rationale: The security reviewer identified a genuine OWASP A05 issue.
Rate limiting on order creation endpoints is a standard requirement for this class
of API. The implementation is incomplete without it.

Options:
  [A] Accept the rejection — re-dispatch implementer with security finding
  [B] Override and approve — I accept the security risk for now
  [C] Amend scope — add a follow-up story for rate limiting, approve current story

Your decision:
```

The human's choice is logged verbatim in the decision log.

---

## Integration with Multi-Review

The `multi-review` skill (see `skills/multi-review/SKILL.md`) dispatches 3 parallel reviewers and produces a unified report. Consensus extends multi-review by adding:

1. Structured vote collection (VOTE/CONFIDENCE/RATIONALE blocks)
2. Weighted scoring instead of a simple majority
3. Escalation protocol when votes diverge

To enable consensus mode on a multi-review dispatch, add `consensus: weighted_voting` to the review configuration:

```
// Standard multi-review (no consensus):
// Reviewers produce findings → deduplicated → unified report → APPROVED/REJECTED verdict

// Consensus-enabled multi-review:
// Reviewers produce findings + vote blocks → weighted score computed →
// if >= 60%: APPROVED (with minority concerns noted) →
// if < 60%: conflict resolution → escalation or human review
```

Consensus mode is recommended when:
- Trust level is Novice or Apprentice (higher oversight needed)
- Story touches security-critical or payment-critical paths
- The feature has had 2+ prior QA rejections (divergent opinions indicate genuine ambiguity)

---

## Integration with Dev-Loop QA Phase

Consensus mechanisms plug into Phase 5 (QA REVIEW) of the dev-loop.

Standard Phase 5 flow:
```
Phase 5: QA REVIEW → single QA agent → APPROVED/REJECTED
```

Consensus-enabled Phase 5 flow:
```
Phase 5: QA REVIEW
  → multi-review skill dispatches N reviewers (parallel)
  → collect votes (VOTE/CONFIDENCE/RATIONALE blocks)
  → weighted_voting(): compute approval_score
  → if approval_score >= 0.60:
      verdict = APPROVED (minority concerns noted)
  → if approval_score < 0.60:
      conflict_resolution():
        stage 1: escalate to higher model with all rationales
        if still REJECT:
          stage 2: PAUSE, present to human
  → log decision (see Decision Log Format below)
  → proceed or re-dispatch implementer
```

Trigger conditions for consensus in Phase 5:

| Condition | Consensus Pattern |
|-----------|------------------|
| Trust level: Novice or Apprentice | Weighted voting (3 reviewers) |
| `--careful` mode active | Weighted voting (3 reviewers) |
| Story tagged `security-critical` | Weighted voting (3 reviewers) |
| Story tagged `architecture` | Quorum check (3 agents) |
| Story tagged `breaking-change` | Quorum check (3 agents) |
| 2+ prior QA rejections on this story | Weighted voting + auto-escalation |

---

## Decision Log Format

Every consensus decision is logged to `.maestro/logs/consensus.md`. The log is append-only.

### Log Entry Schema

```yaml
---
decision_id: consensus-2026-03-18-001
timestamp: "2026-03-18T14:32:07Z"
story: "04-order-api"
pattern: weighted_voting
threshold: 0.60

votes:
  - agent: correctness-qa
    role: reviewer
    weight: 3
    vote: APPROVE
    confidence: 88
    rationale: "All acceptance criteria met. Edge case handling is correct."
  - agent: security-qa
    role: reviewer
    weight: 3
    vote: REJECT
    confidence: 91
    rationale: "Missing rate limiting on POST /api/orders (OWASP A05)."
  - agent: performance-qa
    role: reviewer
    weight: 3
    vote: APPROVE
    confidence: 74
    rationale: "No N+1 patterns. Queries are indexed. Memory usage nominal."

scoring:
  weighted_approve: 486
  weighted_reject: 273
  total_weight: 759
  approval_score: 0.640

result: PASSES
verdict: APPROVED
minority_concerns:
  - "security-qa REJECT (91): Missing rate limiting on POST /api/orders"

escalation: null
human_decision: null
---
```

If conflict resolution was triggered, add:

```yaml
escalation:
  triggered: true
  stage: 1
  escalation_model: opus
  escalation_verdict: REJECT
  escalation_rationale: "The security reviewer identified a genuine OWASP A05 issue..."
  stage2_triggered: true
  human_decision: "Option A — re-dispatch implementer with security finding"
  human_timestamp: "2026-03-18T14:45:22Z"
```

---

## Examples

### Example 1: Weighted Voting — Clean Pass

**Context:** Story 07 (order history API) reviewed by 3 QA agents in careful mode.

```
correctness-qa:  APPROVE  confidence=91  "All 4 acceptance criteria met."
security-qa:     APPROVE  confidence=85  "Proper auth checks, no sensitive data in responses."
performance-qa:  APPROVE  confidence=78  "Paginated. Index on orders.user_id confirmed."
```

Computation:
- weighted_approve = (3*91) + (3*85) + (3*78) = 273 + 255 + 234 = 762
- weighted_reject = 0
- approval_score = 762 / 762 = 1.00

Verdict: APPROVED (unanimous). No escalation.

---

### Example 2: Weighted Voting — Close Call with Minority Concern

**Context:** Story 04 (order creation API) reviewed by 3 QA agents.

```
correctness-qa:  APPROVE  confidence=88  "Criteria met."
security-qa:     REJECT   confidence=91  "No rate limiting on POST /api/orders."
performance-qa:  APPROVE  confidence=74  "No issues found."
```

Computation:
- weighted_approve = (3*88) + (3*74) = 264 + 222 = 486
- weighted_reject = 3*91 = 273
- approval_score = 486 / 759 = 0.640

Verdict: PASSES (64% >= 60%). APPROVED with minority concern noted. Security finding logged and surfaced to orchestrator — it is included in the QA report even though the vote passed.

---

### Example 3: Quorum Check — Architecture Decision

**Context:** Proposal to switch from REST to GraphQL for the API layer. 3-agent quorum.

```
implementer:   DISAGREE  "GraphQL adds resolver complexity not justified by current query patterns."
qa-reviewer:   DISAGREE  "Testing surface increases significantly. Current REST tests are solid."
researcher:    AGREE     "GraphQL is appropriate for this data graph. Alternatives considered."
```

Quorum required: 2 of 3 AGREE. Actual: 1 AGREE. Quorum NOT reached.

Stage 1 escalation to opus: renders DISAGREE (both DISAGREE rationales describe concrete implementation risks).

Stage 2: PAUSE. Human presented with all rationales and escalation verdict. Human selects: "Option C — keep REST for now, revisit at milestone 3."

Decision logged. Architecture decision deferred.

---

### Example 4: Implementer Vote in Mixed Panel

**Context:** Story 09 reviewed by mixed panel (architect + implementer + QA reviewer).

```
architect-agent:   APPROVE  weight=2  confidence=83  "Design is sound."
implementer-agent: APPROVE  weight=1  confidence=90  "Code matches spec."
qa-reviewer:       REJECT   weight=3  confidence=88  "Missing error handling on DB timeout path."
```

Computation:
- weighted_approve = (2*83) + (1*90) = 166 + 90 = 256
- weighted_reject = 3*88 = 264
- total_weight = 520
- approval_score = 256 / 520 = 0.492

Verdict: FAILS threshold (49.2% < 60%). Conflict resolution triggered. Stage 1 escalation dispatched with QA rationale as the primary concern. Escalation verdict: REJECT (DB timeout handling is a correctness issue, not a minor concern). Story re-dispatched with QA feedback.

---

## Configuration

Consensus behavior can be configured in `.maestro/config.yaml`:

```yaml
consensus:
  weighted_voting:
    threshold: 0.60              # approval_score required to pass
    min_confidence: 60           # votes below this are excluded
  quorum:
    default_threshold: 0.667     # 2/3 majority
  conflict_resolution:
    escalation_model_ladder:
      - haiku
      - sonnet
      - opus
    stage2_always_human: true    # always ask human if opus also rejects
```

If no config is present, the defaults in this skill apply.
