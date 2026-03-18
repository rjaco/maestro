# Contributing to Maestro

Thanks for your interest in contributing to Maestro.

## Project Structure

```
skills/          74 skill directories, each with SKILL.md
agents/          6 agent definitions (.md with YAML frontmatter)
commands/        21 slash command handlers
profiles/        11 specialist role templates
templates/       8 scaffolding templates
hooks/           4 hook configs + shell scripts
scripts/         11 utility shell scripts
plugins/maestro/ Distribution copy (mirrored from root)
```

## Adding a Skill

1. Create a directory under `skills/` with a kebab-case name
2. Add a `SKILL.md` file with YAML frontmatter:

```yaml
---
name: your-skill-name
description: "One-line description of what this skill does"
---
```

3. Write the skill body following the existing patterns
4. Reference the skill in `FEATURES.md`

## Adding a Command

1. Create a `.md` file in `commands/` with the command name
2. Include YAML frontmatter with `name`, `description`, `argument-hint`, and `allowed-tools`
3. Add the ASCII banner block after the heading (see any existing command for the pattern)
4. Add the command to the router in `commands/maestro.md` (Step 2.5)
5. Add to the README.md commands table

## Adding an Agent

1. Create a `.md` file in `agents/` with `maestro-` prefix
2. Include frontmatter: `name`, `description`, `model` (haiku/sonnet/opus), optionally `memory`

## Conventions

- **File naming**: kebab-case for everything
- **Frontmatter**: Required on all `.md` content files
- **Skills**: Main file is always `SKILL.md` inside a named directory
- **Branch**: All work goes to `development`. `main` is updated via explicit release only
- **Model routing**: Planning/architecture = opus, implementation = sonnet, simple tasks = haiku

## Quality Checks

Before submitting, run `/maestro doctor` to verify no broken references or misconfigurations.

## License

MIT. By contributing, you agree that your contributions will be licensed under MIT.
