---
name: plan-intelligence
description: "Smarter-than-native planning intelligence — adaptive questioning, plan quality scoring, cross-plan learning, and plan templates."
---

# Plan Intelligence

Elevates Maestro's planning above Claude Code's native `/plan` by reading project context before asking questions, scoring every plan objectively, learning from past plan accuracy, and providing pre-built templates for common patterns.

## When to Use

- Invoked automatically during `/maestro plan` to score the plan and generate adaptive questions
- Invoked by `/maestro plan --deep` for full adaptive interview + consensus architecture
- Invoked by `/maestro` at the start of Step 9 (decompose) to check for matching saved plans

---

## Module 1: Adaptive Question Selection

### Context Gathering

Before generating interview questions, read these sources in order:

1. **`.maestro/dna.md`** — Project type, stack, conventions, patterns
2. **`.maestro/knowledge-graph.md`** (if exists) — Hub files (PageRank >= 0.6) that are central to the codebase
3. **`.maestro/memory/`** (if exists) — Prior decisions recorded during past sessions
4. **`.maestro/config.yaml`** — Integration settings, model preferences

From these sources, derive:

```
PROJECT_TYPE    = API | UI | CLI | Library | FullStack | Mobile | DataPipeline | Unknown
HUB_FILES       = [files with PageRank >= 0.6 from knowledge-graph]
PRIOR_DECISIONS = [relevant decisions from memory/ matching the description]
CONVENTIONS     = [naming, patterns, testing style from dna.md]
AUTH_PRESENT    = true if auth middleware detected in dna.md
EXTERNAL_APIS   = [list of external services from dna.md]
```

### Question Pool by Project Type

**API projects — select 3-5:**
- "Which API layer does this touch? (REST/GraphQL/gRPC)"
- "Does this endpoint require authentication? How should it interact with the existing auth middleware?"
- "What's the expected request/response shape?"
- "Should this be versioned? (v1, v2, etc.)"
- "Are there rate-limiting or pagination requirements?"
- "What's the error contract? (codes, messages, retry behavior)"
- "Will this be called by internal services, external clients, or both?"

**UI projects — select 3-5:**
- "What breakpoints does this need to support? (mobile/tablet/desktop)"
- "Should this follow the existing component library patterns?"
- "Is there a loading, empty, and error state to design?"
- "Does this component need to be accessible? (WCAG level)"
- "Should it be server-rendered or client-only?"
- "Does it need animation? (describe transitions)"
- "What data does it need — prop-driven, fetched, or from global state?"

**CLI projects — select 3-5:**
- "What's the command signature? (flags, positional args)"
- "Should it follow the existing command style from dna.md?"
- "What's the expected exit code behavior?"
- "Does it need interactive prompts or is it fully scriptable?"
- "What should happen on invalid input?"

**Library projects — select 3-5:**
- "What's the public API surface? (functions, classes, types)"
- "Should this be tree-shakeable?"
- "What runtime environments need to be supported? (Node, browser, both)"
- "Breaking change or additive? How does it affect semver?"
- "Does it need to be documented in JSDoc/TSDoc?"

**Hub-file-aware questions (inject when feature touches a hub file):**
- "This feature touches `[hub_file]` — a high-centrality file. How should changes be backward-compatible?"
- "The auth middleware (`[file]`) is central to this codebase. How does this feature interact with it?"
- "The existing `[pattern]` pattern (used in N places) — should this feature follow it or deviate?"

**Prior-decision-aware questions (inject when relevant decisions found):**
- "A prior decision on [date] established [decision]. Does this feature build on it, modify it, or work around it?"
- "Previously we chose [approach] for [similar problem]. Should we be consistent here?"

### Question Selection Algorithm

```
questions = []

# Start with project-type-appropriate pool
pool = question_pool[PROJECT_TYPE]

# Inject hub-file questions if hub files are relevant to the description
for each hub_file in HUB_FILES:
    if description mentions or implies hub_file:
        questions.append(hub_file_question(hub_file))

# Inject prior-decision questions if memory has relevant context
for each decision in PRIOR_DECISIONS:
    if semantic_relevance(decision, description) > 0.7:
        questions.append(prior_decision_question(decision))

# Fill remaining slots from type pool
remaining_slots = max(3, 5 - len(questions))
questions.extend(select_from_pool(pool, remaining_slots))

# Cap at 5
return questions[:5]
```

### Adaptive Question Display

```
[maestro] I've read your project context. Here are targeted questions for this feature.

(i) Hub files detected: [file1], [file2] — these are critical to your codebase.
(i) Prior decision: [summary from memory, if found]

Questions:
1. [question 1]
2. [question 2]
3. [question 3]
```

---

## Module 2: Plan Quality Scoring

Score every plan on 5 dimensions before presenting for approval. If the score is below 0.8, auto-improve and re-score.

### Dimensions

**1. Completeness (weight: 0.25)**

Every requirement from Phase 1 must map to at least one story.

```
score = (requirements_with_coverage / total_requirements)
```

Check:
- Count distinct requirements from the requirements summary
- For each requirement, check if at least one story's acceptance criteria address it
- Flag uncovered requirements

**2. Feasibility (weight: 0.25)**

Referenced files must exist. Dependencies must be available.

```
score = (valid_references / total_references)
```

Check:
- Every file listed in stories under "Modify" or "Reference" — does it exist on disk?
- Every external dependency mentioned — is it in package.json / go.mod / requirements.txt?
- Story dependencies — is the dependency graph acyclic?

**3. Testability (weight: 0.20)**

Every story must have BDD-style acceptance criteria.

```
score = (stories_with_bdd_criteria / total_stories)
```

BDD criteria format: `Given [context], When [action], Then [outcome]`

Check:
- Each story has at least one acceptance criterion
- Each criterion is specific and verifiable (not vague: "should work well")
- At least one criterion per story is in BDD format

**4. Cost Efficiency (weight: 0.15)**

Model recommendations must match story complexity.

```
score = 1.0 - (mismatched_stories / total_stories)
```

Rules:
- Simple stories (< 3 files, well-known pattern) → sonnet
- Medium stories (3-6 files, some inference needed) → sonnet
- Complex stories (7+ files, novel pattern, security-critical, hub-file changes) → opus
- Penalize: opus assigned to simple stories (over-engineered) or sonnet to complex stories (under-resourced)

**5. Risk Coverage (weight: 0.15)**

Edge cases must be identified. Hub files must be flagged.

```
score = (risks_identified / expected_risks)
```

Check:
- Does any story touch a hub file? If yes, is it flagged as high-risk with opus recommended?
- Are there error/failure cases mentioned in acceptance criteria?
- If the feature involves external APIs, is there a story or criterion for error handling?
- If the feature involves migrations, is there a rollback story or criterion?

### Scoring Output

```
+---------------------------------------------+
| Plan Quality Score                          |
+---------------------------------------------+
  Completeness    [0.0-1.0]  (weight 25%)
  Feasibility     [0.0-1.0]  (weight 25%)
  Testability     [0.0-1.0]  (weight 20%)
  Cost Efficiency [0.0-1.0]  (weight 15%)
  Risk Coverage   [0.0-1.0]  (weight 15%)

  Weighted Score  [0.0-1.0]

  (ok) Score >= 0.8: Plan approved for presentation
  (!)  Score < 0.8: Auto-improving plan...
```

### Auto-Improvement Loop

If `weighted_score < 0.8`:

1. Identify lowest-scoring dimensions
2. For each failing dimension, apply fixes:
   - **Completeness < 0.7** — Add stories for uncovered requirements
   - **Feasibility < 0.7** — Correct file paths, add dependency story if needed
   - **Testability < 0.7** — Rewrite vague criteria in BDD format
   - **Cost Efficiency < 0.7** — Reassign model recommendations
   - **Risk Coverage < 0.7** — Add error handling criteria, flag hub files
3. Re-score. Report delta.
4. If score still < 0.8 after one auto-improvement pass: present to user with issues noted, do not block.

```
[maestro] Auto-improved plan:
  - Added "Error handling" acceptance criterion to story 3
  - Changed model: story 2 sonnet → opus (touches auth hub file)
  - Added missing test story for: [requirement X]

  New score: 0.83 — approved.
```

---

## Module 3: Cross-Plan Learning

After a plan is fully executed (all stories complete, session ends with `phase: completed`):

### Step 1: Collect Actuals

Read `.maestro/state.local.md` for:
- `total_stories` (actual)
- `token_spend` (actual)
- Per-story: QA pass/fail, self_heal count

Read all story files in `.maestro/stories/` for:
- `estimated_tokens` per story (predicted)

### Step 2: Compare Predicted vs Actual

```
story_count_accuracy  = 1 - abs(predicted_stories - actual_stories) / predicted_stories
cost_accuracy         = 1 - abs(predicted_cost - actual_cost) / predicted_cost
qa_first_pass_rate    = stories_qa_passed_first_try / total_stories
self_heal_rate        = stories_needed_self_heal / total_stories
```

### Step 3: Store in `.maestro/memory/plan-accuracy.md`

Append a row to the accuracy log:

```markdown
---
type: plan-accuracy-log
---

# Plan Accuracy Log

| Date | Feature | Stories (P/A) | Cost (P/A) | QA 1st-Pass | Self-Heal Rate | Quality Score |
|------|---------|---------------|------------|-------------|----------------|---------------|
| 2026-03-19 | [feature] | 4/6 (+50%) | $0.12/$0.19 (+58%) | 83% | 17% | 0.82 |
```

### Step 4: Calibration

When generating future forecasts, apply calibration multipliers derived from the accuracy log:

```
if story_count_accuracy consistently < 0.8:
    story_multiplier = median(actual/predicted) for last 5 plans
    FORECASTED_STORIES = decomposed_stories * story_multiplier

if cost_accuracy consistently < 0.8:
    cost_multiplier = median(actual/predicted) for last 5 plans
    FORECASTED_COST = estimated_cost * cost_multiplier
```

Display calibration note if multiplier != 1.0:

```
(i) Based on 5 past plans, story count is typically 40% higher than initial estimate.
    Adjusted forecast: ~7 stories (raw estimate: 5).
```

---

## Module 4: Plan Templates

For common patterns, pre-fill story decomposition from templates in `.maestro/templates/plans/`.

### Template Selection

Detect pattern from description keywords:

| Keywords | Template |
|----------|----------|
| "CRUD", "create/read/update/delete", "manage [resource]" | `crud-feature.md` |
| "endpoint", "route", "API", "REST", "GraphQL" | `api-endpoint.md` |
| "component", "page", "UI", "widget", "form" | `ui-component.md` |
| "migration", "schema change", "data move", "rename table" | `migration.md` |
| "refactor", "clean up", "restructure", "extract" | `refactor.md` |

If a template matches, present it:

```
[maestro] Pattern detected: CRUD feature
          Template found: .maestro/templates/plans/crud-feature.md

          Use template? This will pre-populate stories based on the standard CRUD pattern.
```

### Template: `crud-feature.md`

Standard 5-story CRUD decomposition:

```markdown
---
template: crud-feature
story_count: 5
---

Stories:
1. Data model — Define schema, migrations, types
2. Repository layer — CRUD operations, query helpers
3. API endpoints — REST routes with validation
4. UI — List, create, edit, delete views
5. Tests — Integration tests for all endpoints + unit tests for model
```

### Template: `api-endpoint.md`

Standard 3-story API route:

```markdown
---
template: api-endpoint
story_count: 3
---

Stories:
1. Handler — Route definition, validation, response shape
2. Service layer — Business logic, data access
3. Tests — Happy path, auth failure, validation errors, edge cases
```

### Template: `ui-component.md`

Standard 3-story UI component:

```markdown
---
template: ui-component
story_count: 3
---

Stories:
1. Component — Markup, styles, accessibility
2. Data integration — Fetch/mutation hooks, loading/error/empty states
3. Tests — Render tests, interaction tests, accessibility audit
```

### Template: `migration.md`

Standard 4-story migration:

```markdown
---
template: migration
story_count: 4
---

Stories:
1. Schema change — Migration script (up + down)
2. Data migration — Transform existing data, validate counts
3. Code updates — Update all code referencing the old schema
4. Validation — Smoke test against staging data, verify rollback works
```

### Template: `refactor.md`

Standard 3-story refactor:

```markdown
---
template: refactor
story_count: 3
---

Stories:
1. Safety net — Write characterization tests for current behavior
2. Refactor — Restructure code without changing behavior (tests stay green)
3. Cleanup — Remove dead code, update docs, add new tests for improved design
```

---

## Integration Points

| Caller | Integration |
|--------|-------------|
| `/maestro plan` Phase 1 | Call Module 1 (adaptive questions) before interview |
| `/maestro plan` Phase 5 | Call Module 2 (quality scoring) during review |
| `/maestro plan` Phase 4 | Call Module 4 (templates) before decomposition |
| `/maestro` Step 9 | Call Module 4 template detection on DESCRIPTION |
| Session complete | Call Module 3 (cross-plan learning) after all stories done |
| Future forecasts | Read `.maestro/memory/plan-accuracy.md` for calibration |

## Output Files

| File | Purpose |
|------|---------|
| `.maestro/memory/plan-accuracy.md` | Cross-plan accuracy log |
| `.maestro/templates/plans/crud-feature.md` | CRUD template |
| `.maestro/templates/plans/api-endpoint.md` | API endpoint template |
| `.maestro/templates/plans/ui-component.md` | UI component template |
| `.maestro/templates/plans/migration.md` | Migration template |
| `.maestro/templates/plans/refactor.md` | Refactor template |
