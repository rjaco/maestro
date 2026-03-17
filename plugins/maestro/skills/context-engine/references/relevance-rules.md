# Relevance Scoring Rules

The Context Engine scores each available context piece (0.0-1.0) against the current task. These rules define how scores are computed from four signal categories.

## Story Type Signals

The story's `type` field determines baseline relevance for pattern categories.

| Story Type | High Relevance (0.8-1.0) | Medium (0.4-0.6) | Low (0.0-0.2) |
|-----------|--------------------------|-------------------|----------------|
| `backend` | API patterns, DB queries, caching, auth, rate limiting, validation | Type definitions, error handling | Component patterns, styling, a11y, animations |
| `frontend` | Component patterns, styling, a11y, responsive, animations | Type definitions, utility functions | API internals, DB queries, caching layer, auth logic |
| `data` | Pipeline patterns, ETL, migrations, data quality, schema | DB queries, type definitions | Component patterns, styling, API routes, auth |
| `integration` | API contracts, type definitions, error handling | Both API and component patterns | Styling, animations, pipeline internals |
| `infrastructure` | CI/CD, deployment, config, environment | Security patterns, monitoring | Component patterns, business logic, styling |

## File Path Signals

When a story specifies files to create, modify, or reference, score context pieces by path proximity.

| File Path Pattern | High Relevance Context |
|-------------------|----------------------|
| `src/app/api/**` | API route conventions, Zod validation, rate limiting, Cache-Control headers |
| `src/components/**` | Component patterns, props conventions, cn() usage, design tokens |
| `src/components/ui/**` | Design system primitives, variant/size props, forwardRef pattern |
| `src/lib/data/**` | Supabase client rules (DO NOT MODIFY), query patterns |
| `src/lib/business/**` | Business logic conventions, pure function patterns |
| `src/lib/cache/**` | Cache manager, ISR config, Redis patterns |
| `src/lib/seo/**` | SEO conventions, structured data, meta tags |
| `src/app/**/page.tsx` | Page component conventions, metadata, ISR, generateStaticParams |
| `src/middleware.ts` | Edge runtime constraints, Supabase SSR client |
| `database/migrations/**` | Migration naming, SQL conventions |
| `crawler/**` | Python conventions, scraper patterns, ETL pipeline |

Score 1.0 for exact directory match, 0.6 for parent directory, 0.2 for sibling directory, 0.0 for unrelated paths.

## Keyword Signals

Extract keywords from story title, description, and acceptance criteria. Match against context piece content.

| Keywords | Relevant Context |
|----------|-----------------|
| rate limit, throttle, abuse | Cache rules, Redis patterns, withRateLimit() |
| auth, login, session, permission | Middleware, Supabase SSR client, role checks |
| form, input, validate | Zod validation, React Hook Form patterns, forwardRef |
| SEO, meta, structured data | JSON-LD schemas, generateMetadata, canonical URLs |
| cache, revalidate, ISR | Cache manager, revalidate settings, CACHE_HEADERS |
| responsive, mobile, breakpoint | Design tokens, spacing system, Tailwind breakpoints |
| dark mode, theme, color | CSS custom properties, dark: variants, color palette |
| animation, transition, motion | Framer Motion patterns, reduced-motion a11y |
| test, spec, assertion | Vitest config, test location conventions, happy-dom |
| deploy, build, CI | Cloudflare Workers, OpenNext, wrangler, GitHub Actions |
| image, media, CDN | R2 storage, image loader, CDN configuration |
| monetization, ad, affiliate | Monetization widget placements, affiliate patterns |

Multiple keyword matches compound: two matches score 0.7, three or more score 0.9.

## QA History Signals

QA feedback from previous dev-loop iterations is filtered before inclusion.

- **Same story, same session:** Score 1.0. Always include — this is direct iteration feedback.
- **Same story type, same session:** Score 0.5. Include if budget allows — patterns of mistakes transfer.
- **Different story type, same session:** Score 0.1. Exclude unless T0/T1 tier.
- **Previous session:** Score 0.0. Exclude. Stale feedback introduces noise.

## CLAUDE.md Rule Filtering

Parse CLAUDE.md into discrete rules. Score each rule against the story's affected files.

- Rule mentions a file the story modifies: Score 1.0.
- Rule mentions a directory containing story files: Score 0.8.
- Rule mentions the story's technology (e.g., "Supabase", "Tailwind"): Score 0.5.
- Rule is generic (e.g., "No emojis in code"): Score 0.3.
- Rule is about unrelated areas: Score 0.0.

Only include rules scoring above the tier's threshold (T3: 0.5, T4: 0.7).
