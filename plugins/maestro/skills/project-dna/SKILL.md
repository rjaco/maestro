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

---

## Repo Map

A condensed, AST-level map of the codebase — every exported function, class, type, and interface, grouped by directory and file. Gives agents precise knowledge of what exists and where, without reading full files.

### Purpose

- Answers "which files contain auth functions?" before touching anything
- Prevents redundant exploration reads during implementation
- Enables the Context Engine to select the right files for each story
- Reduces token waste by replacing speculative full-file reads with targeted lookups

### Format

Stored in `.maestro/repo-map.md`. Each directory is a heading; each file lists its named exports inline:

```markdown
# Repo Map

**Generated:** [YYYY-MM-DD HH:MM]
**Commit:** [short SHA]

## src/auth/
- `middleware.ts`: AuthMiddleware (class), validateToken (fn), refreshSession (fn)
- `types.ts`: User (type), Session (type), AuthConfig (interface)
- `routes.ts`: loginHandler (fn), logoutHandler (fn), callbackHandler (fn)

## src/api/
- `users.ts`: getUser (fn), createUser (fn), updateUser (fn), deleteUser (fn)
- `router.ts`: createRouter (fn), attachMiddleware (fn)

## src/lib/
- `pricing.ts`: calculatePrice (fn), formatCurrency (fn), PricingEngine (class)
- `utils.ts`: slugify (fn), truncate (fn), deepMerge (fn)
```

Annotations: `(fn)` for functions, `(class)` for classes, `(type)` for type aliases, `(interface)` for interfaces, `(enum)` for enumerations, `(const)` for exported constants.

### Generation Strategy

Run grep-based pattern matching per language. Operate from the project root. Skip `node_modules/`, `dist/`, `build/`, `.git/`, and any directory listed as generated in the DNA profile.

#### TypeScript / JavaScript

```bash
grep -rn "^export \(async \)\?\(function\|class\|type\|interface\|enum\|const\|let\) \w\+" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  src/
```

Extract the symbol name and kind from each match. Group lines by file path.

#### Python

```bash
grep -rn "^\(def\|class\|async def\) \w\+" \
  --include="*.py" \
  src/ app/
```

Top-level definitions only (no leading whitespace). Methods inside classes are omitted to keep the map concise.

#### Go

```bash
grep -rn "^func \w\+\|^type \w\+ \(struct\|interface\)" \
  --include="*.go" \
  .
```

#### Rust

```bash
grep -rn "^\(pub \)\?\(fn\|struct\|enum\|trait\|impl\) \w\+" \
  --include="*.rs" \
  src/
```

#### Fallback (unsupported languages)

If the primary language is not in the list above, fall back to file-level listing only — one line per file with no symbol annotations:

```markdown
## src/legacy/
- `processor.php` (file — symbol extraction not supported for PHP)
- `helpers.php` (file — symbol extraction not supported for PHP)
```

#### Post-processing

1. Parse each grep output line: `path/to/file.ts:42:export function doThing`
2. Extract: directory, filename, symbol name, kind
3. Group by directory, then by file within each directory
4. Sort directories alphabetically; sort symbols within a file by line number
5. Write the grouped result to `.maestro/repo-map.md`

### Refresh Triggers

The repo map is regenerated or updated on the following events:

| Trigger | Action |
|---------|--------|
| `maestro init` | Full generation from scratch |
| `maestro plan` (before decomposition) | Full generation if map is absent; staleness check otherwise |
| Story start (implementer agent launch) | Incremental update if map is >1 hour old |
| User request via orchestrator | Full regeneration on demand |

### Staleness Detection

At each trigger point, run a staleness check before deciding whether to do a full regeneration or an incremental update:

```bash
# Read the commit SHA stored in the repo map header
LAST_COMMIT=$(grep "^\*\*Commit:\*\*" .maestro/repo-map.md | awk '{print $2}')

# List files changed since that commit
CHANGED=$(git diff --name-only "$LAST_COMMIT" HEAD)

# Count how many mapped files appear in the changed set
MAPPED_COUNT=$(grep -c "^\- \`" .maestro/repo-map.md)
CHANGED_MAPPED=$(echo "$CHANGED" | grep -F -f <(grep "^\- \`" .maestro/repo-map.md \
  | sed "s/^- \`//;s/\`.*//") | wc -l)

PERCENT=$(( CHANGED_MAPPED * 100 / MAPPED_COUNT ))
```

- **If `$PERCENT >= 20`** — full regeneration: rerun all grep patterns, overwrite `.maestro/repo-map.md`.
- **If `$PERCENT < 20`** — incremental update: rerun grep only for the changed files, merge the updated entries back into the existing map, update the `**Commit:**` and `**Generated:**` headers.
- **If `LAST_COMMIT` is not found** (map missing or corrupted) — full regeneration.

### Context Engine Integration

The repo map is a **T2 context component** (high-value supporting context, included when directly relevant).

| Consumer | How it uses the map |
|----------|---------------------|
| Architect agent | Identifies which modules will be affected by a story; informs decomposition |
| Implementer agent | Locates the exact files to read or modify; avoids exploratory reads |
| QA reviewer agent | Verifies that the right functions were touched and none were inadvertently removed |
| Context Engine | Answers "which files contain X?" queries during context package assembly |

**Inclusion rules:**

- Always included in architect context packages.
- Included in implementer context packages when the story touches more than one directory.
- Excluded from context packages for single-file stories (the file itself is sufficient).
- The full map is included unless it exceeds 8 000 tokens; in that case, only the directories named in the story are included.
