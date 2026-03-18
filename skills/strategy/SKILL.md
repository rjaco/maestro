---
name: strategy
description: "Marketing and growth strategy planning. Produces .maestro/strategy.md with positioning, channels, content strategy, and KPI targets."
---

# Strategy

Produces a marketing and growth strategy document informed by research findings and project vision. Translates competitive intelligence into actionable positioning, channel priorities, content plans, and measurable KPI targets.

## Input

- `.maestro/vision.md` — Project vision and target audience (required)
- `.maestro/research.md` — Competitive research findings (required)
- `.maestro/dna.md` — Project DNA for technical context (optional)
- `$ARGUMENTS` — Specific strategy focus or constraints (optional)

## Process

### Step 1: Read Context

1. Read `.maestro/vision.md` to understand purpose, target audience, value proposition, success criteria, and constraints.
2. Read `.maestro/research.md` to understand competitive landscape, feature gaps, SEO patterns, and technical trends.
3. If `.maestro/dna.md` exists, read it to understand technical capabilities and limitations that affect strategy.

If either `vision.md` or `research.md` is missing, inform the user and suggest running the appropriate skill first.

### Step 2: Audience Analysis

Define the target audience with specificity:

- **Primary persona** — Who benefits most? What is their current workflow or pain point?
- **Secondary persona** — Who else uses this? How do their needs differ?
- **Anti-persona** — Who is this explicitly NOT for? Knowing this prevents scope creep.
- **Acquisition context** — How does the audience currently discover solutions? Search, social, referral, communities?

### Step 3: Positioning

Craft a positioning statement using this framework:

> For [target audience] who [need/pain point], [product] is a [category] that [key benefit]. Unlike [competitors], we [differentiator].

Validate the positioning against research findings. The differentiator must be something competitors genuinely lack or do poorly, not an aspirational claim.

### Step 4: Channel Priorities

Rank channels by expected impact for this specific project. Do not recommend all channels equally — prioritize ruthlessly.

| Priority | Channel | Rationale | Effort | Expected Impact |
|----------|---------|-----------|--------|----------------|
| 1 | [channel] | [why this channel fits the audience] | [low/med/high] | [expected outcome] |
| 2 | [channel] | ... | ... | ... |
| 3 | [channel] | ... | ... | ... |

Common channels to evaluate:
- **SEO** — Organic search (content pages, programmatic SEO, structured data)
- **Content marketing** — Blog, guides, comparisons, tools
- **Social media** — Platform-specific (which ones, what format)
- **Paid acquisition** — Google Ads, social ads (when organic is insufficient)
- **Community** — Forums, Discord, Reddit, developer communities
- **Partnerships** — Integrations, co-marketing, affiliates
- **Email** — Newsletter, drip campaigns, re-engagement

### Step 5: Content Strategy

Based on channel priorities, define:

1. **Content pillars** — 3-5 core topics the project owns.
2. **Content types** — Which formats (articles, tools, comparisons, videos, infographics).
3. **Content calendar outline** — Monthly themes or quarterly focus areas.
4. **SEO keyword clusters** — Based on research findings, group target keywords by intent (informational, transactional, navigational).
5. **Content gap analysis** — What competitors cover that we should cover better.

### Step 6: KPI Targets

Define measurable targets across three timeframes:

| KPI | 30 Days | 90 Days | 180 Days |
|-----|---------|---------|----------|
| Organic traffic | ... | ... | ... |
| Indexed pages | ... | ... | ... |
| Conversion rate | ... | ... | ... |
| [Domain-specific KPI] | ... | ... | ... |

KPIs must be specific and measurable. Avoid vanity metrics. Tie each KPI to a channel or strategy initiative.

### Step 7: Growth Experiments

Propose 3-5 concrete experiments to validate strategy assumptions:

For each experiment:
- **Hypothesis** — What we believe and why
- **Test** — What we will do to validate
- **Metric** — What we measure
- **Timeline** — How long the experiment runs
- **Decision criteria** — At what threshold do we scale, iterate, or kill

### Step 8: Write Strategy Document

Write `.maestro/strategy.md` with all sections from Steps 2-7. Be specific throughout — no generic marketing advice. Every recommendation should trace back to a research finding or vision constraint.

## Output

- `.maestro/strategy.md` — Complete strategy document
- Strategy findings inform `architecture` decisions (e.g., SEO requirements shape rendering strategy, content strategy shapes data model)

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/strategy.md"
  required_sections:
    - "## Positioning"
    - "## Channels"
    - "## Content Strategy"
    - "## KPIs"
    - "## Growth Experiments"
  min_words: 500
```
