---
name: output-contracts
description: "Declare expected output formats for skills and validate compliance. Replaces test suites for non-code workflows like content, marketing, and research."
---

# Output Contracts

Declare and enforce expected output formats for Maestro skills. When code has tests, knowledge work has contracts. A contract defines what a skill's output MUST contain — the QA reviewer validates against it.

## Contract Definition Format

Each skill declares an output contract in its SKILL.md frontmatter or body. The full schema:

```yaml
output_contract:
  # Where the output file lives. Supports {date}, {slug}, {project} tokens.
  file_pattern: ".maestro/content/{date}-{slug}.md"

  # Frontmatter fields that must be present with correct types.
  required_frontmatter:
    type: string                        # must be a string
    status: enum(draft, review, ready)  # must be one of these values
    keywords: list                      # must be a list (can be empty)
    author: string?                     # optional (trailing ?)

  # Markdown headings that must appear and contain non-empty content.
  required_sections:
    - "## Summary"
    - "## Content"
    - "## SEO Metadata"

  # Word count limits for the full document body (excluding frontmatter).
  word_bounds:
    min: 800
    max: 3000

  # Named validation rules applied after structural checks.
  rules:
    - heading_hierarchy          # no level skips (H2 before H3, etc.)
    - no_empty_sections          # every required section has >= 1 sentence
    - cross_references           # links to .maestro/ files resolve
    - character_limits           # ad copy respects platform limits (see below)
    - min_variations: 3          # at least 3 copy variations generated
```

## Built-In Contracts

### 1. content-pipeline

```yaml
output_contract:
  file_pattern: ".maestro/content/{date}-{slug}.md"
  required_frontmatter:
    type: string
    status: enum(draft, review, ready)
    keywords: list
  required_sections:
    - "## Summary"
    - "## Content"
    - "## SEO Metadata"
  word_bounds:
    min: 800
    max: 3000
  rules:
    - heading_hierarchy
    - no_empty_sections
```

### 2. marketing-automation

```yaml
output_contract:
  file_pattern: ".maestro/campaigns/{slug}.md"
  required_frontmatter:
    type: enum(email, social, paid, landing)
    status: enum(draft, review, ready)
    channel: string
  required_sections:
    - "## Brief"
    - "## Variations"
    - "## A/B Test Plan"
  word_bounds:
    min: 200
    max: 2000
  rules:
    - min_variations: 3
    - character_limits
    - no_empty_sections
```

### 3. research

```yaml
output_contract:
  file_pattern: ".maestro/research.md"
  required_frontmatter:
    type: string      # topic or domain
    status: enum(draft, review, final)
    sources: list
  required_sections:
    - "## Executive Summary"
    - "## Findings"
    - "## Comparison Matrix"
    - "## Recommendations"
  word_bounds:
    min: 500
    max: 5000
  rules:
    - heading_hierarchy
    - no_empty_sections
    - cross_references
```

### 4. strategy

```yaml
output_contract:
  file_pattern: ".maestro/strategy.md"
  required_frontmatter:
    type: string
    status: enum(draft, review, approved)
    horizon: string   # e.g. "Q2 2026" or "6-month"
  required_sections:
    - "## Positioning"
    - "## Channels"
    - "## Content Strategy"
    - "## KPIs"
  word_bounds:
    min: 500
    max: 3000
  rules:
    - heading_hierarchy
    - no_empty_sections
```

### 5. scenario-planning

```yaml
output_contract:
  file_pattern: ".maestro/scenarios/{slug}.md"
  required_frontmatter:
    type: string
    status: enum(draft, review, final)
  required_sections:
    - "## Base Case"
    - "## Scenarios"
    - "## Sensitivity Analysis"
    - "## Recommendation"
  word_bounds:
    min: 300
    max: 3000
  rules:
    - heading_hierarchy
    - no_empty_sections
```

### 6. architecture

```yaml
output_contract:
  file_pattern: ".maestro/architecture.md"
  required_frontmatter:
    type: string
    status: enum(draft, review, approved)
  required_sections:
    - "## Tech Stack"
    - "## Data Model"
    - "## API Design"
    - "## Components"
  word_bounds:
    min: 500
    max: 5000
  rules:
    - heading_hierarchy
    - no_empty_sections
    - cross_references
```

### 7. living-docs

```yaml
output_contract:
  file_pattern: ".maestro/state.md"
  required_sections:
    - "## What Works"
    - "## What's Broken / Known Issues"
    - "## Current Focus"
  rules:
    - no_empty_sections
```

## Creating Custom Contracts

When building a new skill that produces structured output, add a contract by following these steps:

1. **Identify the output file.** What does the skill write? Where does it go?
2. **List required sections.** What headings must always appear?
3. **Enumerate frontmatter fields.** What metadata is required for downstream consumers?
4. **Set word bounds.** What is too short (incomplete) or too long (unfocused)?
5. **Choose rules.** Pick from built-in rules or define custom ones (see below).
6. **Add to SKILL.md.** Paste the `output_contract:` block into the skill's SKILL.md.

**Custom rule definition.** If no built-in rule covers your check, define it inline:

```yaml
rules:
  - custom:
      name: has_call_to_action
      description: "Document must contain at least one CTA link or button reference"
      check: "body contains pattern /\\[.+\\]\\(.+\\)|CTA|call.to.action/i"
      error: "No call-to-action found. Add a CTA link or explicit CTA section."
```

## Validation Algorithm

The validator runs checks in this order. Failure at any step is recorded but does not stop subsequent checks (full report always generated).

```
1. FILE EXISTS
   - Verify the output file is present at the expected path.
   - Error: "File not found: {path}"

2. FRONTMATTER PARSE
   - Parse YAML frontmatter block.
   - Error on malformed YAML: "Frontmatter parse error: {details}"

3. FRONTMATTER FIELDS
   For each required_frontmatter field:
     a. Check presence. Error: "Missing frontmatter field: {field}"
     b. Check type. Error: "Wrong type for {field}: expected {type}, got {actual}"
     c. Check enum values if specified. Error: "Invalid value for {field}: '{value}' not in {enum}"

4. REQUIRED SECTIONS
   For each required section heading:
     a. Check heading is present (exact text match). Error: "Missing section: {heading}"
     b. Check section has content (at least one non-empty line after heading).
        Error: "Empty section: {heading}"

5. WORD BOUNDS
   - Count words in document body (exclude frontmatter).
   - Error if below min: "Too short: {count} words, minimum is {min}"
   - Error if above max: "Too long: {count} words, maximum is {max}"

6. NAMED RULES
   For each rule in rules list:
     - heading_hierarchy: Walk headings in order. Error if H3 appears before H2, etc.
     - no_empty_sections: Re-verify all sections (including non-required ones).
     - cross_references: Resolve all .maestro/ links. Error for each broken link.
     - character_limits: Check ad copy blocks against platform limits (Twitter 280, Meta 125 primary, Google 30/90).
     - min_variations(N): Count variation blocks. Error if fewer than N found.
     - custom rules: Run pattern match per definition.

7. GENERATE REPORT
   - Tally pass/fail per check.
   - Determine result: APPROVED (all pass) or REJECTED (any failure).
   - Emit formatted report (see below).
```

### Partial Pass Handling

A contract result is binary: APPROVED or REJECTED. There is no "partial pass." However, the report distinguishes between:

- **Blocking failures:** missing required sections, missing required frontmatter, file not found.
- **Quality warnings:** word bounds exceeded by less than 10%, non-required empty sections.

Quality warnings are reported as `(warn)` and do not cause REJECTED status. All other failures cause REJECTED.

## Report Format

```
+---------------------------------------------+
| Output Contract Validation                  |
+---------------------------------------------+

  Contract    content-pipeline
  File        .maestro/content/2026-03-17-auth-guide.md

  Frontmatter:
    (ok)   type: blog
    (ok)   status: review
    (ok)   keywords: [auth, JWT]

  Sections:
    (ok)   Summary (45 words)
    (ok)   Content (1,102 words)
    (ok)   SEO Metadata

  Rules:
    (ok)   heading_hierarchy
    (ok)   no_empty_sections
    (ok)   word_bounds (1,247 in 800-3000)

  Result: APPROVED

+---------------------------------------------+
```

Failed validation example:

```
  Sections:
    (ok)   Summary (45 words)
    (FAIL) Content — section is empty
    (ok)   SEO Metadata

  Rules:
    (ok)   heading_hierarchy
    (FAIL) word_bounds (312 words, minimum is 800)

  Result: REJECTED
  Failures: 2 blocking, 0 warnings
  Fix: Add content to '## Content' section; expand body to at least 800 words.
```

## Example: Blog Post Contract

```yaml
output_contract:
  file_pattern: ".maestro/content/{date}-{slug}.md"
  required_frontmatter:
    title: string
    type: enum(blog, tutorial, case-study)
    status: enum(draft, review, ready)
    keywords: list
    reading_time: string?
  required_sections:
    - "## Summary"
    - "## Introduction"
    - "## Content"
    - "## Conclusion"
    - "## SEO Metadata"
  word_bounds:
    min: 800
    max: 3000
  rules:
    - heading_hierarchy
    - no_empty_sections
```

## Example: Research Brief Contract

```yaml
output_contract:
  file_pattern: ".maestro/research/{slug}.md"
  required_frontmatter:
    topic: string
    status: enum(draft, review, final)
    sources: list
    commissioned_by: string?
  required_sections:
    - "## Executive Summary"
    - "## Research Question"
    - "## Methodology"
    - "## Findings"
    - "## Comparison Matrix"
    - "## Recommendations"
    - "## Limitations"
  word_bounds:
    min: 1000
    max: 5000
  rules:
    - heading_hierarchy
    - no_empty_sections
    - cross_references
```

## Example: Strategy Doc Contract

```yaml
output_contract:
  file_pattern: ".maestro/strategy/{slug}.md"
  required_frontmatter:
    type: enum(go-to-market, product, content, growth)
    status: enum(draft, review, approved)
    horizon: string
    owner: string?
  required_sections:
    - "## Context"
    - "## Positioning"
    - "## Target Audience"
    - "## Channels"
    - "## Content Strategy"
    - "## KPIs"
    - "## Risks"
  word_bounds:
    min: 800
    max: 4000
  rules:
    - heading_hierarchy
    - no_empty_sections
```

## Integration

- **QA reviewer:** Receives the contract as context. Code stories use tests; knowledge work uses contract validation. The QA agent runs validation as part of its review.
- **content-validator skill:** Uses contracts as its ruleset. The contract is the single source of truth — content-validator does not define its own rules.
- **dev-loop SELF-HEAL:** For code stories, runs `tsc`/`lint`/`test`. For knowledge work stories, runs contract validation. Failures trigger the fixer agent.
- **Fixer agent:** Receives specific failure lines from the report and fixes them (add missing section, fix frontmatter, expand thin content).
