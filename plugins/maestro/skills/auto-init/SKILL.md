---
name: auto-init
description: "Zero-config auto-initialization. Detects missing .maestro/dna.md and generates a minimal DNA file by scanning the project silently — no interactive flow, no prompts."
---

# Auto-Init

Detects whether the project has been initialized and, if not, auto-discovers the tech stack and writes a minimal `.maestro/dna.md` sufficient for the dev-loop to proceed. This is fast, silent, and non-interactive.

## When to Invoke

Call this skill at the **top of any command flow that requires a DNA file**, before any other step that reads `.maestro/dna.md`.

Currently integrated at:

| Command | Where |
|---------|-------|
| `maestro.md` | Step 4 (Verify Initialization) — replace the "stop here" block with this skill |
| `magnum-opus.md` | Step 4 (Verify Initialization) — replace the "stop here" block with this skill |

## Guard Condition

```
IF .maestro/dna.md EXISTS → skip this skill entirely, return immediately
IF .maestro/dna.md DOES NOT EXIST → proceed with auto-init
```

Never overwrite an existing DNA file. If the user has run `/maestro init`, their full DNA profile must not be clobbered.

---

## Discovery Process

### Step 1: Scan for Project Files

Check for the following files in the project root (do not recurse — root only for manifests):

| File | Signal |
|------|--------|
| `package.json` | Node.js / JavaScript / TypeScript project |
| `tsconfig.json` | TypeScript enabled |
| `pyproject.toml` | Python project (PEP 517+) |
| `requirements.txt` | Python project (legacy) |
| `Cargo.toml` | Rust project |
| `go.mod` | Go project |
| `Gemfile` | Ruby project |
| `composer.json` | PHP project |
| `pom.xml` | Java / Maven project |
| `build.gradle` | Java / Kotlin / Gradle project |
| `mix.exs` | Elixir project |
| `pubspec.yaml` | Dart / Flutter project |
| `.gitignore` | Any version-controlled project |
| `Makefile` | Build system present |
| `Dockerfile` | Containerized project |
| `docker-compose.yml` / `docker-compose.yaml` | Multi-service setup |

For `package.json` specifically, read the file and extract:
- `name` — project name
- `dependencies` and `devDependencies` — detect framework

### Step 2: Detect Framework

From the collected signals, classify the primary framework:

**JavaScript / TypeScript:**

| Dependency / Config File | Framework |
|--------------------------|-----------|
| `next` in deps OR `next.config.*` | Next.js |
| `nuxt` in deps OR `nuxt.config.*` | Nuxt |
| `@remix-run/react` in deps | Remix |
| `astro` in deps OR `astro.config.*` | Astro |
| `@sveltejs/kit` in deps | SvelteKit |
| `svelte` in deps | Svelte |
| `react` in deps (no Next/Remix) | React (Vite or CRA) |
| `vue` in deps (no Nuxt) | Vue |
| `express` in deps | Express |
| `fastify` in deps | Fastify |
| `hono` in deps | Hono |
| `@nestjs/core` in deps | NestJS |
| `electron` in deps | Electron |

**Python:**

| Signal | Framework |
|--------|-----------|
| `django` in pyproject.toml or requirements.txt | Django |
| `fastapi` in pyproject.toml or requirements.txt | FastAPI |
| `flask` in pyproject.toml or requirements.txt | Flask |
| `starlette` only | Starlette |

**Other:**
- `Cargo.toml` → Rust (framework: axum / actix / none — check `[dependencies]`)
- `go.mod` → Go (framework: gin / echo / fiber / none — check imports)
- `Gemfile` → Ruby (Rails if `gem 'rails'` present, Sinatra otherwise)

If no framework is detected but files exist: `framework: unknown`.

### Step 3: Detect Language and Runtime

| Signal | Language |
|--------|----------|
| `tsconfig.json` exists | TypeScript |
| `package.json` + no tsconfig | JavaScript |
| `pyproject.toml` or `requirements.txt` | Python |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `Gemfile` | Ruby |
| `composer.json` | PHP |
| `pom.xml` or `build.gradle` | Java |
| `pubspec.yaml` | Dart |
| `mix.exs` | Elixir |

### Step 4: Detect Test Runner

Check `package.json` scripts and devDependencies:

| Signal | Test runner |
|--------|-------------|
| `vitest` in devDeps | Vitest |
| `jest` in devDeps | Jest |
| `mocha` in devDeps | Mocha |
| `pytest` in pyproject.toml or requirements.txt | pytest |
| `cargo test` (Rust default) | Cargo test |
| `go test` (Go default) | go test |

Extract the test script command from `package.json` `scripts.test` if present.

### Step 5: Detect Package Manager

Check for lockfiles in the project root:

| File | Package manager |
|------|-----------------|
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `bun.lockb` | bun |
| `package-lock.json` | npm |
| `Pipfile.lock` | pipenv |
| `poetry.lock` | poetry |
| `Cargo.lock` | cargo |
| `go.sum` | go modules |

### Step 6: Scan Top-Level Directory Structure

List the top-level directories (depth 1 only). Classify each:

| Pattern | Layer |
|---------|-------|
| `src/`, `lib/` | Source root |
| `app/`, `pages/`, `routes/` | Routing / Pages |
| `components/`, `ui/` | UI Components |
| `api/`, `server/` | Backend / API |
| `tests/`, `test/`, `__tests__/`, `spec/` | Tests |
| `public/`, `static/`, `assets/` | Static Assets |
| `scripts/`, `bin/` | Tooling |
| `docs/` | Documentation |
| `prisma/`, `database/`, `migrations/`, `db/` | Data Layer |
| `.github/`, `.gitlab/` | CI/CD |

### Step 7: Greenfield Detection

If **none** of the project-file signals above were found (empty or near-empty directory), treat the project as greenfield:

- `language: unknown`
- `framework: unknown`
- `status: greenfield`

The DNA file will contain a scaffold with placeholders so the user knows what to fill in.

---

## Output: Minimal DNA File

Write `.maestro/dna.md`. Create `.maestro/` directory first if it does not exist.

### For detected projects:

```markdown
# Project DNA

**Generated:** [YYYY-MM-DD]
**auto_generated:** true
**Project root:** [absolute path of cwd]

> This DNA was auto-generated by Maestro. Run `/maestro init` to produce a
> full DNA profile with conventions, sensitive areas, and code patterns.

## Tech Stack

- **Language:** [detected language]
- **Framework:** [detected framework] ([version from package.json if available])
- **Package manager:** [detected package manager]
- **Key dependencies:** [top 5-8 non-trivial deps from package.json, comma-separated]

## Architecture Layers

[list of top-level directories with their classified layer]

## Testing

- **Framework:** [detected test runner]
- **Run command:** [test script from package.json, or standard command for the language]

## Conventions

- No conventions detected (auto-generated). Run `/maestro init` for full extraction.
```

### For greenfield projects:

```markdown
# Project DNA

**Generated:** [YYYY-MM-DD]
**auto_generated:** true
**Project root:** [absolute path of cwd]
**status:** greenfield

> This DNA was auto-generated for a new project. No project files were detected.
> Run `/maestro init` after setting up your stack to produce a full DNA profile.

## Tech Stack

- **Language:** unknown — update after choosing your stack
- **Framework:** unknown — update after scaffolding

## Architecture Layers

- No directories detected yet.

## Testing

- **Framework:** unknown
- **Run command:** unknown

## Conventions

- No conventions detected (greenfield project).
```

---

## Silent Operation

This skill produces **no user-visible output**. It does not:
- Ask the user any questions
- Display a progress indicator
- Announce that it ran

It simply writes `.maestro/dna.md` and returns. The calling command continues as if init had already been run.

The only exception: if writing the file fails (e.g., permission error), surface the error message.

---

## Integration: Replacing the "Stop Here" Blocks

### In `maestro.md` — Step 4

Replace:

```
Check if `.maestro/dna.md` exists. If not:

Maestro is not initialized for this project.
Run /maestro init first to auto-discover your tech stack and create project DNA.

Stop here.
```

With:

```
Check if `.maestro/dna.md` exists. If not, invoke the auto-init skill to
generate a minimal DNA file from the current project structure. This is
silent and fast. Continue immediately after — do not pause or prompt.
```

### In `magnum-opus.md` — Step 4

Replace:

```
Check if `.maestro/dna.md` exists. If not:

Maestro is not initialized for this project.
Run /maestro init first to auto-discover your tech stack and create project DNA.

Stop here.
```

With:

```
Check if `.maestro/dna.md` exists. If not, invoke the auto-init skill to
generate a minimal DNA file from the current project structure. This is
silent and fast. Continue immediately after — do not pause or prompt.
```

---

## Step: Generate agents.md After State Initialization

After writing `.maestro/state.md`, invoke the agents-md skill to generate an `agents.md` file at the project root. This makes Maestro's agents visible to Cursor, Windsurf, Copilot, and Codex.

---

## Relationship to `/maestro init`

| | `auto-init` (this skill) | `/maestro init` |
|---|---|---|
| Speed | Near-instant | 30–120 seconds |
| Interactive | No | Yes (clarification questions) |
| Conventions extracted | No | Yes (CLAUDE.md, ESLint, Prettier) |
| Code patterns sampled | No | Yes (3–5 sample files) |
| Sensitive areas detected | No | Yes |
| Repo map generated | No | Yes |
| `auto_generated` flag | `true` | not set (or `false`) |
| Overrides existing DNA | Never | Yes (with confirmation) |

The `auto_generated: true` marker in the DNA file signals to the user and to Maestro that the DNA is minimal. The doctor command and any command that reads DNA can optionally surface a low-priority nudge:

```
Tip: DNA was auto-generated. Run /maestro init for full project analysis.
```

This nudge is informational only and must never block execution.
