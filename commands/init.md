---
description: "Initialize Maestro for this project — inference-first onboarding that asks, scans, previews, then builds"
allowed-tools: Read Write Edit Bash Glob Grep AskUserQuestion
---

# Maestro Init — Inference-First Onboarding (v1.2.0)

You are performing first-time Maestro setup for this project. The flow is: **validate → ask → scan → preview → build → guide**. Combine the user's own description with codebase scanning to produce the project DNA.

## Step 0: Quick Validation

Before showing any welcome screen, silently run these pre-flight checks. If a check fails, surface a clear, actionable error — do not proceed until resolved.

### 0a: Verify Claude CLI

```bash
command -v claude >/dev/null 2>&1 && echo "claude:found" || echo "claude:missing"
```

If missing, display:

```
[maestro] Error: claude CLI not found in PATH.
  Install it from https://docs.anthropic.com/claude-code
  Then run /maestro init again.
```

Stop immediately.

### 0b: Verify Git Configuration

```bash
git rev-parse --is-inside-work-tree 2>/dev/null && echo "git:repo" || echo "git:not-a-repo"
git config user.name 2>/dev/null && echo "git:user-name-set" || echo "git:user-name-missing"
git config user.email 2>/dev/null && echo "git:user-email-set" || echo "git:user-email-missing"
```

If not inside a git repo, warn the user — Maestro works best inside a git repository. Offer to continue anyway:

Use AskUserQuestion:
- Question: "This directory is not a git repository. Maestro uses git for checkpoints, rollback, and PR integration. Continue anyway?"
- Header: "Validation"
- Options:
  1. label: "Continue without git", description: "Some features (rollback, PR creation) will not be available"
  2. label: "Cancel", description: "Initialize git first, then run /maestro init"

If user name or email are not set, display a warning (non-blocking):

```
[maestro] Warning: git user.name or user.email not configured.
  Set them with:
    git config --global user.name "Your Name"
    git config --global user.email "you@example.com"
```

### 0c: Check for CLAUDE.md

```bash
test -f CLAUDE.md && echo "claude_md:found" || echo "claude_md:missing"
```

If missing, note this silently. After init completes you will offer to create one (see Step 5).

### 0d: Check for Existing .maestro/ Directory

```bash
test -d .maestro && echo "maestro_dir:exists" || echo "maestro_dir:missing"
```

If `.maestro/dna.md` already exists, skip to the DNA-exists branch in Step 1. Otherwise proceed normally.

### 0e: Check for Development Branch

```bash
git branch --list "dev" "develop" "development" 2>/dev/null
git branch --list "main" "master" 2>/dev/null
```

Note the current default branch (main or master). If neither a `dev` nor `develop` branch exists, Maestro will offer to create one after init completes (see Step 5).

---

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

---

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

### 2f: Zero-Config Detection (Extended)

Run these additional scans to complete the auto-detection picture. All output is silent — results feed the preview in Step 3.

#### Git Remote and Hosting

```bash
# Detect remote URL and infer hosting provider
git remote get-url origin 2>/dev/null || echo "git_remote:none"
```

Parse the remote URL to determine:
- `github.com/...` → GitHub
- `gitlab.com/...` → GitLab
- `bitbucket.org/...` → Bitbucket
- `dev.azure.com/...` or `visualstudio.com/...` → Azure DevOps
- Other / SSH → record raw domain

Extract the `user/repo` slug from the URL (e.g., `github.com/acme/my-app`). Store as `git_remote` for the preview.

#### CI/CD Detection

Check for CI/CD configuration files:

```bash
test -d .github/workflows && ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null | head -5
test -f .gitlab-ci.yml && echo "ci:gitlab"
test -f .circleci/config.yml && echo "ci:circleci"
test -f Jenkinsfile && echo "ci:jenkins"
test -f .travis.yml && echo "ci:travisci"
test -f azure-pipelines.yml && echo "ci:azure-devops"
test -f bitbucket-pipelines.yml && echo "ci:bitbucket"
test -f Makefile && grep -q "\.PHONY" Makefile && echo "ci:makefile"
```

Map findings to a friendly label:
- `.github/workflows/` → "GitHub Actions"
- `.gitlab-ci.yml` → "GitLab CI"
- `.circleci/config.yml` → "CircleCI"
- `Jenkinsfile` → "Jenkins"
- `.travis.yml` → "Travis CI"
- `azure-pipelines.yml` → "Azure Pipelines"
- `bitbucket-pipelines.yml` → "Bitbucket Pipelines"
- None found → "none detected"

#### Test Framework Detection

If not already determined from `package.json`, scan for test framework signals:

```bash
# Check config files
test -f jest.config.* && echo "test_framework:jest"
test -f vitest.config.* && echo "test_framework:vitest"
test -f playwright.config.* && echo "test_framework:playwright"
test -f cypress.config.* && echo "test_framework:cypress"
test -f pytest.ini -o -f pyproject.toml && grep -q "pytest" pyproject.toml 2>/dev/null && echo "test_framework:pytest"
test -f go.mod && echo "test_framework:go-test"
test -f Cargo.toml && echo "test_framework:cargo-test"
```

If `package.json` was already read, prefer its `devDependencies` / `scripts.test` field over file-based detection.

#### Terminal Type Detection

```bash
echo "TERM=${TERM}"
echo "COLORTERM=${COLORTERM}"
echo "TERM_PROGRAM=${TERM_PROGRAM}"
```

Classify the terminal for output adaptation:
- `TERM_PROGRAM=iTerm.app` or `COLORTERM=truecolor` → rich color support
- `TERM=xterm-256color` → 256-color support
- `TERM=dumb` or unset → plain text, no ANSI codes
- `TERM_PROGRAM=vscode` → VS Code integrated terminal (supports color)

Store as `terminal_type` in the detected settings. Use this to decide whether to render box-drawing characters and ANSI in subsequent output.

---

## Step 3: Preview and Confirm

Before creating any files, show a compact DNA preview that merges the user's free-text input with all scan results.

### Interactive Preview

Display the following formatted preview screen. Replace every placeholder with a real detected value; use "not detected" if a value could not be determined.

```
+-----------------------------------------------+
| Maestro Init — Project Detection              |
+-----------------------------------------------+

  Project   [project name — from package.json / git remote / directory name]
  Stack     [framework] + [language] + [styling]
  Tests     [test framework]
  CI        [CI/CD system or "none detected"]
  Git       [git remote slug, e.g. github.com/user/my-app, or "local only"]
  MCP       [comma-separated list of detected MCP servers, or "none"]

  Integrations detected:
    Asana            [detected (ok)] or [not found (x)]
    Atlassian        [detected (ok)] or [not found (x)]
    Linear           [detected (ok)] or [not found (x)]
    Notion           [detected (ok)] or [not found (x)]
    Playwright       [detected (ok)] or [not found (x)]
    GitHub CLI       [detected (ok)] or [not found (x)]
    Obsidian CLI     [detected (ok)] or [not found (x)]

  DB        [database or "none detected"]
  Deploy    [deployment platform or "not configured"]
  Terminal  [terminal type: rich / 256-color / plain]

  (i) Values in [brackets] were auto-detected — you can correct them.

+-----------------------------------------------+
  Ready to initialize? [Y/n]
+-----------------------------------------------+
```

Use AskUserQuestion:
- Question: "Does this look right?"
- Header: "Preview"
- Options:
  1. label: "Build it (Recommended)", description: "Create .maestro/ directory with this configuration"
  2. label: "Request changes", description: "Tell me what to adjust before building"
  3. label: "Cancel", description: "Abort initialization"

If they choose "Build it (Recommended)", proceed to Step 4. If they choose "Request changes", update the inferred data accordingly and re-display the preview. Repeat until confirmed. If they choose "Cancel", stop.

---

## Step 4: Build

Once the user confirms, create all files and directories.

### 4a: Create Directory Structure

```bash
mkdir -p .maestro/stories .maestro/logs .maestro/research .maestro/archive .maestro/steering .maestro/security
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

Delegate to the `project-dna` skill to produce `.maestro/dna.md` from the scan results collected in Step 2. The DNA includes:
- Tech stack (framework, language, styling, database, deployment, test runner, package manager)
- Patterns detected (export style, component conventions, data fetching, validation)
- Architecture layers (directory tree with layer classifications)
- Conventions (extracted from CLAUDE.md or inferred from code)
- Sensitive areas (files/dirs requiring extra care)
- Commands (build, test, lint, dev, deploy)
- Project scale (component count, page count, API route count, test file count)

The DNA template:

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

### 4c: Generate Steering Files

Delegate to the `steering` skill to create the four persistent steering files in `.maestro/steering/`:

- **product.md** — Seed the vision section from the user's free-text description (Step 1). Leave personas, success metrics, and non-goals as `[TODO: fill in]` placeholders.
- **structure.md** — Auto-populate directory layout from the DNA scan. Leave module boundaries and data flow as `[TODO: fill in]`.
- **tech.md** — Auto-populate the stack table and key dependencies from `package.json` and detected files. Leave rationale, performance constraints, security requirements, and API conventions as `[TODO: fill in]`.
- **standards.md** — Auto-populate linting rules from `.eslintrc` or `eslint.config.*` if present. Leave coverage target, review process, and deployment constraints as `[TODO: fill in]`.

After creating the files, note which sections need user input (displayed in Step 5).

### 4d: Create State File

Create `.maestro/state.md`:

```markdown
# Maestro Project State

## Features Completed
(none yet)

## Current Session
No active session.

## History
- [timestamp] Maestro initialized (v1.2.0)
```

### 4e: Create Config File (with integrations)

Create `.maestro/config.yaml`:

```yaml
# Maestro Configuration (v1.2.0)
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

# Notifications (push to Slack/Discord/Telegram)
notifications:
  enabled: false
  providers:
    slack:
      webhook_url: null
    discord:
      webhook_url: null
    telegram:
      bot_token: null
      chat_id: null
  triggers:
    on_story_complete: true
    on_feature_complete: true
    on_qa_rejection: true
    on_self_heal_failure: true
    on_test_regression: true

# Awareness (heartbeat monitoring)
awareness:
  enabled: false
  interval_minutes: 30

# Webhooks (inbound event processing)
webhooks:
  enabled: false
  poll_interval_minutes: 5

# Audio feedback (Peon Ping-style alerts)
audio:
  enabled: true
  provider: auto       # auto | terminal | macos | linux | none
  events:
    on_checkpoint: true
    on_complete: true
    on_error: true
    on_qa_rejection: false

# Explain mode — narrates each phase for new users
# Auto-enabled when trust_level is novice (first 5 stories)
explain_mode: auto     # auto | true | false

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

### 4f: Create Trust File

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

### 4g: Generate Security Baseline

Delegate to the `security-drift` skill to create `.maestro/security/baseline.json`:

```bash
mkdir -p .maestro/security
for pattern in "CLAUDE.md" ".claude/CLAUDE.md" "skills/*/SKILL.md" \
               "agents/*.md" "hooks/*.sh" \
               ".claude-plugin/plugin.json" ".maestro/dna.md"; do
  for file in $(ls $pattern 2>/dev/null); do
    sha256sum "$file"
  done
done
```

Write the baseline JSON with the current timestamp. This establishes a clean starting point for drift detection. If a file does not exist yet, skip it — it will be added when first created.

---

## Step 5: Summary, Post-Init Setup, and Guided First Build

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
  CI        [CI/CD system or "none detected"]
  Git       [remote slug or "local only"]
  Scale     [N] components, [N] pages, [N] API routes

  Integrations:
    [integration name]     (ok) or (x)
    ...

  Created:
    .maestro/dna.md          Project DNA
    .maestro/steering/       Steering files (product, structure, tech, standards)
    .maestro/config.yaml     Configuration (with integrations)
    .maestro/trust.yaml      Trust metrics (novice)
    .maestro/state.md        Project state
    .maestro/security/       Security baseline
    .maestro/stories/        Story files directory
    .maestro/logs/           Session logs directory
    .maestro/research/       Research output directory
    .maestro/archive/        Archive directory

+---------------------------------------------+
```

### Post-Init: CLAUDE.md

If `CLAUDE.md` was not found in Step 0c, offer to create one:

Use AskUserQuestion:
- Question: "No CLAUDE.md found. Would you like me to create one with project conventions inferred from the scan?"
- Header: "Post-Init"
- Options:
  1. label: "Yes, create CLAUDE.md", description: "Start from inferred conventions — edit afterward"
  2. label: "Skip", description: "I'll create it manually"

If they choose yes, create a minimal `CLAUDE.md` pre-filled with the conventions and patterns detected during the scan, with clear `[TODO]` markers for anything that could not be inferred.

### Post-Init: Development Branch

If no `dev` or `develop` branch was found in Step 0e, offer to create one:

Use AskUserQuestion:
- Question: "No development branch found. Create a 'dev' branch for Maestro feature work?"
- Header: "Post-Init"
- Options:
  1. label: "Yes, create 'dev' branch", description: "Maestro will use this for feature branches by default"
  2. label: "Skip", description: "I'll manage branches manually"

If they choose yes:

```bash
git checkout -b dev
git checkout -
```

### Steering Files: What Needs Your Input

Display the steering file summary from the `steering` skill:

```
Steering files created. A few things need your input:

  .maestro/steering/product.md    Vision, personas, success metrics, non-goals
  .maestro/steering/tech.md       Performance constraints, security requirements
  .maestro/steering/standards.md  Coverage target, review process, deployment rules

Edit these files directly at any time. Maestro will never overwrite your edits.
```

### Guided First Build

Display this message to orient the user toward their first feature:

```
+---------------------------------------------+
| Ready! What would you like to build?        |
+---------------------------------------------+

  Your first build will run in --careful mode.
  Maestro pauses at each phase so you can follow along
  and build trust before increasing autonomy.

  Suggested first command:
    /maestro "Add a simple feature"

  As trust grows, Maestro automatically advances:
    novice      → careful mode (step-by-step, explain each phase)
    apprentice  → checkpoint mode (pause at story boundaries)
    journeyman  → checkpoint mode (faster, less explanation)
    expert      → yolo mode (fully autonomous, you review commits)

  Trust is earned through successful builds. You're at:
    novice (0/5 stories completed)

+---------------------------------------------+
```

### Stay Available

```
[maestro] Ready. Ask me anything about how Maestro works,
          or start building with /maestro "your feature"

  Quick start:
    /maestro "your feature"      Build something
    /maestro help                Learn how Maestro works
    /maestro doctor              Check installation health
    /maestro config              View/edit settings
```

---

## Skill Integration Points

The following skills are invoked or seeded during init. Each can also be run independently after init:

| Step | Skill | What It Contributes |
|------|-------|---------------------|
| 2e | `skills/mcp-detect/SKILL.md` | MCP server and CLI tool detection |
| 4b | `skills/project-dna/SKILL.md` | Full DNA profile including repo map generation |
| 4c | `skills/steering/SKILL.md` | Four persistent steering files (product, structure, tech, standards) |
| 4g | `skills/security-drift/SKILL.md` | SHA-256 baseline for drift detection |
| Runtime | `skills/explain-mode/SKILL.md` | Phase-by-phase narration during first builds (novice trust level) |

When `trust_level` is `novice`, the `explain-mode` skill is automatically active for all subsequent `/maestro` runs. It narrates each phase (VALIDATE, DELEGATE, IMPLEMENT, SELF-HEAL, QA REVIEW, GIT CRAFT, CHECKPOINT) so the user understands what Maestro is doing and why. Explain mode quiets down automatically once the user reaches `apprentice` level, unless explicitly re-enabled in config.

---

## Important Notes

- Do NOT create `.maestro/state.local.md` during init — that is session-specific and created by `/maestro` when a feature is started.
- Always wait for user input at Step 1 (free-text description) and Step 3 (preview confirmation) before proceeding.
- If the user requests changes in Step 3, update the preview and re-display. Do not proceed until they confirm.
- If the project has no recognizable tech stack files, still create the DNA with what can be inferred from the user's description, directory structure, and file extensions.
- Keep DNA concise — it will be injected into agent context. Every token counts.
- The user's free-text description takes priority over auto-detection when there is a conflict.
- The first build always uses `--careful` mode regardless of config, because trust starts at `novice`. After 5 successful stories, Maestro switches to `checkpoint` mode automatically.
- If terminal detection shows `dumb` or plain text mode, suppress all box-drawing characters and ANSI codes in output — use plain ASCII separators instead.
- Version is 1.2.0 for state and config file headers.
