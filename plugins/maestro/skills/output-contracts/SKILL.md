---
name: output-contracts
description: "Declare expected output formats for skills and validate compliance. Replaces test suites for non-code workflows like content, marketing, and research."
---

# Output Contracts

Declare and enforce expected output formats for Maestro skills. When code has tests, knowledge work has contracts. A contract defines what a skill's output MUST contain — the QA reviewer validates against it.

## Contract Definition

Each skill declares an output contract:

```yaml
output_contract:
  file_pattern: ".maestro/content/{date}-{slug}.md"
  required_frontmatter:
    type: string
    status: enum(draft, review, ready)
  required_sections:
    - "## Summary"
    - "## Content"
  word_bounds:
    min: 800
    max: 3000
```

## Built-In Contracts

| Skill | File Pattern | Required Sections | Word Bounds |
|-------|-------------|-------------------|-------------|
| content-pipeline | `.maestro/content/{date}-{slug}.md` | Summary, Content, SEO Metadata | 100-3000 |
| marketing-automation | `.maestro/campaigns/{slug}.md` | Brief, Variations, A/B Test Plan | 200-2000 |
| research | `.maestro/research.md` | Executive Summary, Findings, Matrix, Recommendations | 500-5000 |
| strategy | `.maestro/strategy.md` | Positioning, Channels, Content Strategy, KPIs | 500-3000 |
| scenario-planning | `.maestro/scenarios/{slug}.md` | Base Case, Scenarios, Sensitivity, Recommendation | 300-3000 |
| architecture | `.maestro/architecture.md` | Tech Stack, Data Model, API Design, Components | 500-5000 |

## Validation Rules

| Rule | What It Checks |
|------|---------------|
| heading_hierarchy | H1 then H2 then H3, no level skips |
| no_empty_sections | Every required section has content |
| frontmatter_complete | All required fields present and typed correctly |
| character_limits | Ad copy within platform character limits |
| min_variations(N) | At least N variations generated |
| cross_references | Links to other .maestro/ files resolve |
| word_bounds | Content within min/max word count |

## Validation Process

1. Load contract from the generating skill
2. Check frontmatter fields (presence + type)
3. Check required sections (presence + non-empty)
4. Check word bounds
5. Apply rule-specific checks
6. Report results

## Report Format

```
+---------------------------------------------+
| Output Contract Validation                  |
+---------------------------------------------+

  Contract    content-pipeline
  File        .maestro/content/2026-03-17-auth-guide.md

  Frontmatter:
    (ok) type: blog
    (ok) status: review
    (ok) keywords: [auth, JWT]

  Sections:
    (ok) Summary (45 words)
    (ok) Content (1,102 words)
    (ok) SEO Metadata

  Rules:
    (ok) heading_hierarchy
    (ok) no_empty_sections
    (ok) word_bounds (1,247 in 800-3000)

  Result: APPROVED
```

## Integration

- QA reviewer: receives contract as context. Code -> tests. Knowledge work -> contract validation.
- Content validator: uses contracts as its ruleset.
- Dev-loop SELF-HEAL: code stories run tsc/lint/test. Knowledge work runs contract validation.
- Fixer agent: receives specific failures and fixes them (add missing section, fix frontmatter).
