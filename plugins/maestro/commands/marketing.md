---
name: marketing
description: "Generate ad copy variations, run A/B test frameworks, and analyze campaign performance across Google, Meta, and LinkedIn"
argument-hint: "[generate <platform>|ab-test|analyze]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
  - AskUserQuestion
---

# Maestro Marketing

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ██████╗ ██╗  ██╗███████╗████████╗██╗███╗   ██╗ ██████╗
████╗ ████║██╔══██╗██╔══██╗██║ ██╔╝██╔════╝╚══██╔══╝██║████╗  ██║██╔════╝
██╔████╔██║███████║██████╔╝█████╔╝ █████╗     ██║   ██║██╔██╗ ██║██║  ███╗
██║╚██╔╝██║██╔══██║██╔══██╗██╔═██╗ ██╔══╝     ██║   ██║██║╚██╗██║██║   ██║
██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██╗███████╗   ██║   ██║██║ ╚████║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝╚═╝  ╚═══╝ ╚═════╝
```

Generate ad copy variations at scale, build structured A/B test frameworks, and analyze campaign performance. Handles multi-platform ad creation with strict character limit enforcement and CSV export for direct platform upload.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments — Show campaign status

Glob `.maestro/campaigns/*.md` to count existing campaign files. Read frontmatter to count by `status`.

```
+---------------------------------------------+
| Marketing Automation                        |
+---------------------------------------------+

  Campaigns: <N> total
  Active:    <N>
  Draft:     <N>
  Completed: <N>

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Marketing"
- Options:
  1. label: "Generate ad copy", description: "Create copy variations for Google, Meta, or LinkedIn"
  2. label: "Build A/B test", description: "Create a structured A/B test framework for a campaign"
  3. label: "Analyze performance", description: "Review performance data for an existing campaign"

### `generate <platform>` — Generate ad copy variations

Valid platforms: `google` | `meta` | `linkedin` | `all`

If platform is not provided or not recognized:

Use AskUserQuestion:
- Question: "Which platform(s) would you like to generate copy for?"
- Header: "Platform"
- Options:
  1. label: "Google Ads", description: "Search and display ads (30/30/30 char headlines, 90 char descriptions)"
  2. label: "Meta Ads", description: "Facebook and Instagram (125 char primary, 40 char headline)"
  3. label: "LinkedIn Ads", description: "B2B audience (150 char intro, 70 char headline)"
  4. label: "All platforms", description: "Generate variations for Google, Meta, and LinkedIn"

Gather required inputs:

Use AskUserQuestion:
- Question: "Describe your campaign brief. What product or service are you promoting and what is the key benefit?"
- Header: "Campaign Brief"

Use AskUserQuestion:
- Question: "What is the campaign goal?"
- Header: "Goal"
- Options:
  1. label: "Conversions", description: "Drive purchases, signups, or form fills"
  2. label: "Traffic", description: "Bring visitors to a landing page"
  3. label: "Leads", description: "Capture contact information"
  4. label: "Awareness", description: "Increase brand recognition and reach"

Use AskUserQuestion:
- Question: "How many copy variations per platform? (default: 10, max: 50)"
- Header: "Variations"

Invoke the marketing-automation skill from `skills/marketing-automation/SKILL.md`. The skill will:

1. Read `.maestro/strategy.md` and `.maestro/voice.md` if they exist
2. Analyze the brief to extract product, benefit, audience, and differentiator
3. Generate variations cycling through 8 copy frameworks (Problem-Solution, Benefit-Led, Social Proof, Urgency, Question Hook, Comparison, How-To, Curiosity Gap)
4. Enforce character limits for every element of every variation
5. Rewrite any element that exceeds its limit
6. Build an A/B test plan with hypothesis, variants table, and success criteria
7. Save to `.maestro/campaigns/{campaign-slug}.md`
8. Export platform CSVs to `.maestro/campaigns/{campaign-slug}-{platform}.csv`

Display progress inline:

```
[maestro] Campaign brief analyzed
[maestro] Generating <N> variations per platform
[maestro] Character limit audit: <N>/<total> passing
[maestro] A/B test plan: <N> variants
[maestro] Saved: .maestro/campaigns/<slug>.md
[maestro] Exported: <slug>-google.csv, <slug>-meta.csv, <slug>-linkedin.csv
```

After completion:

```
+---------------------------------------------+
| Campaign Created                            |
+---------------------------------------------+

  File:        .maestro/campaigns/<slug>.md
  Platforms:   <platforms>
  Variations:  <total count>
  A/B Test:    yes
  Status:      draft

  (i) Upload CSVs from .maestro/campaigns/ to each platform's bulk upload tool.
  (i) Run /maestro marketing analyze when you have performance data.
```

### `ab-test` — Build an A/B test framework

Use AskUserQuestion:
- Question: "Which campaign would you like to build an A/B test for? Provide the campaign name or slug."
- Header: "Campaign"

Glob `.maestro/campaigns/*.md`. If no campaigns exist:

```
[maestro] No campaigns found.

  Create a campaign first with:
    /maestro marketing generate
```

If a campaign slug is provided, read `.maestro/campaigns/{slug}.md`. If not found, list available campaigns and ask the user to choose.

Invoke the marketing-automation skill's `ab_test` operation. The skill generates:
- Test hypothesis
- Variant table (Control A + up to 2 variants) isolating one variable at a time
- Metric definitions and targets (CTR, CPC, Conv. Rate, CPA, ROAS)
- Timeline (setup day, 7-day learning phase, evaluation day)
- Success criteria with statistical significance threshold

Display the full A/B test plan and append it to the campaign file.

```
+---------------------------------------------+
| A/B Test Plan Added                         |
+---------------------------------------------+

  Campaign:   <name>
  Variants:   <N> (Control + <N> challengers)
  Variable:   <isolated element>
  Duration:   <N> days
  Min sample: <N> impressions per variant

  (i) Do not change the campaign during the learning phase (days 1-7).
  (i) Evaluate on day 8 with /maestro marketing analyze.
```

### `analyze` — Analyze campaign performance

Use AskUserQuestion:
- Question: "Which campaign would you like to analyze? Provide the campaign name or slug."
- Header: "Campaign"

Glob `.maestro/campaigns/*.md`. If no campaigns exist:

```
[maestro] No campaigns found.

  Create a campaign first with:
    /maestro marketing generate
```

Read the target campaign file. Check for performance data in the `## Performance Log` table.

If no performance data exists:

```
[maestro] No performance data found in <campaign>.md

  To analyze a campaign:
  1. Add performance data to the "## Performance Log" table in:
       .maestro/campaigns/<slug>.md
  2. Run /maestro marketing analyze again.

  Log format:
    | Date | Platform | Variant | Impressions | Clicks | CTR | Conv | CPA |
```

If performance data exists, invoke the marketing-automation skill's `analyze` operation. The skill will:

1. Compare variants against the control (Variant A)
2. Apply decision rules: clear winner (30%+ improvement + 1000 clicks), marginal (10-30%), no winner (<10%)
3. Suggest next-round iterations based on winning elements
4. Recommend budget reallocation

Display the variant comparison table:

```
+---------------------------------------------+
| Variant Performance: <Campaign>             |
+---------------------------------------------+

  Variant    Impressions  CTR     CPA     Status
  ---------  ----------   -----   ------  ------
  A (ctrl)   <N>          <N>%    $<N>    baseline
  B          <N>          <N>%    $<N>    <result>
  C          <N>          <N>%    $<N>    <result>

  Decision:  <winner declared | extend test | new angles needed>

  Recommendations:
  - <suggestion 1>
  - <suggestion 2>
```

## Error Handling

| Error | Action |
|-------|--------|
| No brief provided | Prompt interactively with AskUserQuestion |
| Character limit exceeded after rewrite | Flag element, ask user for shorter alternative |
| Strategy file missing | Generate without positioning context, warn user |
| No performance data for analysis | Show instructions for adding data to the log |
| CSV export path conflict | Append timestamp to filename |
| Platform not supported | Warn and skip, generate for supported platforms only |
