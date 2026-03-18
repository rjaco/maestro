# Contributing a Squad

Squads are multi-agent configurations that wire together Maestro agents for a specific workflow. This guide explains how to author, test, and submit a squad for community review.

---

## What Is a Squad?

A squad is a `.md` file with YAML frontmatter that declares a set of agents, their roles, how they share context, and the quality gates that govern their output. Squads live in `squads/` and can be invoked by Maestro's orchestrator.

---

## Step-by-Step: Creating a Squad

### 1. Pick a name

Squad names must be:
- kebab-case (e.g., `code-review-squad`, `full-stack-feature`)
- Descriptive of the workflow, not a team name
- Unique within the `squads/` directory

File name: `squads/<your-squad-name>.md`

### 2. Write the frontmatter

```yaml
---
name: your-squad-name
description: "One clear sentence describing what this squad does and when to use it."
version: 1.0.0
author: your-github-handle
agents:
  - role: planner
    agent: maestro-strategist
    model: opus
    focus: "Break down the request into stories"
  - role: implementer
    agent: maestro-implementer
    model: sonnet
    focus: "Implement each story using TDD"
  - role: reviewer
    agent: maestro-qa-reviewer
    model: sonnet
    focus: "Validate output against acceptance criteria"
orchestration_mode: sequential   # sequential | parallel | dynamic
shared_context:
  - docs/architecture.md
  - CLAUDE.md
quality_gates:
  - all tests pass
  - no lint errors
  - reviewer approved
---
```

All frontmatter fields are described in `.squad-schema.md`. Required fields: `name`, `description`, `version`, `author`, `agents`.

### 3. Write the body

After the frontmatter, add a Markdown body with these sections:

```markdown
## Purpose

What problem this squad solves and when a user should reach for it.

## Agents

Describe each agent's role in the workflow and what it receives/produces.

## Workflow

Step-by-step description of how agents hand off to each other.

## Context Sharing

Which files are shared across agents and why. Justify each entry — don't share files speculatively.

## Quality Gates

What the squad checks before declaring success.
```

### 4. Test your squad locally

Before submitting, run your squad against a real task in a scratch project:

```
/maestro squad run <your-squad-name> --dry-run
```

Verify:
- All agent references resolve
- Context files exist and are within the project root
- The workflow completes without errors
- Output meets your stated quality gates

Run the schema validator:

```
/maestro squad validate <your-squad-name>
```

All validation rules are documented in `VALIDATION.md`. Your squad must pass all of them before submission.

### 5. Submit for community review

1. Fork the Maestro repository
2. Add your squad file to `squads/`
3. Open a pull request with the title: `squad: add <your-squad-name>`
4. Fill in the PR template — include a sample task you ran the squad against and the output it produced
5. A maintainer will run the automated validator and then do a manual security review (see `SECURITY.md`)

Expect one round of feedback. Most rejections are for missing required fields or shared_context paths that escape the project root.

---

## Naming Conventions

| Good | Bad |
|------|-----|
| `code-review-squad` | `mySquad` |
| `full-stack-feature` | `squad1` |
| `bug-triage-and-fix` | `the-best-squad` |
| `api-contract-test` | `rodrigos-workflow` |

Names must not include version numbers — use the `version` field in frontmatter instead.

---

## Required Metadata Fields

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Must match filename (without `.md`) |
| `description` | string | At least 20 characters, substantive |
| `version` | string | Semver (e.g., `1.0.0`) |
| `author` | string | GitHub handle |
| `agents` | list | At least one agent entry |

See `.squad-schema.md` for the complete schema including optional fields.

---

## Versioning Policy

Squads follow [Semantic Versioning](https://semver.org/):

- **Patch** (`1.0.x`): Fix a typo, tighten a focus description, adjust a quality gate phrase
- **Minor** (`1.x.0`): Add an agent, add a shared_context entry, add a quality gate
- **Major** (`x.0.0`): Change orchestration_mode, remove an agent, restructure the workflow

When you update an existing squad, bump the version in the frontmatter and note the change in your PR description. Do not reuse a version number for different content.

---

## Code of Conduct

Squads are shared tools. Do not submit squads that:
- Harvest user data or project secrets
- Execute shell commands outside the project directory
- Are designed to circumvent Maestro's security model

Violations will result in immediate removal and a ban from future contributions. See `SECURITY.md` for what is and is not allowed.
