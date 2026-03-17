---
description: "Initialize Maestro for this project — auto-discovers tech stack, creates project DNA"
allowed-tools: Read Write Edit Bash Glob Grep
---

# Maestro Init — Project Initialization

You are performing first-time Maestro setup for this project. Auto-discover everything about the codebase and create the project DNA — the foundation that every future Maestro agent will reference.

## Step 1: Auto-Detect Tech Stack

Read as many of these files as exist (skip missing ones silently):

| File | What It Reveals |
|------|----------------|
| `package.json` | Node.js deps, scripts, framework, test runner |
| `tsconfig.json` | TypeScript config, path aliases, strictness |
| `next.config.*` | Next.js version, plugins, experimental features |
| `tailwind.config.*` | CSS framework config |
| `vite.config.*` | Vite-based projects |
| `Cargo.toml` | Rust project, deps, workspace |
| `requirements.txt` | Python deps |
| `pyproject.toml` | Python project config, tools, deps |
| `go.mod` | Go project, module path, deps |
| `Gemfile` | Ruby project, gems |
| `pom.xml` | Java/Maven project |
| `build.gradle` | Java/Gradle project |
| `composer.json` | PHP project |
| `pubspec.yaml` | Dart/Flutter project |
| `Dockerfile` | Container setup, base image, runtime |
| `docker-compose.yml` | Multi-service architecture |
| `.env.example` or `env_example.txt` | Required environment variables |
| `wrangler.toml` | Cloudflare Workers deployment |
| `vercel.json` | Vercel deployment |
| `netlify.toml` | Netlify deployment |

Extract: framework, language, styling, database, deployment platform, test runner, package manager, and any distinctive tooling.

## Step 2: Read Project Conventions

If `CLAUDE.md` exists, read it completely. Extract:
- Explicit rules ("NEVER modify", "ALWAYS use")
- Code style conventions (exports, naming, patterns)
- Architecture layers and boundaries
- Sensitive areas (files/dirs that must not be modified)
- Available commands (build, test, lint, deploy)

If `CLAUDE.md` does not exist, note that conventions will be inferred from code patterns.

## Step 3: Scan Directory Structure

Run these commands to map the project:

```bash
# Top-level structure
ls -la

# Source directory layout (first 3 levels)
find src/ -type d -maxdepth 3 2>/dev/null || find app/ -type d -maxdepth 3 2>/dev/null || find lib/ -type d -maxdepth 3 2>/dev/null || echo "No standard source directory found"

# Count key file types
echo "--- File Counts ---"
echo "Components: $(find . -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' 2>/dev/null | grep -ic 'component\|\.tsx\|\.jsx\|\.vue\|\.svelte' || echo 0)"
echo "Pages/Routes: $(find . -path '*/app/*/page.*' -o -path '*/pages/*' -o -path '*/routes/*' 2>/dev/null | wc -l)"
echo "API Routes: $(find . -path '*/api/*route*' -o -path '*/api/*' -name '*.ts' -o -path '*/api/*' -name '*.py' 2>/dev/null | wc -l)"
echo "Test Files: $(find . -name '*.test.*' -o -name '*.spec.*' -o -name 'test_*' 2>/dev/null | wc -l)"
echo "Config Files: $(find . -maxdepth 2 -name '*.config.*' -o -name '.env*' 2>/dev/null | wc -l)"
```

Record the counts: components, pages, API routes, test files.

## Step 4: Detect Patterns from Code

Sample 2-3 representative files from the codebase to detect patterns:

- **Export style**: default exports vs named exports
- **Component style**: function declarations vs arrow functions
- **Styling approach**: CSS modules, Tailwind, styled-components, CSS-in-JS
- **State management**: Redux, Zustand, Jotai, React Context, signals
- **Data fetching**: Server Components, SWR, React Query, fetch, axios
- **Form handling**: React Hook Form, Formik, native forms
- **Validation**: Zod, Yup, Joi, class-validator
- **Testing patterns**: unit style, mocking approach, assertion library

## Step 5: Generate Project DNA

Create `.maestro/dna.md`:

```markdown
# Project DNA — [Project Name]

## Tech Stack
- Framework: [detected framework + version]
- Language: [language + strict mode?]
- Styling: [CSS approach]
- Database: [if detected]
- Deployment: [platform]
- Test Runner: [test framework]
- Package Manager: [npm/yarn/pnpm/bun]

## Patterns Detected
- [Export style]
- [Component conventions]
- [Data fetching patterns]
- [Validation approach]
- [Other distinctive patterns]

## Architecture Layers
- [Layer]: [path] ([description])
- [Layer]: [path] ([description])
- ...

## Conventions
- [Convention 1 from CLAUDE.md or inferred]
- [Convention 2]
- ...

## Sensitive Areas
- [path] — [reason: NEVER modify / modify with care]
- ...

## Commands
- Build: [command]
- Test: [command]
- Lint: [command]
- Dev: [command]
- Deploy: [command]

## Project Scale
- Components: [N]
- Pages/Routes: [N]
- API Routes: [N]
- Test Files: [N]
```

## Step 6: Create State and Config Files

Create `.maestro/state.md` (persistent project state, not session-specific):

```markdown
# Maestro Project State

## Features Completed
(none yet)

## Current Session
No active session.

## History
- [timestamp] Maestro initialized
```

Create `.maestro/config.yaml`:

```yaml
# Maestro Configuration
# Edit these values to customize Maestro's behavior for this project.

# Default execution mode: yolo | checkpoint | careful
default_mode: checkpoint

# Default model for implementation agents
default_model: sonnet

# Cost tracking
cost_tracking:
  enabled: true
  forecast: true
  ledger: true
  budget_enforcement: true

# Quality gates
quality:
  max_qa_iterations: 5
  max_self_heal: 3
  run_tsc: true
  run_lint: true
  run_tests: true

# Project-specific commands (auto-detected, override if needed)
commands:
  build: null    # auto-detect from package.json / Makefile
  test: null     # auto-detect
  lint: null     # auto-detect
  typecheck: null  # auto-detect
```

Create `.maestro/trust.yaml`:

```yaml
# Maestro Trust Metrics — tracks reliability on this project
# Trust determines default autonomy level (Novice -> Expert)

total_stories: 0
qa_first_pass_rate: 0.00
self_heal_success_rate: 0.00
average_qa_iterations: 0.0
stories_by_mode:
  yolo: 0
  checkpoint: 0
  careful: 0
trust_level: novice
# Levels: novice (<5 stories) | apprentice (5-15, >60% QA pass)
#         journeyman (15-30, >75%) | expert (30+, >85%)
```

## Step 7: Create Directory Structure

Create the `.maestro/` directory tree:

```bash
mkdir -p .maestro/stories .maestro/logs .maestro/research .maestro/archive
```

Ensure `.maestro/state.local.md` is gitignored (it contains session-specific state):

```bash
# Add to .gitignore if not already present
if ! grep -q '.maestro/state.local.md' .gitignore 2>/dev/null; then
  echo '' >> .gitignore
  echo '# Maestro session state (local only)' >> .gitignore
  echo '.maestro/state.local.md' >> .gitignore
  echo '.maestro/*.lock' >> .gitignore
fi
```

## Step 8: Print Discovery Summary

Display a clear, informative summary of what was discovered and created:

```
====================================
  Maestro Initialized
====================================

  Project: [name]
  Stack:   [framework] + [language] + [styling]
  DB:      [database or "none detected"]
  Deploy:  [platform or "not configured"]
  Tests:   [test runner] ([N] test files)
  Scale:   [N] components, [N] pages, [N] API routes

  Patterns:
    - [pattern 1]
    - [pattern 2]
    - [pattern 3]

  Sensitive areas:
    - [path] ([reason])

  Created:
    .maestro/dna.md          Project DNA (tech stack, patterns, conventions)
    .maestro/config.yaml     Configuration (modes, quality gates, commands)
    .maestro/trust.yaml      Trust metrics (starts at novice)
    .maestro/state.md        Project state (persistent)
    .maestro/stories/        Story files directory
    .maestro/logs/           Session logs directory
    .maestro/research/       Research output directory

====================================

  Ready! Try: /maestro "Add user authentication"

====================================
```

## Important Notes

- Do NOT create `.maestro/state.local.md` during init — that is session-specific and created by `/maestro` when a feature is started.
- If `.maestro/dna.md` already exists, warn the user and ask before overwriting: "Project DNA already exists. Regenerate? [Y/n]"
- If the project has no recognizable tech stack files, still create the DNA with what can be inferred from directory structure and file extensions.
- Keep DNA concise — it will be injected into agent context. Every token counts.
