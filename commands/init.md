---
description: "Initialize Maestro for this project — inference-first onboarding that asks, scans, previews, then builds"
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Maestro Init — Inference-First Onboarding (v2.0.0)

You are performing first-time Maestro setup for this project. The flow is: **ask → scan → preview → build → stay available**. Combine the user's own description with codebase scanning to produce the project DNA.

## Step 1: Welcome and Ask

### Check for existing DNA

If `.maestro/dna.md` already exists, warn the user:

Use AskUserQuestion:
- Question: "Project DNA already exists. What would you like to do?"
- Header: "Init"
- Options:
  1. label: "Regenerate", description: "Rescan codebase and overwrite current DNA"
  2. label: "Cancel", description: "Keep existing DNA unchanged"

If they choose Cancel, stop immediately and do nothing.

### Fresh init

If this is a fresh init (no existing DNA), display:

```
+---------------------------------------------+
| Maestro Init                                |
+---------------------------------------------+

[maestro] Tell me about your project in a few sentences.

  What are you building? What stack are you using?
  What matters most to you?

  (i) I'll also scan your codebase to fill in the gaps.
```

Wait for the user's free-text response. Do NOT proceed until you have their answer.

Once the user responds, parse their free-text answer to infer:
- **Intent**: What they are building (app type, domain, purpose)
- **Role**: Their role or perspective (frontend, backend, fullstack, etc.)
- **Priorities**: What matters most (performance, DX, shipping speed, test coverage, etc.)
- **Stack hints**: Any technologies they mention explicitly

Carry these inferences forward — they take priority over auto-detection when there is a conflict, since the user knows their own project best.

## Step 2: Scan Codebase

Now combine the user's description with automated discovery. Run these sub-steps silently (no output to the user until the preview in Step 3).

### 2a: Auto-Detect Tech Stack

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

### 2b: Read Project Conventions

If `CLAUDE.md` exists, read it completely. Extract:
- Explicit rules ("NEVER modify", "ALWAYS use")
- Code style conventions (exports, naming, patterns)
- Architecture layers and boundaries
- Sensitive areas (files/dirs that must not be modified)
- Available commands (build, test, lint, deploy)

If `CLAUDE.md` does not exist, note that conventions will be inferred from code patterns.

### 2c: Scan Directory Structure

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

### 2d: Detect Patterns from Code

Sample 2-3 representative files from the codebase to detect patterns:

- **Export style**: default exports vs named exports
- **Component style**: function declarations vs arrow functions
- **Styling approach**: CSS modules, Tailwind, styled-components, CSS-in-JS
- **State management**: Redux, Zustand, Jotai, React Context, signals
- **Data fetching**: Server Components, SWR, React Query, fetch, axios
- **Form handling**: React Hook Form, Formik, native forms
- **Validation**: Zod, Yup, Joi, class-validator
- **Testing patterns**: unit style, mocking approach, assertion library

### 2e: Detect MCP Servers and CLI Tools

Detect available integrations by checking for MCP tool prefixes and CLI tools in PATH.

**MCP server detection** — check if any tools are available with these prefixes:
- `mcp__asana__` → Asana project management
- `mcp__atlassian__` → Atlassian (Jira/Confluence)
- `mcp__linear__` → Linear issue tracking
- `mcp__notion__` → Notion knowledge base
- `mcp__plugin_playwright_playwright__` → Playwright browser automation

**CLI tool detection** — run:
```bash
command -v gh >/dev/null 2>&1 && echo "gh_cli:found" || echo "gh_cli:missing"
command -v obsidian >/dev/null 2>&1 && echo "obsidian_cli:found" || echo "obsidian_cli:missing"
```

Record each integration as detected or not detected. These will be shown in the preview and written to config.

## Step 3: Preview and Confirm

Before creating any files, show a compact DNA preview that merges the user's free-text input with scan results. Display:

```
+---------------------------------------------+
| Project DNA (inferred)                      |
+---------------------------------------------+
  Stack     [framework] + [language] + [styling]
  DB        [database or "none detected"]
  Deploy    [platform or "not configured"]
  Tests     [test runner] ([N] test files)
  Patterns  [key patterns, comma-separated]

  Integrations detected:
    Asana            [detected (ok)] or [not found (x)]
    Atlassian        [detected (ok)] or [not found (x)]
    Linear           [detected (ok)] or [not found (x)]
    Notion           [detected (ok)] or [not found (x)]
    Playwright       [detected (ok)] or [not found (x)]
    GitHub CLI       [detected (ok)] or [not found (x)]
    Obsidian CLI     [detected (ok)] or [not found (x)]
```

Use AskUserQuestion:
- Question: "Does this look right?"
- Header: "Preview"
- Options:
  1. label: "Build it (Recommended)", description: "Create .maestro/ directory with this configuration"
  2. label: "Request changes", description: "Tell me what to adjust before building"
  3. label: "Cancel", description: "Abort initialization"

If they choose "Build it (Recommended)", proceed to Step 4. If they choose "Request changes", update the inferred data accordingly and re-display the preview. Repeat until confirmed. If they choose "Cancel", stop.

## Step 4: Build

Once the user confirms, create all files and directories.

### 4a: Create Directory Structure

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

### 4b: Generate Project DNA

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

### 4c: Create State File

Create `.maestro/state.md`:

```markdown
# Maestro Project State

## Features Completed
(none yet)

## Current Session
No active session.

## History
- [timestamp] Maestro initialized (v2.0.0)
```

### 4d: Create Config File (with integrations)

Create `.maestro/config.yaml`:

```yaml
# Maestro Configuration (v2.0.0)
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

# Model assignments per task type
models:
  planning: opus         # Decomposition, architecture, roadmaps
  execution: sonnet      # Story implementation, code writing
  review: opus           # QA review, milestone evaluation
  simple: haiku          # Fix agents, config changes, boilerplate
  research: sonnet       # Web research, competitive analysis

# Project-specific commands (auto-detected, override if needed)
commands:
  build: null    # auto-detect from package.json / Makefile
  test: null     # auto-detect
  lint: null     # auto-detect
  typecheck: null  # auto-detect

# Scheduler (cron-based tasks)
scheduler:
  enabled: false

# External integrations (auto-detected)
integrations:
  kanban:
    provider: null      # asana | linear | atlassian | null
    auto_detected: []   # e.g. ["asana", "linear"]
    sync_enabled: false
    project_id: null
  knowledge_base:
    provider: null      # notion | obsidian | null
    auto_detected: []   # e.g. ["notion"]
    vault_path: null
    sync_enabled: false
  tools:
    playwright: false   # true if Playwright MCP detected
    github_cli: false   # true if `gh` found in PATH
    obsidian_cli: false # true if `obsidian` found in PATH
```

Populate the `integrations` section based on Step 2e detection results:
- If Asana MCP tools were found, add `"asana"` to `kanban.auto_detected` and set `kanban.provider: asana`
- If Linear MCP tools were found, add `"linear"` to `kanban.auto_detected` and set `kanban.provider: linear` (if no provider already set)
- If Atlassian MCP tools were found, add `"atlassian"` to `kanban.auto_detected` and set `kanban.provider: atlassian` (if no provider already set)
- If Notion MCP tools were found, add `"notion"` to `knowledge_base.auto_detected` and set `knowledge_base.provider: notion`
- If Playwright MCP tools were found, set `tools.playwright: true`
- If `gh` CLI was found, set `tools.github_cli: true`
- If `obsidian` CLI was found, set `tools.obsidian_cli: true` and add `"obsidian"` to `knowledge_base.auto_detected`

### 4e: Create Trust File

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

## Step 5: Summary and Stay Available

After all files are created, display a box-formatted summary:

```
+---------------------------------------------+
| Maestro Initialized                         |
+---------------------------------------------+

  Project   [name]
  Stack     [framework] + [language] + [styling]
  DB        [database or "none detected"]
  Deploy    [platform or "not configured"]
  Tests     [test runner] ([N] test files)
  Scale     [N] components, [N] pages, [N] API routes

  Integrations:
    [integration name]     (ok) or (x)
    ...

  Created:
    .maestro/dna.md          Project DNA
    .maestro/config.yaml     Configuration (with integrations)
    .maestro/trust.yaml      Trust metrics (novice)
    .maestro/state.md        Project state
    .maestro/stories/        Story files directory
    .maestro/logs/           Session logs directory
    .maestro/research/       Research output directory
    .maestro/archive/        Archive directory

+---------------------------------------------+
```

Then display the stay-available message:

```
[maestro] Ready. Ask me anything about how Maestro works,
          or start building with /maestro "your feature"

  Quick start:
    /maestro "your feature"      Build something
    /maestro help                Learn how Maestro works
    /maestro doctor              Check installation health
    /maestro config              View/edit settings
```

## Important Notes

- Do NOT create `.maestro/state.local.md` during init — that is session-specific and created by `/maestro` when a feature is started.
- Always wait for user input at Step 1 (free-text description) and Step 3 (preview confirmation) before proceeding.
- If the user requests changes in Step 3, update the preview and re-display. Do not proceed until they confirm.
- If the project has no recognizable tech stack files, still create the DNA with what can be inferred from the user's description, directory structure, and file extensions.
- Keep DNA concise — it will be injected into agent context. Every token counts.
- The user's free-text description takes priority over auto-detection when there is a conflict.
- Version is 2.0.0 for state and config file headers.
