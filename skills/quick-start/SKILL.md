---
name: quick-start
description: "Pre-built task templates for common development and knowledge work patterns. Pick a template instead of typing a description."
---

# Quick Start Templates

Pre-built templates for common tasks. Instead of thinking about how to phrase a feature request, pick a template and fill in the blank. Zero thinking required.

## How to Use

1. Run `/maestro quick-start`
2. Pick a category (Code / Project / Content / Marketing / Research)
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

---

## Project Templates

Bootstrap a complete project from zero. Each template produces a working skeleton with tooling, CI, and an initial set of Maestro stories ready to execute.

| Template | Stack | Complexity | Maestro Command |
|----------|-------|------------|-----------------|
| REST API | Node.js + Express + PostgreSQL | medium | `/maestro "Bootstrap REST API named [name]"` |
| GraphQL API | Node.js + Apollo Server + Prisma | medium | `/maestro "Bootstrap GraphQL API named [name]"` |
| Full-Stack Web App | Next.js + Tailwind + PostgreSQL | high | `/maestro "Bootstrap full-stack app named [name]"` |
| Landing Page | Next.js/Astro + Tailwind | simple | `/maestro "Bootstrap landing page for [product]"` |
| CLI Tool | Node.js or Python | simple | `/maestro "Bootstrap CLI tool named [name]"` |
| DevOps Script | Bash or Python | simple | `/maestro "Bootstrap DevOps script for [task]"` |
| NPM Package | TypeScript library | medium | `/maestro "Bootstrap NPM package named [name]"` |
| Python Package | Python + pyproject.toml | medium | `/maestro "Bootstrap Python package named [name]"` |
| React Native App | Expo + TypeScript | high | `/maestro "Bootstrap React Native app named [name]"` |
| Flutter App | Dart + Flutter | high | `/maestro "Bootstrap Flutter app named [name]"` |
| Data Pipeline | Python + pandas/polars | medium | `/maestro "Bootstrap data pipeline for [source] to [destination]"` |
| ML Training | Python + PyTorch/scikit-learn | high | `/maestro "Bootstrap ML training project for [task]"` |

### Template Details: Project

---

#### REST API

```yaml
template: bootstrap-rest-api
description: "Bootstrap REST API named [name]"
tech_stack:
  language: TypeScript
  runtime: Node.js
  framework: Express
  database: PostgreSQL
  orm: Drizzle or Prisma
  testing: Vitest
  linting: ESLint + Prettier
complexity: medium
suggested_mode: checkpoint
estimated_stories: 5
placeholder: "[name]"
examples:
  - "Bootstrap REST API named inventory-service"
  - "Bootstrap REST API named user-service"
stories:
  - id: 1
    title: "Project setup"
    description: "Initialize TypeScript project with Express, ESLint, Prettier, and Vitest"
    acceptance_criteria:
      - "package.json with all dev and runtime dependencies"
      - "tsconfig.json configured for Node.js with strict mode"
      - "ESLint + Prettier configs with no lint errors on empty project"
      - "`npm run dev` starts a server responding 200 on GET /healthz"
      - "`npm test` runs and exits 0 with at least one passing smoke test"
  - id: 2
    title: "Database schema and migrations"
    description: "Configure PostgreSQL connection and define initial schema with migration tooling"
    acceptance_criteria:
      - "DATABASE_URL env var wired through dotenv"
      - "ORM client initializes and connects without error"
      - "At least one migration file that creates a `users` table"
      - "`npm run migrate` applies migrations idempotently"
      - "Rollback command documented in README"
  - id: 3
    title: "Auth endpoints (register, login, refresh)"
    description: "Implement JWT-based auth with password hashing"
    acceptance_criteria:
      - "POST /auth/register creates user, returns 201 with userId"
      - "POST /auth/login returns signed access token (15 min) and refresh token (7 days)"
      - "POST /auth/refresh exchanges valid refresh token for new access token"
      - "Passwords stored as bcrypt hashes, never returned in responses"
      - "Integration tests cover happy path and error cases (duplicate email, bad credentials)"
  - id: 4
    title: "Core CRUD endpoints"
    description: "Generate a representative CRUD resource wired to the database"
    acceptance_criteria:
      - "GET /[resource] returns paginated list (limit/offset)"
      - "GET /[resource]/:id returns single record or 404"
      - "POST /[resource] validates body and creates record"
      - "PATCH /[resource]/:id applies partial update"
      - "DELETE /[resource]/:id soft-deletes or hard-deletes with 204"
      - "All routes protected by auth middleware"
  - id: 5
    title: "Error handling, validation, and OpenAPI docs"
    description: "Centralized error handler, Zod validation, and auto-generated OpenAPI spec"
    acceptance_criteria:
      - "Global error handler returns consistent `{ error, code, details }` shape"
      - "Zod schemas validate all request bodies; validation errors return 422 with field list"
      - "OpenAPI 3.1 spec auto-generated and served at GET /docs"
      - "All endpoints documented in spec"
      - "No unhandled promise rejections in any test scenario"
```

---

#### GraphQL API

```yaml
template: bootstrap-graphql-api
description: "Bootstrap GraphQL API named [name]"
tech_stack:
  language: TypeScript
  runtime: Node.js
  server: Apollo Server v4
  orm: Prisma
  database: PostgreSQL
  testing: Vitest + Apollo testing utilities
  linting: ESLint + Prettier
complexity: medium
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[name]"
examples:
  - "Bootstrap GraphQL API named content-graph"
  - "Bootstrap GraphQL API named product-catalog"
stories:
  - id: 1
    title: "Schema-first setup with TypeScript"
    description: "Initialize Apollo Server with a schema-first approach and codegen"
    acceptance_criteria:
      - "Apollo Server v4 running at /graphql with GraphQL Playground in dev"
      - "Prisma client configured and connected to PostgreSQL"
      - "graphql-codegen generates TypeScript types from schema on `npm run codegen`"
      - "Health check query `{ _health }` returns `ok`"
      - "`npm test` runs and passes with at least one resolver test"
  - id: 2
    title: "Resolver implementation"
    description: "Implement Query and Mutation resolvers for the core domain entity"
    acceptance_criteria:
      - "Query resolvers read from database via Prisma"
      - "Mutation resolvers create/update/delete records"
      - "DataLoader used to batch N+1 queries on nested fields"
      - "Each resolver has at least one passing unit test"
      - "Resolver errors map to GraphQL errors with appropriate extensions.code"
  - id: 3
    title: "Auth and authorization middleware"
    description: "JWT verification in context builder and field-level authorization"
    acceptance_criteria:
      - "Authorization header parsed in context builder; user attached to context"
      - "Unauthenticated requests to protected operations return UNAUTHENTICATED error"
      - "Role-based field authorization via a `@auth` directive or guard helper"
      - "Tests cover authenticated, unauthenticated, and unauthorized scenarios"
  - id: 4
    title: "Pagination and filtering"
    description: "Add cursor-based pagination and filter arguments to list queries"
    acceptance_criteria:
      - "List queries accept `first`, `after` (cursor) arguments"
      - "Response includes `pageInfo { hasNextPage, endCursor }`"
      - "Filter arguments accept common operators (eq, contains, gte, lte)"
      - "Pagination and filter logic tested with at least 5 test cases"
      - "Prisma queries use `where` and `cursor` correctly -- no full-table scans for paginated queries"
```

---

#### Full-Stack Web App

```yaml
template: bootstrap-fullstack-web
description: "Bootstrap full-stack app named [name]"
tech_stack:
  language: TypeScript
  framework: Next.js 14+ (App Router)
  styling: Tailwind CSS
  database: PostgreSQL
  orm: Drizzle
  auth: NextAuth.js or Lucia
  testing: Vitest + Playwright
  deployment: Vercel or Docker
complexity: high
suggested_mode: checkpoint
estimated_stories: 5
placeholder: "[name]"
examples:
  - "Bootstrap full-stack app named project-tracker"
  - "Bootstrap full-stack app named team-wiki"
stories:
  - id: 1
    title: "Next.js project with App Router"
    description: "Initialize Next.js with TypeScript, Tailwind, and project conventions"
    acceptance_criteria:
      - "Next.js app created with App Router and `src/` layout"
      - "Tailwind configured with a base design token set (colors, spacing, fonts)"
      - "ESLint + Prettier passing with zero errors"
      - "`npm run dev` serves root page with no console errors"
      - "`npm test` runs Vitest with at least one passing test"
  - id: 2
    title: "Database and ORM setup"
    description: "Wire PostgreSQL via Drizzle with initial schema and migration workflow"
    acceptance_criteria:
      - "Drizzle schema file defines at least `users` table"
      - "`npm run db:migrate` applies migrations"
      - "`npm run db:studio` opens Drizzle Studio without error"
      - "Database connection pooled (pg or postgres.js)"
      - "Schema types exported and used in Server Components"
  - id: 3
    title: "Auth system"
    description: "Email/password and/or OAuth login with session management"
    acceptance_criteria:
      - "Sign in, sign up, and sign out flows working end-to-end"
      - "Session stored in HTTP-only cookie"
      - "`useSession` / `auth()` hook available in client and server components"
      - "Protected routes redirect unauthenticated users to /login"
      - "Playwright E2E test covers login and protected page access"
  - id: 4
    title: "Core feature pages"
    description: "Scaffold the main application screens with data fetching"
    acceptance_criteria:
      - "Dashboard page with Server Component data fetch"
      - "List page with search and pagination"
      - "Detail/edit page with optimistic UI update"
      - "All pages mobile-responsive"
      - "Loading and error states implemented for each page"
  - id: 5
    title: "Deployment config"
    description: "Prepare project for production deployment"
    acceptance_criteria:
      - "Vercel config (vercel.json) or Dockerfile present and validated"
      - "Environment variable documentation in .env.example"
      - "`npm run build` succeeds with no TypeScript errors"
      - "GitHub Actions workflow runs lint + test + build on every PR"
      - "README documents local setup in under 5 steps"
```

---

#### Landing Page

```yaml
template: bootstrap-landing-page
description: "Bootstrap landing page for [product]"
tech_stack:
  language: TypeScript
  framework: Next.js or Astro
  styling: Tailwind CSS
  forms: React Hook Form or Astro form actions
  analytics: Plausible or Google Analytics (config only)
complexity: simple
suggested_mode: checkpoint
estimated_stories: 5
placeholder: "[product]"
examples:
  - "Bootstrap landing page for Acme SaaS"
  - "Bootstrap landing page for open-source CLI tool"
stories:
  - id: 1
    title: "Hero section and CTA"
    description: "Above-the-fold section with headline, subheading, and primary call-to-action"
    acceptance_criteria:
      - "Headline and subheading rendered as H1/H2 with correct semantic markup"
      - "Primary CTA button links to sign-up or anchor section"
      - "Hero section is full viewport height on desktop"
      - "Mobile layout stacks elements vertically with readable font sizes"
      - "Lighthouse performance score >= 90 on mobile"
  - id: 2
    title: "Feature grid"
    description: "Three to six feature cards with icon, title, and description"
    acceptance_criteria:
      - "Feature grid renders 3-6 cards in a responsive CSS grid"
      - "Each card has SVG icon, bold title, and 1-2 sentence description"
      - "Grid collapses to single column on mobile"
      - "Card content driven by a data array (easy to edit without touching markup)"
  - id: 3
    title: "Pricing table"
    description: "Two or three pricing tiers with feature comparison"
    acceptance_criteria:
      - "At least 2 pricing tiers displayed side-by-side on desktop"
      - "Each tier shows: name, price, billing period, feature list, and CTA"
      - "Most popular tier visually highlighted"
      - "Tiers stack vertically on mobile"
      - "Prices and features driven by a data array"
  - id: 4
    title: "Contact form"
    description: "Email contact form with validation and submission feedback"
    acceptance_criteria:
      - "Form fields: name, email, message -- all required"
      - "Client-side validation with inline error messages"
      - "Submission sends data to an API route or form service (Formspree/Resend)"
      - "Success state shows confirmation message; error state shows retry prompt"
      - "Form is keyboard accessible and passes axe-core audit"
  - id: 5
    title: "SEO optimization"
    description: "Meta tags, OG image, sitemap, and robots.txt"
    acceptance_criteria:
      - "Title, description, and canonical meta tags set per page"
      - "Open Graph and Twitter card meta tags present with og:image"
      - "sitemap.xml generated and accessible at /sitemap.xml"
      - "robots.txt present and allows all crawlers"
      - "Lighthouse SEO score = 100"
```

---

#### CLI Tool

```yaml
template: bootstrap-cli-tool
description: "Bootstrap CLI tool named [name]"
tech_stack:
  language: Node.js (TypeScript) or Python
  argument_parsing: commander.js (Node) or Click/Typer (Python)
  testing: Vitest (Node) or pytest (Python)
  packaging: npm link / pip install -e
  ci: GitHub Actions
complexity: simple
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[name]"
examples:
  - "Bootstrap CLI tool named db-snapshot"
  - "Bootstrap CLI tool named deploy-helper"
stories:
  - id: 1
    title: "Command structure and help system"
    description: "Root command with --help, --version, and subcommand scaffolding"
    acceptance_criteria:
      - "`[name] --help` prints usage, description, and lists all subcommands"
      - "`[name] --version` prints semver from package.json or pyproject.toml"
      - "Unknown flags print a friendly error and suggest --help"
      - "Entry point is executable (`chmod +x` or console_scripts)"
      - "At least one unit test verifies help output contains expected strings"
  - id: 2
    title: "Core command implementation"
    description: "Implement the primary subcommand with flags and output formatting"
    acceptance_criteria:
      - "Primary subcommand accepts documented flags and positional arguments"
      - "Success output uses structured format (table or JSON with --json flag)"
      - "Errors print to stderr and exit with non-zero code"
      - "Long-running operations show progress indicator"
      - "Unit and integration tests cover primary subcommand"
  - id: 3
    title: "Config file support"
    description: "Load defaults from a config file in the project root or home directory"
    acceptance_criteria:
      - "Reads config from `.[name]rc` or `[name].config.json` if present"
      - "CLI flags override config file values"
      - "`[name] config init` writes a default config file"
      - "Config schema documented in README"
      - "Test verifies config file values are applied correctly"
  - id: 4
    title: "Testing and CI/CD"
    description: "Full test suite and GitHub Actions workflow"
    acceptance_criteria:
      - "Test coverage >= 80% on core logic"
      - "GitHub Actions workflow runs tests on Node 18/20 (or Python 3.11/3.12)"
      - "Workflow caches dependencies for fast runs"
      - "README includes install instructions and 3 usage examples"
      - "CHANGELOG.md initialized"
```

---

#### DevOps Script

```yaml
template: bootstrap-devops-script
description: "Bootstrap DevOps script for [task]"
tech_stack:
  language: Bash or Python
  logging: structured log lines with timestamps
  config: environment variables or YAML/TOML config file
  error_handling: set -euo pipefail (Bash) or sys.exit with logging (Python)
complexity: simple
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[task]"
examples:
  - "Bootstrap DevOps script for nightly database backup"
  - "Bootstrap DevOps script for log rotation and archival"
stories:
  - id: 1
    title: "Core automation logic"
    description: "Main script body implementing the primary automation task"
    acceptance_criteria:
      - "Script accepts --dry-run flag that logs actions without executing them"
      - "Primary task implemented and manually verified in dry-run mode"
      - "Script exits 0 on success, non-zero on failure"
      - "Usage comment block at top of file documents purpose, flags, and examples"
      - "Script is idempotent: running it twice produces the same end state"
  - id: 2
    title: "Error handling and logging"
    description: "Robust error handling with structured log output"
    acceptance_criteria:
      - "All errors caught and logged with timestamp, severity, and message"
      - "Bash scripts use `set -euo pipefail`; Python scripts use try/except at top level"
      - "Log lines follow format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`"
      - "Critical failures send alert (email, Slack webhook, or PagerDuty) if configured"
      - "Partial failure leaves system in a safe, documented state"
  - id: 3
    title: "Configuration management"
    description: "Externalize all tuneable values to env vars or a config file"
    acceptance_criteria:
      - "All hardcoded values (paths, thresholds, credentials) moved to config"
      - "Config loaded from environment variables with sensible defaults"
      - "Optional YAML/TOML config file overrides env vars"
      - "Missing required config causes immediate exit with descriptive error"
      - "Config documented in README with example values"
  - id: 4
    title: "Documentation"
    description: "README, inline comments, and operational runbook"
    acceptance_criteria:
      - "README describes what the script does, prerequisites, and how to run it"
      - "Setup section covers permissions, dependencies, and cron/systemd scheduling"
      - "Inline comments explain non-obvious logic"
      - "Runbook section in README covers common failure modes and recovery steps"
      - "CHANGELOG initialized with initial version entry"
```

---

#### NPM Package

```yaml
template: bootstrap-npm-package
description: "Bootstrap NPM package named [name]"
tech_stack:
  language: TypeScript
  bundler: tsup or unbuild
  testing: Vitest
  linting: ESLint + Prettier
  publishing: npm publish via GitHub Actions
complexity: medium
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[name]"
examples:
  - "Bootstrap NPM package named date-fns-business"
  - "Bootstrap NPM package named react-use-form"
stories:
  - id: 1
    title: "Package setup with tsconfig, ESLint, and Vitest"
    description: "Initialize package with dual CJS/ESM output, strict TypeScript, and test runner"
    acceptance_criteria:
      - "package.json exports CJS and ESM via `exports` field"
      - "tsconfig.json has strict mode; `npm run typecheck` exits 0"
      - "ESLint + Prettier configured; `npm run lint` exits 0 on empty src"
      - "`npm run build` emits to dist/ with type declarations (.d.ts)"
      - "`npm test` runs Vitest and passes with at least one smoke test"
  - id: 2
    title: "Core module implementation"
    description: "Implement the primary exported functions with full type safety"
    acceptance_criteria:
      - "All public functions exported from package root (index.ts)"
      - "Function signatures are fully typed with no `any`"
      - "JSDoc comments on every exported function and type"
      - "Tree-shakeable: named exports only, no side effects at import time"
      - "Test coverage >= 90% on core module"
  - id: 3
    title: "API design and types"
    description: "Finalize public API surface with strict TypeScript types"
    acceptance_criteria:
      - "Public API documented in README with TypeScript code examples"
      - "Discriminated unions or branded types used where appropriate"
      - "No breaking API changes without major version bump (documented in CHANGELOG)"
      - "Types compatible with TypeScript 4.9+ and 5.x"
      - "API surface reviewed against similar packages -- no accidental overlap"
  - id: 4
    title: "Publishing workflow"
    description: "GitHub Actions workflow for automated npm publish on tag push"
    acceptance_criteria:
      - "GitHub Actions workflow triggers on `v*` tag push"
      - "Workflow runs lint + test + build before publish"
      - "NPM_TOKEN stored as GitHub secret; not logged"
      - "`npm publish --dry-run` succeeds locally"
      - "README has install badge and quick-start code snippet"
```

---

#### Python Package

```yaml
template: bootstrap-python-package
description: "Bootstrap Python package named [name]"
tech_stack:
  language: Python 3.11+
  packaging: pyproject.toml (hatchling or flit)
  testing: pytest + pytest-cov
  linting: ruff + mypy
  publishing: PyPI via GitHub Actions (Trusted Publisher)
complexity: medium
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[name]"
examples:
  - "Bootstrap Python package named csv-cleaner"
  - "Bootstrap Python package named async-retry"
stories:
  - id: 1
    title: "Project structure with pytest and ruff"
    description: "Initialize pyproject.toml, src layout, and CI-ready tooling"
    acceptance_criteria:
      - "src/[name]/__init__.py present and importable"
      - "pyproject.toml defines project metadata, dependencies, and tool configs"
      - "`python -m pytest` runs and passes with at least one smoke test"
      - "`ruff check .` exits 0 on empty src"
      - "`mypy src/` exits 0 with strict config"
  - id: 2
    title: "Core module"
    description: "Implement primary public functions with type hints"
    acceptance_criteria:
      - "All public functions in `[name]/core.py` or logical submodules"
      - "Every function has full type annotations (no `Any` without justification)"
      - "Docstrings follow Google or NumPy style consistently"
      - "Test coverage >= 90% (`pytest --cov=[name] --cov-fail-under=90`)"
      - "No mutable default arguments; no global state"
  - id: 3
    title: "Type hints and docs"
    description: "Strict typing, docstring completeness, and API reference generation"
    acceptance_criteria:
      - "`mypy src/` passes with `--strict` flag"
      - "All public symbols have docstrings (verified by `pydocstyle` or ruff D rules)"
      - "Sphinx or mkdocs-material configured; `make docs` builds HTML without errors"
      - "README has usage example runnable with `python -c`"
      - "CHANGELOG.md initialized with version 0.1.0 entry"
  - id: 4
    title: "PyPI publishing"
    description: "GitHub Actions workflow for automated PyPI publish via Trusted Publisher"
    acceptance_criteria:
      - "GitHub Actions workflow triggers on `v*` tag push"
      - "Workflow runs ruff + mypy + pytest before publish"
      - "PyPI Trusted Publisher configured (no long-lived token)"
      - "`python -m build` succeeds and produces wheel + sdist"
      - "Package installable with `pip install [name]` after publish"
```

---

#### React Native App

```yaml
template: bootstrap-react-native
description: "Bootstrap React Native app named [name]"
tech_stack:
  language: TypeScript
  framework: Expo SDK 50+
  navigation: Expo Router (file-based)
  state: Zustand or Jotai
  api_client: TanStack Query + fetch/axios
  testing: Jest + React Native Testing Library
complexity: high
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[name]"
examples:
  - "Bootstrap React Native app named field-reporter"
  - "Bootstrap React Native app named habit-tracker"
stories:
  - id: 1
    title: "Expo setup and navigation"
    description: "Initialize Expo project with TypeScript, Expo Router, and tab or stack navigation"
    acceptance_criteria:
      - "Expo project created with `create-expo-app` and TypeScript template"
      - "Expo Router configured; at least two screens navigable"
      - "Tab bar or drawer navigation visible on app launch"
      - "`npx expo start` runs without errors on iOS and Android simulators"
      - "Absolute imports configured via tsconfig paths"
  - id: 2
    title: "Core screens"
    description: "Scaffold the main screens with placeholder content and navigation"
    acceptance_criteria:
      - "At least 3 screens implemented: list, detail, and settings"
      - "Each screen has a descriptive header title"
      - "Back navigation works correctly between all screens"
      - "Screens are keyboard-aware (KeyboardAvoidingView where applicable)"
      - "Each screen has at least one passing React Native Testing Library test"
  - id: 3
    title: "State management"
    description: "Global state store with persistence via AsyncStorage"
    acceptance_criteria:
      - "Zustand or Jotai store created with typed state and actions"
      - "State persisted to AsyncStorage with `persist` middleware or equivalent"
      - "Store rehydrates correctly on app restart"
      - "State mutations tested in isolation (no component rendering required)"
      - "No prop drilling beyond 2 levels -- all shared state in store"
  - id: 4
    title: "API integration"
    description: "TanStack Query setup with typed API client and loading/error states"
    acceptance_criteria:
      - "TanStack Query configured with QueryClient and QueryClientProvider"
      - "API base URL configurable via Expo env vars"
      - "At least one query and one mutation implemented with full loading/error/success states"
      - "Offline behavior documented (stale time, retry config)"
      - "API types generated from OpenAPI spec or hand-authored in types/api.ts"
```

---

#### Flutter App

```yaml
template: bootstrap-flutter
description: "Bootstrap Flutter app named [name]"
tech_stack:
  language: Dart
  framework: Flutter stable channel
  routing: GoRouter
  state: Riverpod or BLoC
  api_client: Dio + Freezed DTOs
  testing: flutter_test + mocktail
complexity: high
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[name]"
examples:
  - "Bootstrap Flutter app named expense-tracker"
  - "Bootstrap Flutter app named event-scanner"
stories:
  - id: 1
    title: "Project setup and routing"
    description: "Initialize Flutter project with GoRouter and a base navigation scaffold"
    acceptance_criteria:
      - "Flutter project created with `flutter create` and null-safety enabled"
      - "GoRouter configured with at least 3 named routes"
      - "Bottom navigation bar or drawer visible on launch"
      - "`flutter run` builds and launches on iOS and Android simulators without errors"
      - "Analysis options set to `flutter_lints` with zero lint warnings"
  - id: 2
    title: "Core screens"
    description: "Implement primary app screens with proper widget decomposition"
    acceptance_criteria:
      - "At least 3 screens: list, detail, and settings"
      - "Widgets decomposed into reusable components in lib/widgets/"
      - "Each screen has AppBar with contextual actions"
      - "Screens scroll correctly on small-screen devices"
      - "Widget tests cover each screen's happy-path render"
  - id: 3
    title: "State management (Riverpod or BLoC)"
    description: "Implement state layer with chosen state management solution"
    acceptance_criteria:
      - "Providers (Riverpod) or Blocs (BLoC) defined for each feature"
      - "State classes use Freezed for immutability and copyWith"
      - "Loading, error, and data states handled in UI"
      - "State logic unit-tested without Flutter framework"
      - "No setState() calls outside of StatefulWidgets that own purely local UI state"
  - id: 4
    title: "API integration"
    description: "Dio HTTP client with Freezed DTOs and error handling"
    acceptance_criteria:
      - "Dio client configured with base URL and interceptors (logging, auth header)"
      - "Response DTOs generated with Freezed and json_serializable"
      - "Repository layer abstracts HTTP calls from state management"
      - "Network errors surface in UI with retry option"
      - "Mocked HTTP responses used in integration tests (mocktail)"
```

---

#### Data Pipeline

```yaml
template: bootstrap-data-pipeline
description: "Bootstrap data pipeline for [source] to [destination]"
tech_stack:
  language: Python 3.11+
  dataframes: pandas or polars
  scheduling: cron, Prefect, or Airflow
  storage: local files, S3, or BigQuery (configurable)
  testing: pytest + pytest-mock
  logging: structlog
complexity: medium
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[source] to [destination]"
examples:
  - "Bootstrap data pipeline for Postgres to BigQuery"
  - "Bootstrap data pipeline for CSV files to Parquet"
stories:
  - id: 1
    title: "Extract from sources"
    description: "Implement extractors for the configured source system(s)"
    acceptance_criteria:
      - "Extractor reads from source and returns a typed DataFrame"
      - "Connection config loaded from environment variables"
      - "Extractor supports incremental load via a watermark (updated_at or offset)"
      - "Extraction errors raise a typed exception with source context"
      - "Unit tests use fixture data to avoid hitting real source in CI"
  - id: 2
    title: "Transform and validate"
    description: "Apply business transformations and validate data quality"
    acceptance_criteria:
      - "Transformation functions are pure: input DataFrame -> output DataFrame"
      - "Pandera or Great Expectations schema validates output shape and types"
      - "Rows failing validation are quarantined to a dead-letter location, not silently dropped"
      - "All transformations covered by unit tests with edge-case fixtures"
      - "Column renaming, type casting, and null handling documented in docstrings"
  - id: 3
    title: "Load to destination"
    description: "Implement loaders that write transformed data to the destination"
    acceptance_criteria:
      - "Loader writes to destination in configured format (Parquet, CSV, SQL, etc.)"
      - "Upsert or append mode configurable per run"
      - "Loader is idempotent: re-running with the same data produces the same result"
      - "Write errors trigger rollback or dead-letter logging"
      - "Integration test verifies round-trip extract -> transform -> load"
  - id: 4
    title: "Scheduling and monitoring"
    description: "Schedule pipeline runs and emit health metrics"
    acceptance_criteria:
      - "Pipeline runnable as a cron job or via Prefect/Airflow flow"
      - "Each run emits structured log lines with row counts and duration"
      - "Alert sent on failure via configured channel (email, Slack, PagerDuty)"
      - "README documents schedule, retry policy, and on-call runbook"
      - "Dry-run mode logs planned actions without writing to destination"
```

---

#### ML Training

```yaml
template: bootstrap-ml-training
description: "Bootstrap ML training project for [task]"
tech_stack:
  language: Python 3.11+
  framework: PyTorch or scikit-learn
  experiment_tracking: MLflow or Weights & Biases
  data: pandas + sklearn datasets or HuggingFace datasets
  testing: pytest
  environment: conda or venv with requirements.txt / pyproject.toml
complexity: high
suggested_mode: checkpoint
estimated_stories: 4
placeholder: "[task]"
examples:
  - "Bootstrap ML training project for image classification"
  - "Bootstrap ML training project for churn prediction"
stories:
  - id: 1
    title: "Data loading and preprocessing"
    description: "Implement a Dataset class or pipeline that loads, cleans, and splits data"
    acceptance_criteria:
      - "Dataset loads from local files or a URL with caching"
      - "Preprocessing pipeline handles missing values, outliers, and encoding"
      - "Train/validation/test split reproducible via a random seed config"
      - "Data shapes and dtypes logged after each preprocessing step"
      - "Unit tests verify preprocessing output on a tiny synthetic dataset"
  - id: 2
    title: "Model architecture"
    description: "Define the model class with configurable hyperparameters"
    acceptance_criteria:
      - "Model defined as a class (nn.Module for PyTorch or sklearn Pipeline)"
      - "Hyperparameters externalised to a config file (YAML or dataclass)"
      - "Forward pass tested with random input tensor / sample row"
      - "Parameter count logged on model instantiation"
      - "Model serializable with torch.save / joblib.dump"
  - id: 3
    title: "Training loop"
    description: "Implement training with checkpointing and experiment tracking"
    acceptance_criteria:
      - "Training loop runs for configured epochs with loss logged per step"
      - "Validation loss computed at end of each epoch"
      - "Best checkpoint saved when validation loss improves"
      - "MLflow or W&B run created; hyperparameters and metrics logged"
      - "Training resumable from a checkpoint"
  - id: 4
    title: "Evaluation and metrics"
    description: "Compute task-appropriate metrics on the test set and produce a report"
    acceptance_criteria:
      - "Task-appropriate metrics computed (accuracy/F1 for classification, RMSE/MAE for regression)"
      - "Confusion matrix or residual plot saved to artifacts/"
      - "Evaluation script accepts a checkpoint path and test dataset path as arguments"
      - "Metrics logged to experiment tracker and printed to stdout"
      - "README documents how to reproduce the evaluation with a single command"
```

---

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

---

## Template Selection Flow

The `/maestro quick-start` command uses AskUserQuestion to guide the user through template selection:

### Step 1: Category Selection

**Question**: "What kind of work?"
**Options**:
- Code -- API endpoints, auth, tests, migrations
- Project -- Bootstrap a new project from scratch
- Content -- Blog posts, case studies, documentation
- Marketing -- Competitor analysis, ad copy, calendars
- Research -- Tech evaluations, architecture reviews

### Step 2: Template Selection

Based on the category, show 3-6 templates with descriptions. For example, if "Project" is selected:

**Question**: "Pick a project type"
**Options**:
- REST API -- Node.js + Express + PostgreSQL + TypeScript (medium)
- GraphQL API -- Apollo Server + Prisma + PostgreSQL (medium)
- Full-Stack Web App -- Next.js + Tailwind + PostgreSQL (high)
- Landing Page -- Next.js/Astro + Tailwind (simple)
- CLI Tool -- Node.js or Python with argument parsing (simple)
- DevOps Script -- Bash or Python automation (simple)
- NPM Package -- TypeScript library with publishing workflow (medium)
- Python Package -- Python + pyproject.toml + PyPI (medium)
- React Native App -- Expo + TypeScript + GoRouter (high)
- Flutter App -- Dart + Flutter + Riverpod/BLoC (high)
- Data Pipeline -- Python + pandas/polars + scheduling (medium)
- ML Training -- Python + PyTorch/scikit-learn + MLflow (high)

### Step 3: Placeholder Fill

If the selected template has a placeholder (e.g., `[name]`), ask the user to fill it in:

**Question**: "What should the project be named?"

### Step 4: Confirmation

Show the final command and ask for confirmation:

```
[maestro] Ready to run:

  /maestro "Bootstrap REST API named inventory-service"

  Mode       checkpoint
  Estimate   5 stories, ~$4.00
  Stack      TypeScript + Express + PostgreSQL + Vitest
```

**Question**: "Run this now?"
**Options**:
- Yes, run it
- Customize first (change mode, add details)
- Cancel
