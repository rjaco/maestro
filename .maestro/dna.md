# Project DNA — Maestro

## Tech Stack
- **Language:** Markdown (skill/agent/command definitions), Bash (hooks, scripts)
- **Framework:** Claude Code Plugin System (`.claude-plugin/plugin.json`)
- **Styling:** N/A (no UI — this is a CLI plugin)
- **Database:** None
- **Deployment:** Claude Code Marketplace (`marketplace.json`)
- **Testing:** None detected (plugin tested via Claude Code runtime)
- **Package Manager:** None (no dependencies — pure markdown + shell)

## Patterns Detected

### Plugin Structure
- Dual-root layout: top-level dirs mirror `plugins/maestro/` (marketplace structure)
- Skills use `SKILL.md` convention inside named directories (e.g., `skills/dev-loop/SKILL.md`)
- Agents use flat `.md` files in `agents/` with YAML frontmatter (name, description, model, memory)
- Commands use flat `.md` files in `commands/` (slash-command definitions)
- Profiles use flat `.md` files in `profiles/` with YAML frontmatter (name, description, expertise, tools)

### Frontmatter Conventions
- All `.md` content files use YAML frontmatter for metadata
- Agent frontmatter: `name`, `description`, `model`, `memory`
- Profile frontmatter: `name`, `description`, `expertise` (list), `tools` (list)
- Template frontmatter: structured YAML with default values

### Naming Conventions
- Directories: kebab-case (`dev-loop`, `context-engine`, `opus-loop`)
- Files: kebab-case `.md` (`qa-reviewer.md`, `stop-hook.sh`)
- Skills: directory name = skill name, main file always `SKILL.md`
- Supporting files colocated with `SKILL.md` (e.g., `deep-interview.md`, `mega-research.md`)

### Agent Model Routing
- Planning/architecture: `opus`
- Implementation/execution: `sonnet`
- Review/QA: `sonnet`
- Simple tasks: `haiku`
- Research: `sonnet`

## Architecture Layers

```
[User Command] -> [Classifier] -> [Layer Router]
                                      |
                    +-----------------+------------------+
                    |                 |                   |
              [Vision Layer]   [Tactics Layer]    [Execution Layer]
              research         decompose           dev-loop
              strategy         architecture        delegation
              opus-loop        forecast            git-craft
                                                   ship
                                                   preview
                                                   watch
```

### Layer Boundaries
- **Commands:** Entry points — `/maestro`, `/maestro opus`, `/maestro init`, `/maestro status`, `/maestro model`
- **Classifier:** Routes requests to correct layer based on complexity
- **Vision & Strategy:** Research, strategy, opus-loop (product-level orchestration)
- **Tactics & Architecture:** Decompose features into stories, architecture decisions, cost forecasting
- **Execution:** Dev-loop (implement, self-heal, QA), git-craft, ship, preview
- **Cross-cutting:** Context Engine (right-sized context), Token Ledger, Living Docs, Build Log, Retrospective

## Conventions
- Skills define autonomous workflows — agents execute them
- Agents receive scoped context from Context Engine (never read full codebase)
- TDD workflow enforced in implementer agent (Red-Green-Refactor)
- Progressive trust: novice -> apprentice -> journeyman -> expert (based on QA pass rate)
- Checkpoint mode by default (pause for user review between stories)
- Templates in `templates/` provide scaffolding for generated files (dna, state, architecture, etc.)

## Sensitive Areas
- `.claude-plugin/plugin.json` — Plugin manifest, must conform to Anthropic spec
- `.claude-plugin/marketplace.json` — Marketplace listing, schema-validated
- `hooks/hooks.json` — Hook configuration, must match Claude Code hook format
- `templates/` — Scaffolding templates used by init and other skills

## Commands
- Build: N/A (no build step)
- Test: N/A (no automated tests)
- Lint: N/A
- Dev: `claude` (run Claude Code with plugin installed)
- Deploy: `claude plugin install maestro` (marketplace)

## Project Scale
- Skills: 65 skill directories, 94 skill files
- Agents: 6 agent definitions
- Commands: 19 slash commands
- Profiles: 11 specialist profiles
- Templates: 8 scaffolding templates
- Hooks: 4 (Stop, Opus Loop, Notification, Branch Guard)
- Scripts: 10 (setup, statusline, notify, service-installer, session-lock, security-drift, index-health, audio-alert, worktree-merge)
- Total files: ~270 markdown, 5 JSON, 14 shell scripts

## Branching Strategy
- `development` branch: all work goes here
- `main` branch: only updated via explicit launch/release
- Branch guard hook enforces this via PreToolUse
