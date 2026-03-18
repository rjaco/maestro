---
name: gcr-loop
description: "Generator-Critic-Refiner pipeline. Produces high-quality artifacts through iterative generation, structured critique against a rubric, and targeted refinement. Applicable to code, documentation, architecture, and strategy."
---

# Generator-Critic-Refiner Loop

A 3-agent pipeline that produces high-quality artifacts through structured iteration. Generator creates, Critic evaluates against a rubric, Refiner improves. Repeat until pass or max iterations.

## The 3 Agents

**Generator** — Creates the initial artifact from task description, constraints, output format, and the rubric (so generation targets evaluation criteria from the start). Produces a complete artifact, not a draft pending feedback.

**Critic** — Always uses **sonnet**. Evaluates the artifact against every rubric criterion explicitly. Produces structured critique — not free-form commentary. Identifies what fails and why; does not rewrite.

**Refiner** — Uses the same model as the Generator. Receives current artifact, full critique, rubric, and prior versions. Preserves passing sections; improves only what the Critic flagged.

## Rubric Format

```markdown
## Rubric: [artifact type]

### Required (must pass all)
- [ ] [Criterion 1]
- [ ] [Criterion 2]

### Quality (score 0-3 each)
- Clarity: [0-3]
- Completeness: [0-3]
- Correctness: [0-3]

### Pass threshold
All required + quality average >= 2.0
```

Scores: 0 = missing/broken, 1 = deficient, 2 = adequate, 3 = excellent.

## Loop Behavior

Default max iterations: **3** (configurable per invocation).

```
iteration = 0
loop:
  artifact = Generator (iteration 0) or Refiner (iteration > 0)
  critique = Critic.evaluate(artifact, rubric, prior_critiques)
  iteration += 1
  if critique.passes: return artifact          # DONE
  if iteration >= max_iterations: ESCALATE     # show user, offer options
```

Each iteration records: version, pass/fail verdict, required criteria status, quality scores, delta from prior iteration. On escalation, preserve the best-scoring version and ask the user: accept, extend iterations, or abort.

## Pre-Built Rubrics

### Code
```markdown
## Rubric: Code
### Required
- [ ] All existing tests pass without modification
- [ ] New tests cover the acceptance criteria
- [ ] No security vulnerabilities (injection, secrets, unsafe deserialization)
- [ ] Follows project conventions (dna.md naming, structure, import patterns)
### Quality (score 0-3)
- Correctness: Logic sound, edge cases handled
- Clarity: Descriptive names, readable without comments
- Completeness: All AC addressed, no shipped TODOs
- Testability: Side effects isolated, code is testable
### Pass threshold: all required + quality average >= 2.0
```

### Documentation
```markdown
## Rubric: Documentation
### Required
- [ ] All public APIs or features documented
- [ ] Code examples are accurate and runnable
- [ ] Prerequisites and setup steps are explicit
- [ ] Audience is scoped (who this is for, assumed knowledge)
### Quality (score 0-3)
- Clarity: A new reader can follow without prior context
- Completeness: No gaps where a reader would be stuck
- Accuracy: No outdated or incorrect information
- Structure: Logical flow, appropriate headings, scannable
### Pass threshold: all required + quality average >= 2.0
```

### Architecture
```markdown
## Rubric: Architecture
### Required
- [ ] Addresses all functional requirements from the feature spec
- [ ] No contradictions with existing constraints (dna.md, CLAUDE.md)
- [ ] Data model supports all identified query patterns
- [ ] Security model is explicit (auth, authorization, data boundaries)
### Quality (score 0-3)
- Scalability: Accommodates projected growth without fundamental rework
- Maintainability: Components decoupled, responsibilities clear
- Pattern adherence: Follows project patterns; deviations are justified
- Feasibility: Implementable by the team within stated constraints
### Pass threshold: all required + quality average >= 2.0
```

### Strategy
```markdown
## Rubric: Strategy
### Required
- [ ] Every recommendation traces to a research finding or stated constraint
- [ ] Success metrics are specific and measurable (not "increase traffic")
- [ ] Prioritization is explicit — not all actions ranked equally
- [ ] Feasibility is addressed — effort and timeline are grounded in reality
### Quality (score 0-3)
- Actionability: Team can execute without further clarification
- Evidence: Claims backed by data, research, or explicit reasoning
- Measurability: Progress trackable against defined KPIs
- Coherence: Tactics reinforce positioning; no internal contradictions
### Pass threshold: all required + quality average >= 2.0
```

## Model Routing

| Role | Model | Rationale |
|------|-------|-----------|
| Generator | Matches task complexity (from delegation) | Complex → opus, simple → haiku |
| Critic | Always **sonnet** | Consistent rubric evaluation; not creative work |
| Refiner | Same model as Generator | Refinement needs equal capability as generation |

If the story has failed 2+ QA cycles before GCR invocation, escalate Generator to opus.

## Custom Rubrics

Store project-specific rubrics in `.maestro/rubrics/<name>.md` using the standard format above. Reference by name in a story spec:

```yaml
gcr_rubric: api-endpoint   # loads .maestro/rubrics/api-endpoint.md
```

## Integration Points

| Skill | How GCR Is Used |
|-------|----------------|
| `dev-loop` | Story with `gcr: true` routes Phase 3 IMPLEMENT through GCR; Generator = implementer, Critic = QA reviewer. SELF-HEAL runs after GCR PASS. |
| `content-pipeline` | Steps 3-5 (Draft → SEO → Editorial) map to Generator → Critic → Refiner using the Documentation rubric. |
| `strategy` | Step 8 (Write Strategy Document) quality-gates via GCR with the Strategy rubric before saving to `.maestro/strategy.md`. |
| `architecture` | Step 7 (Write Architecture Document) quality-gates via GCR with the Architecture rubric before committing to `.maestro/architecture.md`. |

## Critic Output Format

The Critic must produce a structured response the orchestrator can parse:

```
## Critique: [type] v[N]
### Required Criteria
- [x] Criterion A — PASS
- [ ] Criterion B — FAIL: reason
### Quality Scores
- Correctness: 2 — sound logic, empty input unhandled
- Clarity: 3 — readable, descriptive names
- Completeness: 1 — error handling missing in fetch wrapper
- Testability: 2 — side effects mostly isolated
### Summary
Quality average: 2.0 | Required passing: 1/2 | Verdict: FAIL
### Refiner Instructions
Fix: (1) add tests for criteria 3-5; (2) handle empty input in parseResponse()
Preserve: authentication logic, data model, component structure (approved)
```

The `Refiner Instructions` block is the direct handoff — specific, scoped, explicit about what not to touch.
