---
name: research
description: "Competitive intelligence and market research using web search and Playwright screenshots. Produces .maestro/research.md with competitor matrix, patterns, and recommendations."
---

# Research

Performs competitive intelligence and market research to inform strategy and architecture decisions. Uses WebSearch for discovery, WebFetch for technical analysis, and Playwright MCP for visual analysis when available.

## Input

- Topic or domain to research (from `$ARGUMENTS` or upstream classifier)
- Optional: specific competitors to analyze
- Optional: specific aspects to focus on (SEO, UX, features, pricing, tech stack)

## Process

### Step 1: Discovery

Use WebSearch to find:

1. **Direct competitors** — Products or services solving the same problem for the same audience.
2. **Indirect competitors** — Adjacent solutions the target audience might use instead.
3. **Best practices** — Industry standards, design patterns, and conventions in the space.
4. **Market context** — Market size signals, trends, recent launches, funding activity.

Perform at least 3-5 searches with varied queries:
- `"[topic] competitors"` / `"[topic] alternatives"`
- `"best [topic] 2026"` / `"top [topic] tools"`
- `"[topic] market size"` / `"[topic] trends"`
- `"[topic] open source"` (if applicable)

Collect the top 3-5 competitors by relevance. Record their URLs.

### Step 2: Visual Analysis

If Playwright MCP tools are available:

1. Navigate to each competitor's homepage or primary landing page.
2. Take a full-page screenshot using `browser_take_screenshot`.
3. Capture a DOM snapshot using `browser_snapshot` to understand component structure.
4. Navigate to 1-2 key interior pages (pricing, features, product page) and repeat.
5. Save screenshot references to `.maestro/research/screenshots/` with descriptive names:
   - `competitor-name-homepage.png`
   - `competitor-name-pricing.png`
   - `competitor-name-product.png`

Note: If Playwright is not available, skip this step and rely on WebFetch analysis.

### Step 3: Technical Analysis

For each competitor, use WebFetch to retrieve the page source and analyze:

1. **Meta tags** — title, description, Open Graph, Twitter Cards.
2. **Schema.org** — structured data types (JSON-LD, microdata).
3. **Tech stack signals** — framework markers in HTML (Next.js `__NEXT_DATA__`, Nuxt, React root divs), CSS frameworks (Tailwind classes, Bootstrap grid), analytics scripts (GA4, Segment, Mixpanel).
4. **Performance indicators** — script count, CSS file count, image optimization (WebP/AVIF, lazy loading, srcset), font loading strategy.
5. **API patterns** — visible API calls in network requests, GraphQL endpoints, REST patterns.

Record findings in a structured format per competitor.

### Step 4: SEO Analysis

For each competitor's key pages, examine:

1. **Heading structure** — H1-H6 hierarchy, keyword usage, heading count.
2. **Structured data** — JSON-LD schemas present (Product, Organization, BreadcrumbList, FAQ, HowTo, Article).
3. **Canonical URLs** — Canonical tags, hreflang for internationalization.
4. **Internal linking** — Navigation depth, contextual links, footer link density, breadcrumbs.
5. **URL structure** — Path patterns, slug conventions, parameter usage.
6. **Content depth** — Word count on key pages, FAQ presence, glossary, buyer guides.

### Step 5: Feature Matrix

Build a feature comparison matrix:

```
| Feature           | Competitor A | Competitor B | Competitor C | Our Plan |
|-------------------|-------------|-------------|-------------|----------|
| Feature 1         | Yes         | Partial     | No          | ?        |
| Feature 2         | No          | Yes         | Yes         | ?        |
| Pricing Model     | Freemium    | Paid only   | Free + Ads  | ?        |
| Mobile Support    | Native app  | Responsive  | None        | ?        |
```

The "Our Plan" column is left blank or marked with `?` for the strategy phase to fill in.

### Step 6: Synthesis

Write `.maestro/research.md` with these sections:

```markdown
# Research: [Topic]

**Date:** [YYYY-MM-DD]
**Competitors analyzed:** [count]
**Sources reviewed:** [count]

## Competitor Matrix

[Feature matrix table from Step 5]

## Competitor Profiles

### [Competitor Name]
- **URL:** [url]
- **Tech stack:** [detected stack]
- **Strengths:** [bullet points]
- **Weaknesses:** [bullet points]
- **Differentiator:** [one sentence]

[Repeat for each competitor]

## Technical Patterns Worth Adopting

[Numbered list of patterns seen across multiple competitors that indicate industry standards or proven approaches. Each with rationale.]

## Anti-Patterns to Avoid

[Numbered list of problematic patterns observed, with explanation of why they hurt UX, SEO, performance, or conversion.]

## SEO Landscape

[Summary of SEO strategies observed, keyword patterns, content depth, structured data usage.]

## Recommended Approach

[Specific, opinionated recommendations for how the project should position itself relative to the competition. Not generic advice — concrete suggestions tied to observations.]

## Screenshots

[If captured: list of screenshot files with brief descriptions. If not captured: note that visual analysis was skipped.]
```

## Output

- `.maestro/research.md` — Full research report
- `.maestro/research/screenshots/` — Visual captures (if Playwright available)
- Research findings are consumed by `strategy` and `architecture` skills
