---
name: classifier
description: "Auto-classify user requests and route to the appropriate Maestro layer (vision, tactics, execution)"
effort: low
maxTurns: 3
disallowedTools:
  - Write
  - Edit
---

# Classifier

Auto-classifies user intent from a natural-language request and routes to the correct Maestro orchestration layer and skill(s).

## Input

The user's feature description or request, provided via `$ARGUMENTS`.

## Classification Rules

Analyze the request against four layers. Match the **primary intent**, not incidental keywords.

### Layer 1 — Vision & Strategy

**Trigger words:** competitors, market, research, strategy, marketing, growth, vision, audience, branding, positioning, SEO strategy, content strategy, monetization strategy, competitive analysis, go-to-market, product-market fit, user personas, target market.

**Route to:** `research`, `strategy`, or both.

**Output artifacts:** `.maestro/vision.md`, `.maestro/research.md`, `.maestro/strategy.md`

### Layer 2 — Tactics & Architecture

**Trigger words:** architecture, design, system design, tech stack, data model, schema, database, API design, component tree, infrastructure, deployment, caching strategy, migration plan, technical decision.

**Route to:** `architecture` skill (and optionally `decompose` for implementation planning).

**Output artifacts:** `.maestro/architecture.md`, `.maestro/stories/`

### Layer 3 — Execution

**Trigger words:** build, implement, create, add, fix, refactor, update, migrate, test, ship, deploy — or any concrete development task that does not fit Layer 1 or Layer 2.

**Route to:** `decompose` (to break into stories) then `dev-loop` (to execute).

**Output artifacts:** code, tests, commits.

### Layer 4 — Knowledge Work

**Trigger words:** write, blog, article, content, copy, ad, campaign, email, newsletter, report, case study, whitepaper, presentation, social media, SEO, keywords, marketing, growth, funnel, conversion, A/B test, scenario, simulation, what-if, content calendar, editorial.

**Route to:** Appropriate knowledge work skill based on specific intent:

| Intent Pattern | Skill | Output |
|---------------|-------|--------|
| "Write a blog/article/post about..." | `content-pipeline` | `.maestro/content/` |
| "Create ad copy/variations for..." | `marketing-automation` | `.maestro/campaigns/` |
| "Build a content calendar..." | `content-pipeline` (calendar mode) | `.maestro/content-calendar.md` |
| "Run a scenario analysis..." | `scenario-planning` | `.maestro/scenarios/` |
| "Analyze campaign performance..." | `marketing-automation` (analysis mode) | Report output |

**Validation:** Uses `content-validator` and `output-contracts` instead of code tests.

**Output artifacts:** `.maestro/content/`, `.maestro/campaigns/`, `.maestro/scenarios/`

## Scope Detection

After classifying the layer, assess the scope of the request:

| Signal | Scope | Recommendation |
|--------|-------|----------------|
| Single concern, 1-3 files, clear boundary | **Single feature** | Route directly to the classified layer |
| Multiple concerns, 4-10 files, one milestone | **Multi-story feature** | Route to `decompose` then `dev-loop` |
| Multiple milestones, new product, full system, 10+ files | **Magnum Opus candidate** | Suggest autonomous mode |
| Content/marketing task, no code involved | **Knowledge work** | Route to Layer 4 skills |

If scope seems too large for a single feature, respond:

> This sounds like a multi-milestone project. Would you like to use `/maestro opus` for the full autonomous experience? It includes a deep interview, research sprint, architecture design, and iterative build cycles with checkpoints.

## Output Format

Present the classification to the user:

```
Layer: [1/2/3/4] — [Vision & Strategy / Tactics & Architecture / Execution / Knowledge Work]
Scope: [single feature / multi-story / magnum opus candidate]
Skills: [comma-separated list of skills to invoke]
Suggested mode: [yolo / checkpoint / careful]
```

Then invoke the recommended skill(s) unless the user overrides.

## Mode Suggestion Heuristic

- **yolo** — Small, well-understood changes (bug fixes, styling tweaks, single-file additions)
- **checkpoint** — Standard features (2-5 stories, moderate complexity)
- **careful** — Large features, unfamiliar territory, production-critical, or user explicitly wants oversight
