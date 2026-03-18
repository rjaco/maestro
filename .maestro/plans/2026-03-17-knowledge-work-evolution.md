---
feature: "Evolve Maestro from code-only to universal knowledge work orchestrator"
created: "2026-03-17"
status: roadmap
priority: critical
---

# Maestro Evolution: Code + Knowledge Work

## Why

Anthropic's own marketing team uses Claude Code for non-code tasks (ad copy at 30s vs 30min, 100+ hours/month freed). Maestro's three-layer architecture (Vision → Tactics → Execution) maps perfectly to ANY structured workflow, not just code.

The dev-loop's 7 phases need ONE change: **validation doesn't require test suites**. For marketing/content/research, validation = format checks + cross-references + quality signals.

## The Change

### Current: Code-Only Execution

```
Classifier → Decompose → Dev-Loop:
  VALIDATE (deps exist)
  DELEGATE (context package)
  IMPLEMENT (write code)
  SELF-HEAL (tsc, lint, tests)
  QA REVIEW (code review)
  GIT CRAFT (commit)
  CHECKPOINT
```

### Evolved: Universal Execution

```
Classifier → Detect Work Type → Decompose → Execution Loop:

  If code:     Dev-Loop (tests, tsc, lint)         ← already works
  If content:  Content-Loop (SEO, readability)      ← NEW
  If research: Research-Loop (sources, synthesis)    ← NEW
  If strategy: Strategy-Loop (metrics, feasibility)  ← NEW
  If marketing: Marketing-Loop (copy, channels)      ← NEW
```

Each loop uses the SAME 7-phase structure but with **different validation**:

| Phase | Code | Content | Research | Strategy |
|-------|------|---------|----------|----------|
| VALIDATE | deps exist | topic defined | questions defined | goals defined |
| DELEGATE | code context | audience + tone | search queries | market data |
| IMPLEMENT | write code | write content | run searches | build framework |
| SELF-HEAL | tsc/lint/test | readability/SEO/links | source quality | feasibility |
| QA REVIEW | code review | editorial review | fact-check | peer review |
| GIT CRAFT | commit | save to vault | save to research/ | save to strategy/ |
| CHECKPOINT | user reviews code | user reviews content | user reviews findings | user reviews plan |

## New Skills Needed

### Content Skills
- `content-pipeline/SKILL.md` — Blog posts, case studies, email campaigns
- `content-validator/SKILL.md` — Readability, SEO signals, heading hierarchy, link health
- `content-calendar/SKILL.md` — Monthly content planning with keyword clustering

### Research Skills (enhance existing)
- `research-synthesis/SKILL.md` — Combine multiple research runs into actionable brief
- `competitive-matrix/SKILL.md` — Auto-updating competitor comparison table

### Marketing Skills
- `marketing-automation/SKILL.md` — Ad copy variations, A/B test frameworks
- `campaign-tracker/SKILL.md` — Track campaign performance in .maestro/campaigns/

### Validation Skills
- `markdown-validator/SKILL.md` — Frontmatter schema, structure, cross-references
- `output-contracts/SKILL.md` — Each skill declares expected output format, validator checks

### New Profiles
- `profiles/content-marketer.md` — Blog, SEO, email expertise
- `profiles/growth-marketer.md` — Ads, funnels, analytics expertise
- `profiles/researcher.md` — Already exists, enhance for non-code research
- `profiles/project-manager.md` — Task orchestration, scheduling, reporting

## Classifier Enhancement

The classifier skill needs to detect work type from the description:

```
"Write a blog post about..." → content
"Research competitors in..." → research
"Build a marketing strategy..." → strategy
"Create ad copy for..." → marketing
"Add user authentication" → code (default)
```

Add to `plugins/maestro/skills/classifier/SKILL.md`:

```
### Layer 4 — Knowledge Work

Trigger words: write, blog, article, content, copy, ad, campaign,
email, newsletter, report, analysis, brief, case study, whitepaper,
presentation, deck, social media, SEO, keywords

Route to: content-pipeline, marketing-automation, or research-synthesis
depending on specific intent.
```

## Validation Without Tests

### Markdown Validator Checks:
1. YAML frontmatter present and valid
2. Required sections exist (per skill's output contract)
3. Heading hierarchy is correct (H1 → H2 → H3, no skips)
4. Internal links resolve (cross-file references)
5. Word count within target range
6. Reading level appropriate for audience
7. SEO signals: title tag, meta description, keyword density
8. No broken external links (optional, uses curl)

### Output Contract Pattern:
Each skill declares what its output must contain:

```yaml
# In SKILL.md frontmatter
output_contract:
  file: ".maestro/content/{date}-{slug}.md"
  required_sections:
    - "## Summary"
    - "## Content"
    - "## SEO Metadata"
  frontmatter:
    - type: string
    - status: enum(draft, review, ready)
    - target_audience: string
  min_words: 800
  max_words: 3000
```

The QA reviewer checks against this contract instead of running tests.

## Implementation Priority

1. **Classifier enhancement** — detect code vs knowledge work (small change)
2. **Markdown validator skill** — universal validation without tests
3. **Output contracts** — add to existing skills, create pattern for new ones
4. **Content pipeline** — first non-code execution skill
5. **Marketing automation** — ad copy + campaign tracking
6. **New profiles** — content-marketer, growth-marketer, project-manager

## What This Enables

- `/maestro "Write a blog post about our new feature"` → researches, writes, validates SEO, saves to vault
- `/maestro "Analyze 5 competitors and build a positioning strategy"` → parallel research, synthesis, strategy doc
- `/maestro "Create a 3-month content calendar"` → keyword research, topic clustering, calendar with dates
- `/maestro "Generate 50 ad copy variations for our landing page"` → variations, A/B test plan, CSV export
- `/maestro opus "Launch marketing for our SaaS product"` → full autonomous marketing engine

## Anthropic Precedent

Anthropic's own marketing team does exactly this with Claude Code:
- 100+ ad creative variations per session
- Case studies from 2.5 hours to 30 minutes
- 100+ hours/month freed across influencer, customer, digital, product, and partner marketing
- Non-coders building Figma plugins and Google Ads workflows

Maestro would formalize and automate these workflows with the same quality gates that make code development reliable.
