---
name: quick-start
description: "Pre-built task templates for common development and knowledge work patterns. Pick a template instead of typing a description."
---

# Quick Start Templates

Pre-built templates for common tasks. Instead of thinking about how to phrase a feature request, pick a template and fill in the blank. Zero thinking required.

## How to Use

1. Run `/maestro quick-start`
2. Pick a category (Code / Content / Marketing / Research)
3. Pick a template
4. Maestro fills in the command -- you just confirm

## Code Templates

| Template | Description | Maestro Command |
|----------|-------------|-----------------|
| Add API endpoint | REST endpoint with validation, auth, tests | `/maestro "Add [resource] API endpoint"` |
| Add authentication | Email/password or OAuth login flow | `/maestro "Add authentication with [method]"` |
| Add test suite | Unit + integration tests for existing code | `/maestro "Add comprehensive tests for [module]"` |
| Fix lint errors | Auto-fix all linting issues | `/maestro "Fix all lint errors" --yolo` |
| Add dark mode | Toggle with CSS variables or Tailwind | `/maestro "Add dark mode toggle"` |
| Database migration | Add/modify schema with migration | `/maestro "Add [table] to database"` |

### Template Details: Code

#### Add API endpoint

```yaml
template: add-api-endpoint
description: "Add [resource] API endpoint"
suggested_mode: checkpoint
estimated_stories: 3-4
expected_output:
  - Route handler with CRUD operations
  - Input validation middleware
  - Authentication/authorization checks
  - Unit and integration tests
  - OpenAPI/Swagger documentation (if project uses it)
placeholder: "[resource]"
examples:
  - "Add users API endpoint"
  - "Add products API endpoint"
  - "Add payments API endpoint"
```

#### Add authentication

```yaml
template: add-authentication
description: "Add authentication with [method]"
suggested_mode: checkpoint
estimated_stories: 5-7
expected_output:
  - Login/register routes
  - Session or JWT token management
  - Password hashing (bcrypt)
  - Protected route middleware
  - Tests for auth flows
placeholder: "[method]"
examples:
  - "Add authentication with email/password"
  - "Add authentication with Google OAuth"
  - "Add authentication with magic link"
```

#### Add test suite

```yaml
template: add-test-suite
description: "Add comprehensive tests for [module]"
suggested_mode: checkpoint
estimated_stories: 2-4
expected_output:
  - Unit tests for all public functions
  - Integration tests for API endpoints
  - Edge case coverage
  - Mock setup for external dependencies
placeholder: "[module]"
examples:
  - "Add comprehensive tests for auth module"
  - "Add comprehensive tests for payment service"
  - "Add comprehensive tests for data pipeline"
```

#### Fix lint errors

```yaml
template: fix-lint-errors
description: "Fix all lint errors"
suggested_mode: yolo
estimated_stories: 1
expected_output:
  - All lint errors resolved
  - No functional changes
  - Clean lint run
placeholder: null
```

#### Add dark mode

```yaml
template: add-dark-mode
description: "Add dark mode toggle"
suggested_mode: checkpoint
estimated_stories: 2-3
expected_output:
  - Theme toggle component
  - CSS variables or Tailwind dark classes
  - Persisted preference (localStorage)
  - System preference detection
  - Smooth transition animation
placeholder: null
```

#### Database migration

```yaml
template: database-migration
description: "Add [table] to database"
suggested_mode: checkpoint
estimated_stories: 2-3
expected_output:
  - Migration file with up/down
  - Model/schema definition
  - Seed data (if applicable)
  - Updated type definitions
placeholder: "[table]"
examples:
  - "Add orders table to database"
  - "Add notifications table to database"
  - "Add audit_logs table to database"
```

## Content Templates

| Template | Description | Maestro Command |
|----------|-------------|-----------------|
| Blog post | SEO-optimized article with meta tags | `/maestro "Write a blog post about [topic]"` |
| Case study | Problem-solution-results with metrics | `/maestro "Write case study about [client/project]"` |
| Documentation | Technical docs for a feature or API | `/maestro "Write documentation for [feature]"` |
| Landing page | Hero, features, CTA, social proof | `/maestro "Build landing page for [product]"` |

### Template Details: Content

#### Blog post

```yaml
template: blog-post
description: "Write a blog post about [topic]"
suggested_mode: checkpoint
estimated_stories: 1-2
expected_output:
  - SEO-optimized title and meta description
  - Structured headings (H2, H3)
  - 1500-2500 words
  - Internal/external links
  - Call to action
placeholder: "[topic]"
examples:
  - "Write a blog post about microservices vs monoliths"
  - "Write a blog post about our Series A journey"
  - "Write a blog post about React Server Components"
```

#### Case study

```yaml
template: case-study
description: "Write case study about [client/project]"
suggested_mode: checkpoint
estimated_stories: 1-2
expected_output:
  - Problem statement
  - Solution description
  - Implementation timeline
  - Results with metrics
  - Client quote placeholder
  - Before/after comparison
placeholder: "[client/project]"
examples:
  - "Write case study about Acme Corp migration"
  - "Write case study about our internal tooling rebuild"
```

## Marketing Templates

| Template | Description | Maestro Command |
|----------|-------------|-----------------|
| Competitor analysis | Research 3-5 competitors across features/pricing | `/maestro "Analyze competitors for [product]"` |
| Content calendar | 3-month plan with topics and keywords | `/maestro "Create content calendar for [audience]"` |
| Ad copy | 20+ variations for Google/Meta/LinkedIn | `/maestro "Generate ad copy for [product]"` |
| Email sequence | Onboarding or nurture drip campaign | `/maestro "Create email sequence for [goal]"` |

### Template Details: Marketing

#### Competitor analysis

```yaml
template: competitor-analysis
description: "Analyze competitors for [product]"
suggested_mode: checkpoint
estimated_stories: 1-2
expected_output:
  - 3-5 competitor profiles
  - Feature comparison matrix
  - Pricing comparison
  - Strengths/weaknesses analysis
  - Market positioning map
  - Recommended differentiators
placeholder: "[product]"
examples:
  - "Analyze competitors for our project management tool"
  - "Analyze competitors for our email marketing platform"
```

#### Content calendar

```yaml
template: content-calendar
description: "Create content calendar for [audience]"
suggested_mode: checkpoint
estimated_stories: 1
expected_output:
  - 3-month content plan
  - Weekly topics with working titles
  - Target keywords per piece
  - Content type mix (blog, social, video)
  - Seasonal/event tie-ins
placeholder: "[audience]"
examples:
  - "Create content calendar for developer audience"
  - "Create content calendar for SaaS founders"
```

#### Ad copy

```yaml
template: ad-copy
description: "Generate ad copy for [product]"
suggested_mode: yolo
estimated_stories: 1
expected_output:
  - 5+ Google Ads headlines (30 chars)
  - 5+ Google Ads descriptions (90 chars)
  - 5+ Meta ad primary texts
  - 5+ LinkedIn ad variations
  - A/B test recommendations
placeholder: "[product]"
examples:
  - "Generate ad copy for our analytics dashboard"
  - "Generate ad copy for our developer API"
```

## Research Templates

| Template | Description | Maestro Command |
|----------|-------------|-----------------|
| Tech evaluation | Compare tools/frameworks for a decision | `/maestro "Evaluate [options] for [use case]"` |
| Architecture review | Analyze current architecture, suggest improvements | `/maestro "Review architecture of [system]"` |
| Security audit | Scan for common vulnerabilities | `/maestro "Security audit for [component]"` |

### Template Details: Research

#### Tech evaluation

```yaml
template: tech-evaluation
description: "Evaluate [options] for [use case]"
suggested_mode: checkpoint
estimated_stories: 1-2
expected_output:
  - Evaluation criteria matrix
  - Pros/cons for each option
  - Performance benchmarks (if available)
  - Community/ecosystem comparison
  - Recommendation with rationale
placeholder: "[options] for [use case]"
examples:
  - "Evaluate Prisma vs Drizzle vs TypeORM for our API"
  - "Evaluate Next.js vs Remix vs Astro for our marketing site"
```

## Template Selection Flow

The `/maestro quick-start` command uses AskUserQuestion to guide the user through template selection:

### Step 1: Category Selection

**Question**: "What kind of work?"
**Options**:
- Code -- API endpoints, auth, tests, migrations
- Content -- Blog posts, case studies, documentation
- Marketing -- Competitor analysis, ad copy, calendars
- Research -- Tech evaluations, architecture reviews

### Step 2: Template Selection

Based on the category, show 3-6 templates with descriptions. For example, if "Code" is selected:

**Question**: "Pick a template"
**Options**:
- Add API endpoint -- REST endpoint with validation, auth, tests
- Add authentication -- Email/password or OAuth login flow
- Add test suite -- Unit + integration tests for existing code
- Fix lint errors -- Auto-fix all linting issues (yolo mode)

### Step 3: Placeholder Fill

If the selected template has a placeholder (e.g., `[resource]`), ask the user to fill it in:

**Question**: "What [resource]? (e.g., users, products, payments)"

### Step 4: Confirmation

Show the final command and ask for confirmation:

```
[maestro] Ready to run:

  /maestro "Add users API endpoint"

  Mode       checkpoint
  Estimate   3-4 stories, ~$2.50
```

**Question**: "Run this now?"
**Options**:
- Yes, run it
- Customize first (change mode, add details)
- Cancel
