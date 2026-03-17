---
name: project-dna
description: "Auto-discover project patterns, tech stack, conventions, and architecture. Produces .maestro/dna.md — the project's DNA profile used by the Context Engine."
---

# Project DNA

Auto-discovers the project's technical DNA by scanning its codebase, configuration, and conventions. Produces a structured profile that the Context Engine uses to select relevant context for each agent.

## Input

- Project root directory (current working directory)
- Optional: `$ARGUMENTS` to focus on specific aspects (e.g., "update after adding auth")

## Process

### Step 1: Detect Tech Stack

Scan for package manifests and configuration files:

| File | Detects |
|------|---------|
| `package.json` | Node.js ecosystem, framework (Next.js, Nuxt, Remix, Astro, Vite), dependencies |
| `Cargo.toml` | Rust ecosystem, crate dependencies |
| `pyproject.toml` / `requirements.txt` | Python ecosystem, framework (Django, FastAPI, Flask) |
| `go.mod` | Go ecosystem, module dependencies |
| `composer.json` | PHP ecosystem, framework (Laravel, Symfony) |
| `Gemfile` | Ruby ecosystem, framework (Rails, Sinatra) |
| `tsconfig.json` | TypeScript configuration, strictness, path aliases |
| `next.config.*` | Next.js version, plugins, output mode |
| `tailwind.config.*` | Tailwind CSS version, theme customization |
| `docker-compose.*` | Container services, infrastructure dependencies |
| `wrangler.toml` | Cloudflare Workers deployment |
| `.env.example` / `env_example.txt` | Environment variable shape |

Extract: framework name and version, language, key dependencies, deployment target.

### Step 2: Detect Conventions

Scan for convention files and extract rules:

1. **CLAUDE.md** — Read fully. Extract: file organization, do-not-modify rules, allowed modifications, code style rules, gotchas.
2. **.eslintrc** / `eslint.config.*` — Linting rules, style preferences.
3. **.prettierrc** — Formatting conventions.
4. **CONTRIBUTING.md** — Workflow conventions.
5. **Existing code patterns** — Sample 3-5 files from different directories to detect:
   - Export style (named vs default exports)
   - Naming convention (camelCase, PascalCase, kebab-case for files)
   - Import organization (grouped, alphabetized, alias usage)
   - Comment style and density

### Step 3: Detect Architecture Layers

Scan the directory structure (top 3 levels) and classify:

| Directory Pattern | Layer |
|-------------------|-------|
| `src/app/`, `pages/`, `routes/` | Routing / Pages |
| `src/components/`, `components/` | UI Components |
| `src/lib/`, `lib/`, `utils/` | Business Logic / Utilities |
| `src/types/`, `types/` | Type Definitions |
| `src/api/`, `api/`, `server/` | API / Backend |
| `src/middleware*`, `middleware*` | Middleware |
| `database/`, `migrations/`, `prisma/` | Data Layer |
| `tests/`, `__tests__/`, `*.test.*` | Testing |
| `public/`, `static/`, `assets/` | Static Assets |
| `scripts/`, `bin/` | Tooling / Scripts |
| `.github/`, `.gitlab-ci*` | CI/CD |

### Step 4: Detect Sensitive Areas

Identify files and directories that should not be modified without caution:

- Files explicitly listed as "do not modify" in CLAUDE.md or conventions
- Migration files (append-only)
- Generated files (lock files, build output)
- Authentication and authorization code
- Database connection and client configuration
- Environment variable handling

### Step 5: Detect Testing Patterns

Scan test files to determine:
- Test framework (Jest, Vitest, Mocha, pytest, cargo test)
- Test file location convention (co-located, separate directory)
- Test naming convention (`.test.ts`, `.spec.ts`, `_test.go`)
- Fixture and mock patterns
- Coverage configuration

### Step 6: Generate DNA Profile

Write `.maestro/dna.md`:

```markdown
# Project DNA

**Generated:** [YYYY-MM-DD]
**Project root:** [absolute path]

## Tech Stack

- **Language:** [language] ([version if detectable])
- **Framework:** [framework] [version]
- **Styling:** [CSS framework/approach]
- **Database:** [database]
- **Deployment:** [hosting/platform]
- **Key dependencies:** [list of important deps with purpose]

## Patterns Detected

- **Export style:** [named / default / mixed]
- **Naming:** [files: kebab-case, components: PascalCase, etc.]
- **State management:** [approach]
- **Validation:** [library/approach]
- **Error handling:** [pattern]
- **Import aliases:** [e.g., @/ -> src/]

## Architecture Layers

[Directory tree showing the layer classification from Step 3]

## Conventions

[Extracted rules from CLAUDE.md and other convention sources, organized by category]

## Sensitive Areas

[List of files/directories that must not be modified or require special care, with the reason for each]

## Testing

- **Framework:** [framework]
- **Location:** [pattern]
- **Run command:** [command]
- **Coverage:** [configured / not configured]
```

## Refresh

If `$ARGUMENTS` contains "update" or "refresh", read the existing `.maestro/dna.md` first and only update sections that have changed. Note what changed at the top of the file:

```markdown
**Last updated:** [YYYY-MM-DD]
**Changes:** [brief description of what changed since last scan]
```

## Output

- `.maestro/dna.md` — Project DNA profile
- Used by the Context Engine to select relevant context for implementer, QA reviewer, and other agents
- Updated incrementally when project structure changes
