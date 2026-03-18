---
name: marketing-automation
description: "Generate ad copy variations, build A/B test frameworks, track campaign performance. Inspired by how Anthropic's marketing team uses Claude Code."
---

# Marketing Automation

Generate ad copy variations at scale, build structured A/B test frameworks, and track campaign performance over time. Handles multi-platform ad creation with character limit enforcement, variation generation from a single brief, and CSV export for direct upload to ad platforms.

## Input

- **brief** — Campaign brief or product description (from `$ARGUMENTS`)
- **platforms** — Target platforms: `google` | `meta` | `linkedin` | `all` (default: `all`)
- **goal** — Campaign objective: `awareness` | `traffic` | `conversions` | `leads`
- **variations** — Number of copy variations to generate (default: 10, max: 50)
- **Optional:** `.maestro/strategy.md` for positioning and audience context
- **Optional:** `.maestro/voice.md` for brand voice guidelines
- **Optional:** existing campaign file for iteration

## Platform Character Limits

Strict enforcement. Every generated variation must fit within these bounds:

| Platform | Element | Max Characters |
|----------|---------|---------------|
| Google Ads | Headline 1 | 30 |
| Google Ads | Headline 2 | 30 |
| Google Ads | Headline 3 | 30 |
| Google Ads | Description 1 | 90 |
| Google Ads | Description 2 | 90 |
| Google Ads | Display URL path | 15 each |
| Meta Ads | Primary text | 125 (recommended) |
| Meta Ads | Headline | 40 |
| Meta Ads | Description | 30 |
| Meta Ads | CTA button | Platform preset |
| LinkedIn Ads | Intro text | 150 (single image) |
| LinkedIn Ads | Headline | 70 |
| LinkedIn Ads | Description | 100 |

Any variation exceeding a limit is flagged and truncated or rewritten. Character count is validated before output.

## Process

### Step 1: Understand the Brief

1. Read the campaign brief from `$ARGUMENTS`.
2. Read `.maestro/strategy.md` if it exists for positioning, audience, and channel context.
3. Read `.maestro/voice.md` if it exists for tone and language guidelines.
4. Extract or infer:
   - **Product/service** being promoted
   - **Key benefit** (one sentence)
   - **Target audience** (who sees this ad)
   - **Differentiator** (why choose this over alternatives)
   - **Goal** (what action the viewer should take)
   - **Constraints** (legal disclaimers, banned words, brand guidelines)

### Step 2: Generate Ad Copy Variations

For each platform, generate the requested number of variations. Use these copy frameworks:

**Framework rotation (cycle through these):**

1. **Problem-Solution** — State the pain, offer the fix
2. **Benefit-Led** — Lead with the outcome the user gets
3. **Social Proof** — Lead with numbers, testimonials, authority
4. **Urgency** — Time-limited or scarcity-driven
5. **Question Hook** — Open with a question the audience asks themselves
6. **Comparison** — Position against the alternative (without naming competitors)
7. **How-To** — Promise a method or approach
8. **Curiosity Gap** — Hint at a revelation or insight

For each variation, produce:

```
Variation [N] — Framework: [name]
  Platform:     [google | meta | linkedin]
  Headline:     [text] ([char count]/[limit])
  Description:  [text] ([char count]/[limit])
  CTA:          [text]
  Display URL:  [path] (Google only)
```

**Quality rules:**
- No two variations should use the same framework consecutively
- Each variation must have a distinct angle (not just word swaps)
- CTAs must be specific actions, not generic ("Start free trial" not "Learn more")
- Avoid superlatives without proof ("Best in class" without data)
- Include at least one number or specific claim per variation when possible

### Step 3: Character Limit Enforcement

After generation, validate every variation:

```
+---------------------------------------------+
| Character Limit Audit                        |
+---------------------------------------------+
  Platform      Element       Count  Limit  Status
  -----------   -----------   -----  -----  ------
  Google Ads    Headline 1    28     30     (ok)
  Google Ads    Headline 2    31     30     (x) OVER
  Google Ads    Description   87     90     (ok)
  Meta Ads      Primary       118    125    (ok)
  Meta Ads      Headline      42     40     (x) OVER
  LinkedIn      Intro         145    150    (ok)
```

Any `(x)` result triggers automatic rewriting of that element. Rewrite must preserve the core message while fitting the limit.

### Step 4: A/B Test Framework

For each campaign, generate a structured A/B test plan:

```markdown
## A/B Test Plan: [Campaign Name]

### Hypothesis
[What we believe will happen and why]

### Test Structure

| Element | Variant A (Control) | Variant B | Variant C |
|---------|-------------------|-----------|-----------|
| Headline | [text] | [text] | [text] |
| Description | [text] | [text] | [text] |
| CTA | [text] | [text] | [text] |
| Image style | [description] | [description] | [description] |

### Variables
- **Isolated variable:** [the one thing that differs between variants]
- **Held constant:** [everything that stays the same]

### Metrics
| Metric | Definition | Target |
|--------|-----------|--------|
| CTR | Click-through rate | > [X]% |
| CPC | Cost per click | < $[X] |
| Conv. Rate | Conversions / clicks | > [X]% |
| CPA | Cost per acquisition | < $[X] |
| ROAS | Revenue / ad spend | > [X]x |

### Timeline
- **Setup:** Day 1
- **Learning phase:** Days 1-7 (no changes)
- **Evaluation:** Day 8 (min. [N] impressions per variant)
- **Decision:** Day 8-10

### Success Criteria
- **Winner declared when:** One variant achieves [X]% higher CTR/Conv with 95% statistical significance
- **Minimum sample size:** [N] impressions per variant
- **If no clear winner:** Extend test by [N] days or test new angles
```

### Step 5: Save Campaign File

Save all outputs to `.maestro/campaigns/{campaign-slug}.md`:

```markdown
---
campaign: "Campaign Name"
status: draft | active | paused | completed
platforms:
  - google
  - meta
  - linkedin
goal: conversions
created: YYYY-MM-DD
updated: YYYY-MM-DD
variations_count: 30
ab_test: true
---

# Campaign: [Name]

## Brief
[Original brief]

## Target Audience
[Extracted audience description]

## Positioning
[Key benefit + differentiator]

## Ad Copy Variations

### Google Ads
[Variations table]

### Meta Ads
[Variations table]

### LinkedIn Ads
[Variations table]

## A/B Test Plan
[Full test plan from Step 4]

## Performance Log
| Date | Platform | Variant | Impressions | Clicks | CTR | Conv | CPA |
|------|----------|---------|-------------|--------|-----|------|-----|
| -- | -- | -- | -- | -- | -- | -- | -- |

## Iteration History
- [Date]: Initial creation, [N] variations generated
```

### Step 6: CSV Export

Generate platform-ready CSV files for bulk upload:

**Google Ads CSV format:**
```csv
Campaign,Ad Group,Headline 1,Headline 2,Headline 3,Description 1,Description 2,Path 1,Path 2,Final URL
[campaign],[group],[h1],[h2],[h3],[d1],[d2],[p1],[p2],[url]
```

**Meta Ads CSV format:**
```csv
Ad Name,Primary Text,Headline,Description,CTA,URL
[name],[primary],[headline],[desc],[cta],[url]
```

Save CSVs to `.maestro/campaigns/{campaign-slug}-{platform}.csv`.

## Performance Analysis

When invoked with an existing campaign file that contains performance data:

### Compare Variants

```
+---------------------------------------------+
| Variant Performance                          |
+---------------------------------------------+
  Variant    Impressions  CTR     CPA     Status
  ---------  ----------   -----   ------  ------
  A (ctrl)   12,500       2.1%    $14.20  baseline
  B          12,800       2.8%    $11.50  (ok) winning
  C          12,300       1.9%    $15.80  (x) underperforming
```

### Identify Winners

Apply these decision rules:
- **Clear winner:** 30%+ improvement over control with 1000+ clicks per variant
- **Marginal winner:** 10-30% improvement, recommend extending test
- **No winner:** Less than 10% difference, recommend new angles

### Suggest Iterations

Based on winning variants, suggest next-round variations:
- Combine winning elements from different variants
- Test new frameworks not yet explored
- Adjust messaging based on which benefits resonated
- Recommend budget reallocation toward winning platforms

## Integration Points

### With Strategy Skill

Reads `.maestro/strategy.md` for:
- Target audience definition (who sees the ads)
- Positioning statement (core message)
- Channel priorities (which platforms to focus on)
- Growth experiments (A/B test hypotheses)

### With Kanban

Campaign tasks can be tracked on the kanban board:
- `draft` — Ad copy being created
- `active` — Campaign running, tracking performance
- `paused` — Campaign paused for review
- `completed` — Campaign ended, results documented

Map campaign milestones to kanban cards:
- "Create ad copy for [campaign]" — In Progress
- "Launch A/B test" — In Review
- "Analyze results" — To Do

### With Content Pipeline

Ad campaigns can link to content created by the content-pipeline skill:
- Blog posts as landing page destinations
- Case studies as social proof in ad copy
- Email sequences as retargeting follow-ups

### With Content Validator

Validates campaign files against the campaign output contract:
- Frontmatter schema compliance
- Required sections present
- Character limits respected
- CSV format correctness

## Output Contract

```yaml
output_contract:
  file: ".maestro/campaigns/{campaign-slug}.md"
  frontmatter:
    campaign: string
    status: "enum(draft,active,paused,completed)"
    platforms: "list(enum(google,meta,linkedin))"
    goal: "enum(awareness,traffic,conversions,leads)"
    created: date
    updated: date
    variations_count: integer
    ab_test: boolean
  required_sections:
    - "# Campaign:"
    - "## Brief"
    - "## Target Audience"
    - "## Ad Copy Variations"
    - "## A/B Test Plan"
    - "## Performance Log"
    - "## Iteration History"
  min_words: 500
  max_words: 5000
```

## Error Handling

| Error | Action |
|-------|--------|
| No brief provided | Ask user for product description and goal |
| Strategy file missing | Generate copy without positioning context, warn user |
| Character limit exceeded after rewrite | Flag the specific element, ask user to provide shorter alternative |
| CSV export path conflict | Append timestamp to filename |
| Performance data incomplete | Show available metrics, mark missing as "--" |
| Platform not supported | Warn and skip, generate for supported platforms only |

## Example Invocation

```
/marketing-automation "Maestro: AI-powered project orchestration for Claude Code. Turns feature requests into shipped code with autonomous planning, implementation, and QA." --platforms all --goal conversions --variations 15
```

Output:
```
[maestro] Campaign brief analyzed
[maestro] Generating 15 variations per platform (45 total)
[maestro] Character limit audit: 43/45 passing (2 rewritten)
[maestro] A/B test plan: 3 variants, CTR + CPA metrics
[maestro] Saved: .maestro/campaigns/maestro-launch.md
[maestro] Exported: maestro-launch-google.csv, maestro-launch-meta.csv, maestro-launch-linkedin.csv
```
