---
name: live-docs
description: "Inject current framework documentation into agent context before implementation. Prevents using outdated API patterns from training data."
---

# Live Documentation Injection

Before implementing a story, detect framework/library usage and fetch current documentation to prevent outdated patterns.

## When to Inject

During DELEGATE phase, before composing the implementer's context package:

1. Parse the story's file list and context for framework references
2. If a framework is detected, search for current documentation
3. Inject relevant API surfaces (function signatures, key patterns)
4. Max injection: 2000 tokens (stay within context budget)

## Supported Frameworks

| Framework | Detection | What to Fetch |
|-----------|-----------|---------------|
| Next.js | `next.config`, imports from `next/` | App Router API, Server Components, Route Handlers |
| React | imports from `react` | Hooks API, Server Components, Suspense |
| Tailwind | `tailwind.config` | Utility classes, theme config, plugins |
| Prisma | `prisma/schema.prisma` | Client API, query patterns, migrations |
| Supabase | imports from `@supabase/` | Auth, database, storage, realtime |
| Express | imports from `express` | Router, middleware, error handling |
| Zod | imports from `zod` | Schema API, validation patterns |
| tRPC | imports from `@trpc/` | Router, procedure, context |

## Process

1. Read story spec — extract file paths and imports
2. Match against framework detection table
3. For each matched framework:
   - Check cache: `.maestro/docs-cache/{framework}-{topic}.md`
   - If cached and fresh (< 7 days): use cached version
   - If not cached: WebSearch for "{framework} {topic} documentation 2026"
   - Extract key API surfaces (signatures, patterns, examples)
   - Save to cache for future use
4. Truncate to 2000 tokens max
5. Return as context block for injection

## Cache

Save fetched docs to `.maestro/docs-cache/`:

```
.maestro/docs-cache/
  nextjs-app-router.md
  prisma-client-api.md
  supabase-auth.md
```

Each cached file includes a `fetched_at` date. Re-fetch if older than 7 days.

## Integration

Called by the context-engine during DELEGATE phase:

```
if story references a framework:
    docs = live_docs.fetch(framework, topic)
    inject docs into context package (after interface definitions)
```

## Output Format

```
[Live Docs: Next.js App Router]

Route Handlers (app/api/):
  export async function GET(request: Request) { ... }
  export async function POST(request: Request) { ... }

Server Components (default):
  - No useState, useEffect, event handlers
  - Can use async/await directly
  - Use 'use client' directive for client components

[End Live Docs]
```
