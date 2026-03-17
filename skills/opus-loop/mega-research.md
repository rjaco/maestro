# Mega Research Sprint — 8-Dimension Parallel Investigation

Dispatches 8 research agents simultaneously to investigate the landscape around the user's vision. Each agent writes its findings to a dedicated file. After all complete, findings are synthesized into a single research brief.

## When to Run

- After the Deep Interview produces `.maestro/vision.md`
- Skipped if `--skip-research` flag was passed
- Estimated cost: $3-5 for all 8 dimensions (primarily Sonnet with WebSearch)

## Agent Configuration (per dimension)

```yaml
model: sonnet
tools: [WebSearch, WebFetch, Read, Write, Bash]
maxTurns: 20
```

All 8 agents run in parallel via `run_in_background: true`. The orchestrator waits for all to complete before synthesizing.

## Dimensions

### 1. Market and Competitors

**Output:** `.maestro/research/01-market-competitors.md`

**Instructions:** Search for existing products in the same space as described in the vision. For each competitor:
- Name, URL, pricing model
- Key features (what they do well)
- Gaps and weaknesses (from user reviews, complaint forums, social media)
- Market positioning (enterprise vs SMB, technical vs non-technical)
- Approximate scale (team size, funding, user count if available)

Identify market gaps that the vision can exploit.

### 2. Tech Stack Options

**Output:** `.maestro/research/02-tech-stack.md`

**Instructions:** Given the project DNA and vision requirements, research:
- Framework choices and tradeoffs for this type of product
- Database options optimized for the data patterns described
- Hosting and deployment options (cost, scale, DX)
- Third-party services that accelerate development (auth, payments, email, storage)
- Open-source libraries that solve specific problems mentioned in the vision

Recommend a stack, with rationale. If the project DNA already defines the stack, validate it against the vision requirements and flag any gaps.

### 3. Architecture Patterns

**Output:** `.maestro/research/03-architecture.md`

**Instructions:** Research architecture patterns used by similar products:
- Data model patterns (multi-tenant, event-sourced, CQRS, standard CRUD)
- API design (REST, GraphQL, tRPC, WebSocket for real-time)
- Frontend architecture (SSR, SPA, hybrid, micro-frontends)
- Caching strategies appropriate for the data access patterns
- Background job processing if applicable

Recommend an architecture with diagrams (ASCII art) and rationale.

### 4. SEO and Content Strategy

**Output:** `.maestro/research/04-seo-content.md`

**Instructions:** Research the SEO landscape for the product's domain:
- High-volume keywords related to the problem space
- Content types that rank well (guides, comparisons, tools, templates)
- Competitor content strategies (what they publish, how often)
- Technical SEO requirements (structured data, sitemaps, Core Web Vitals)
- Content-led growth opportunities

Skip this dimension if the product has no public-facing web presence (internal tool, CLI, API-only).

### 5. Monetization Patterns

**Output:** `.maestro/research/05-monetization.md`

**Instructions:** Research monetization approaches used by similar products:
- Pricing models (per-seat, usage-based, tiered, freemium boundaries)
- Common price points for the market segment
- Payment providers and their fees
- Upsell and expansion revenue patterns
- Free trial vs freemium conversion benchmarks

Skip this dimension if the vision explicitly states no revenue intent.

### 6. Integrations Ecosystem

**Output:** `.maestro/research/06-integrations.md`

**Instructions:** Research APIs and services the product needs to integrate with:
- API documentation quality, rate limits, pricing
- Authentication methods (OAuth, API keys, webhooks)
- SDK availability for the project's language
- Common integration pitfalls and workarounds
- Webhook patterns for real-time data sync

Focus only on integrations mentioned in the vision document.

### 7. User Research Patterns

**Output:** `.maestro/research/07-user-research.md`

**Instructions:** Research user behavior patterns for the product type:
- Common user journeys and drop-off points
- Onboarding patterns that work well (progressive disclosure, templates, wizards)
- Engagement and retention patterns (what keeps users coming back)
- Accessibility requirements for the target audience
- Mobile vs desktop usage patterns for this product category

### 8. Launch Strategy

**Output:** `.maestro/research/08-launch-strategy.md`

**Instructions:** Research launch approaches for similar products:
- Launch channels (Product Hunt, Hacker News, Reddit, Twitter, LinkedIn)
- Pre-launch strategies (waitlists, beta programs, landing pages)
- Launch timing considerations
- Post-launch iteration cadence
- Community building approaches

## Synthesis

After all 8 agents complete, synthesize findings into `.maestro/research-brief.md` using the research-brief template.

Read all 8 dimension files and extract:
- Key findings that impact architecture or milestone planning
- Anti-patterns to avoid (from competitor failures and common pitfalls)
- Recommended approach (the distilled recommendation across all dimensions)
- Competitor matrix (name, pricing, strengths, weaknesses, our advantage)
- Technical recommendations (stack validation, architecture, integrations)

The research brief is the primary input to the roadmap-generator. Individual dimension files serve as deep-dive references during milestone execution.

Present the research brief summary to the user before proceeding to roadmap generation. They may want to add context, correct assumptions, or redirect focus.
