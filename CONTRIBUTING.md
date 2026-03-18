# Contributing to Maestro

Thanks for your interest in making Maestro better. This guide covers everything you need to contribute skills, agents, profiles, squads, and commands.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Development Setup](#development-setup)
- [What You Can Contribute](#what-you-can-contribute)
- [Naming Conventions](#naming-conventions)
- [Documentation Requirements](#documentation-requirements)
- [PR Process](#pr-process)

---

## Code of Conduct

Be direct and constructive. Criticism of code and ideas is welcome; criticism of people is not. If something is broken, say so clearly. If you have a better approach, show it.

---

## Development Setup

Maestro runs entirely in Claude Code — there is no build step, no package manager, and no compiled artifacts.

**Prerequisites:**
- Claude Code (desktop or CLI)
- A project to test against (any codebase works)

**Testing your changes locally:**

1. Clone or fork the repo
2. In Claude Code, set your custom slash command path to point at your local Maestro copy
3. Run `/maestro doctor` — it checks for broken references, missing frontmatter, and misconfigured files
4. Test your skill manually: `/maestro [your-skill-name]`
5. Run `/maestro quick-start` on a test project to verify the full flow still works

There are no automated tests. Quality is verified through `/maestro doctor` and manual integration testing.

---

## What You Can Contribute

### Skills

Skills are the core unit of Maestro. A skill is a markdown file that instructs an agent how to perform a specific task.

1. Create a directory under `skills/` with a kebab-case name
2. Add a `SKILL.md` with YAML frontmatter:

```yaml
---
name: your-skill-name
description: "One-line description of what this skill does"
---
```

3. Write the skill body (see [Documentation Requirements](#documentation-requirements))
4. Add the skill to `FEATURES.md` under the appropriate category
5. If the skill is invocable as a subcommand, add routing in `commands/maestro.md` Step 2.5

**Good skill candidates:** recurring tasks that require multiple steps, domain knowledge that's hard to keep in your head, tasks that benefit from a structured process.

**Poor skill candidates:** one-liners that are faster to type than invoke, tasks that vary so much per-project that a generic skill adds no value.

### Agents

Agents are specialist roles dispatched by the orchestrator.

1. Create a `.md` file in `agents/` with the `maestro-` prefix
2. Include frontmatter:

```yaml
---
name: maestro-your-agent
description: "What this agent specializes in"
model: sonnet  # haiku | sonnet | opus
---
```

3. Write the agent's system prompt — what it knows, what it does, what it avoids

### Profiles

Profiles are generic role templates that the Skill Factory uses to generate project-specific skills.

1. Create a `.md` file in `profiles/`
2. Use placeholder sections that the Skill Factory will fill in with project-specific details
3. Reference `profiles/frontend-engineer.md` as a structural example

### Squads

Squads are named groups of agents assembled for a specific type of work.

1. Create a `.md` file in `squads/`
2. Specify the agents in the squad and the workflow between them
3. Reference `squads/` for existing examples

### Commands

Commands are the user-facing entry points (`/maestro something`).

1. Create a `.md` file in `commands/` named after the subcommand
2. Include frontmatter: `name`, `description`, `argument-hint`, `allowed-tools`
3. Add the ASCII banner block (copy the pattern from any existing command)
4. Add routing in `commands/maestro.md` Step 2.5
5. Add the command to the README.md commands table

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Skill directories | kebab-case | `seo-analyzer` |
| Agent files | `maestro-` prefix, kebab-case | `maestro-seo-specialist.md` |
| Profile files | kebab-case role name | `seo-specialist.md` |
| Squad files | kebab-case | `content-team.md` |
| Command files | kebab-case subcommand | `audit.md` |
| Frontmatter `name` | matches file/directory name | `name: seo-analyzer` |

---

## Documentation Requirements

Every contribution needs sufficient documentation for an agent to follow it correctly without human intervention.

**Minimum for a skill:**
- YAML frontmatter with `name` and `description`
- What the skill does (one paragraph)
- Input: what it reads or requires
- Steps: numbered process, specific enough that the agent doesn't have to guess
- Output: what it produces (files, messages, side effects)
- Error handling: what to do when things go wrong

**Minimum for an agent:**
- Frontmatter with `name`, `description`, `model`
- Clear scope: what the agent handles and what it defers
- Constraints: what the agent must never do

**You do not need:**
- Exhaustive API references
- Diagrams (unless the structure is genuinely hard to convey in prose)
- Changelog entries (the PR history is the changelog)

---

## PR Process

**Branch:** All contributions go to `development`. `main` is updated via release only.

**Before opening a PR:**

1. Run `/maestro doctor` — fix any reported issues
2. Test your contribution manually on a real project
3. Check that `FEATURES.md` is updated if you added a skill or command
4. Verify frontmatter on all new `.md` files

**What reviewers look for:**

- Does the skill/agent do one thing well? Scope creep is the most common issue.
- Are the steps specific enough that an agent can follow them without guessing?
- Is the output contract clear? What does success look like?
- Does it follow naming conventions?
- Would this be useful outside the author's specific project?

**PR size:** Keep PRs focused. One skill or one feature per PR is ideal. If you're refactoring multiple files, explain why they belong together.

---

## Skill Packs

If you're contributing a collection of related skills, consider packaging them as a skill pack. See `skills/skill-pack/SKILL.md` for the pack format and `CONTRIBUTING.md` (this file) for how to submit.

To submit a community pack:
1. Export your pack: `/maestro skill-pack export <name>`
2. Host it in a public GitHub repository
3. Open an issue with the "Feature Request" template linking to your repo

---

## License

MIT. By contributing, you agree that your contributions will be licensed under MIT.
