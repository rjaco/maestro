# Squads

A squad is a packaged team of specialist agents that work together on a category of tasks. Think of it as Docker Compose for agents: a single declarative file defines the team, their roles, how they coordinate, and what they share.

## What a Squad Is

A squad bundles:

- **Agents** — which agents participate and in what role
- **Orchestration mode** — how those agents coordinate (sequential, parallel, or DAG)
- **Shared context** — which files every agent in the team receives
- **Quality gates** — what must be true before the squad's output is accepted

Squads are composable and shareable. A squad defined here can be referenced by any Maestro orchestrator command.

## Format

Squads use the same YAML frontmatter + markdown body pattern as agents and profiles.

### Frontmatter

```yaml
---
name: "full-stack-dev"
description: "Full-stack development team for web applications"
version: "1.0.0"
author: "Maestro"
agents:
  - role: architect
    agent: "maestro:maestro-implementer"
    model: opus
    focus: "System design, API contracts, data models"
  - role: frontend
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "React/Next.js components, styling, UX"
  - role: backend
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "API routes, business logic, database"
  - role: qa
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "Code review, security, edge cases"
orchestration_mode: dag
shared_context:
  - ".maestro/dna.md"
  - "CLAUDE.md"
quality_gates:
  - "All tests pass"
  - "QA reviewer approves"
  - "No TypeScript errors"
---
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Slug identifier, lowercase with hyphens |
| `description` | string | yes | One-line description of what this squad handles |
| `version` | string | yes | Semantic version (`major.minor.patch`) |
| `author` | string | yes | Author or team name |
| `agents` | list | yes | Ordered list of agent role definitions |
| `agents[].role` | string | yes | Role name within the squad (e.g. `architect`, `qa`) |
| `agents[].agent` | string | yes | Agent reference: `maestro:<name>` or a local file path |
| `agents[].model` | string | yes | Model tier: `opus`, `sonnet`, or `haiku` |
| `agents[].focus` | string | yes | One-line description of this role's scope |
| `orchestration_mode` | enum | yes | `sequential`, `parallel`, or `dag` |
| `shared_context` | list | yes | Files injected into every agent's prompt |
| `quality_gates` | list | yes | Binary pass/fail conditions for accepting squad output |

### Orchestration Modes

**`sequential`** — Agents run one after another. Each receives the previous agent's output as context. Use when work must build in order.

```
architect → backend → frontend → qa
```

**`parallel`** — Agents run simultaneously on independent concerns. Use when roles don't depend on each other's output.

```
backend ─┐
         ├→ qa
frontend ─┘
```

**`dag`** — Agents run in a dependency graph. Some agents parallelize while others must wait for specific predecessors. Use for complex pipelines.

```
architect ─┐
           ├→ backend ─┐
           └→ frontend ─┤→ qa
```

### Agent References

An agent entry can reference a Maestro built-in or a local file:

```yaml
# Maestro built-in agent
agent: "maestro:maestro-implementer"

# Local agent file (relative to repo root)
agent: "agents/my-custom-agent.md"
```

### Markdown Body

The markdown body documents the squad for humans and orchestrators. Use the template at `templates/squad.md`. Required sections:

- **Purpose** — When to use this squad and what it handles
- **Agents** — Role-by-role breakdown: inputs, outputs, scope
- **Workflow** — Handoff protocol and coordination diagram
- **Context Sharing** — What each role sees (avoid injecting unnecessary context)
- **Quality Gates** — Detailed explanation of each gate

## Example: Content Production Squad

```yaml
---
name: "content-production"
description: "Research-to-publish content team for blog posts and landing pages"
version: "1.0.0"
author: "Maestro"
agents:
  - role: researcher
    agent: "maestro:maestro-researcher"
    model: opus
    focus: "Topic research, competitive analysis, keyword discovery"
  - role: strategist
    agent: "maestro:maestro-strategist"
    model: opus
    focus: "Content angle, positioning, audience fit"
  - role: writer
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Draft writing, SEO optimization, CTA placement"
  - role: editor
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "Factual accuracy, brand voice, readability"
orchestration_mode: sequential
shared_context:
  - ".maestro/vision.md"
  - ".maestro/strategy.md"
quality_gates:
  - "Editor reports APPROVED"
  - "Target keyword appears in title, H1, and first paragraph"
  - "Word count is between 1200 and 2500"
---
```

## Example: Security Audit Squad

```yaml
---
name: "security-audit"
description: "Parallel security review across frontend, backend, and infrastructure"
version: "1.0.0"
author: "Maestro"
agents:
  - role: frontend-auditor
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "XSS, CSRF, insecure storage, exposed secrets in client code"
  - role: backend-auditor
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "SQL injection, auth bypass, rate limiting, input validation"
  - role: dependency-auditor
    agent: "maestro:maestro-researcher"
    model: sonnet
    focus: "Known CVEs in package.json and lock files"
  - role: report-writer
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Consolidate findings into a prioritized remediation report"
orchestration_mode: dag
shared_context:
  - "CLAUDE.md"
  - ".maestro/dna.md"
quality_gates:
  - "All critical and high findings have a suggested fix"
  - "Report includes CVSS scores for each finding"
  - "No false positives — every finding cites file and line number"
---
```

## Creating a Squad

1. Copy `templates/squad.md` into this directory as `squads/<name>.md`
2. Fill in the YAML frontmatter
3. Write the markdown body sections
4. Reference your squad in a Maestro command or workflow

## Naming Conventions

- Squad file names use lowercase kebab-case: `full-stack-dev.md`, `content-production.md`
- Role names within a squad are lowercase: `architect`, `qa`, `frontend`
- Agent references use the `maestro:` prefix for built-ins: `maestro:maestro-implementer`

## Relationship to Agents and Profiles

| Concept | What it defines | Scope |
|---------|----------------|-------|
| Agent | A single specialist's behavior and instructions | Individual |
| Profile | A skill set (expertise + tools) attachable to any agent | Individual |
| Squad | A coordinated team of agents with defined handoffs | Team |

Squads compose agents. A squad does not replace agents — it orchestrates them.
