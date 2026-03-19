---
name: readme
description: "Auto-generate or update README.md from the current plugin inventory — counts all components, rebuilds the table of contents, updates badges, and pulls the latest CHANGELOG entry"
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# Maestro Readme

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Auto-generate or refresh `README.md` from the live plugin inventory. Counts all components, rebuilds the table of contents by category, updates shields.io badges, and pulls the latest CHANGELOG entry into a "What's New" section.

No arguments needed — just run `/maestro readme`.

## When to Use

- After adding new skills, commands, agents, or squads (badges and tables go stale immediately)
- Before cutting a release (ensures README version numbers match `plugin.json`)
- After updating `CHANGELOG.md` (pulls the new entry into README automatically)
- Any time README feels out of date

---

## Step 1: Inventory the Plugin

Walk the directory tree and count every component. Read the version from `.claude-plugin/plugin.json`.

```
SKILLS    = count of skills/*/SKILL.md files
COMMANDS  = count of commands/*.md files
AGENTS    = count of agents/*.md files
SQUADS    = count of squads/*/squad.md files
PROFILES  = count of profiles/configs/*.yaml files
TEMPLATES = count of templates/*.md files
HOOKS     = count of distinct event types in hooks/hooks.json
VERSION   = .version from .claude-plugin/plugin.json
```

If `.claude-plugin/plugin.json` does not exist or contains no version, use `"unknown"` in the version badge and warn:

```
[maestro] Warning: .claude-plugin/plugin.json not found or has no version field. Using "unknown" in badge.
```

---

## Step 2: Categorize Skills

Read the `description` field from each `SKILL.md` frontmatter. Group each skill into a category using keyword matching against the skill name and description:

| Keywords in name or description | Category |
|--------------------------------|----------|
| `dev`, `code`, `test`, `build`, `ci`, `git`, `ship`, `loop`, `tdd` | Development |
| `agent`, `squad`, `delegation`, `dispatch`, `orchestrat`, `steering` | Orchestration |
| `context`, `memory`, `brain`, `checkpoint`, `token`, `budget` | Context & Memory |
| `notify`, `webhook`, `trigger`, `scheduler`, `watch`, `remote` | Integrations |
| `kanban`, `board`, `spec`, `decompose`, `story`, `planning` | Planning |
| `cost`, `model`, `router`, `profile`, `config`, `health`, `audit` | Observability |
| `content`, `marketing`, `research`, `strategy`, `scenario` | Content & Strategy |
| `doc`, `readme`, `changelog`, `live-docs`, `auto-docs` | Documentation |
| anything else | Utilities |

Sort skills alphabetically within each category.

If a SKILL.md has no `description` in its frontmatter, use the skill directory name as the description and warn:

```
[maestro] Warning: skills/<name>/SKILL.md has no frontmatter description. Using directory name.
```

---

## Step 3: Extract "What's New"

Read `CHANGELOG.md`. Extract the most recent versioned entry — everything between the first `## [x.y.z]` heading and the next one. Strip the heading line; keep the body verbatim.

If `CHANGELOG.md` is missing:
```
[maestro] Warning: CHANGELOG.md not found. Omitting "What's New" section.
```

If `CHANGELOG.md` has no versioned entry:
```
[maestro] Warning: CHANGELOG.md has no versioned entry. Omitting "What's New" section.
```

---

## Step 4: Preserve Existing Sections

Read `README.md` if it exists. Preserve the following sections verbatim — do NOT regenerate them:

- Installation
- Quick Start / Getting Started
- Prerequisites
- Configuration
- Contributing
- License

If any of these sections are absent from the current README, insert a minimal placeholder.

---

## Step 5: Build the Updated README

Produce a complete `README.md` with all sections in this order:

### Header block

```markdown
# Maestro

> <existing tagline — preserve if present, or use plugin.json description>

![Version](https://img.shields.io/badge/version-{VERSION}-blue)
![Skills](https://img.shields.io/badge/skills-{SKILLS}-green)
![Commands](https://img.shields.io/badge/commands-{COMMANDS}-green)
![Agents](https://img.shields.io/badge/agents-{AGENTS}-green)
![Squads](https://img.shields.io/badge/squads-{SQUADS}-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)
```

### Table of Contents

Generate a ToC from all major README sections. Include at minimum:
- What's New
- Skills (with each non-empty category as a sub-entry)
- Commands
- Agents
- Squads
- Profiles
- Installation
- Quick Start
- Contributing

### What's New

```markdown
## What's New in v{VERSION}

{latest CHANGELOG entry body}
```

Omit this section if CHANGELOG extraction failed.

### Skills by Category

For each category that contains at least one skill:

```markdown
### {Category Name}

| Skill | Description |
|-------|-------------|
| `{name}` | {description} |
```

### Commands

```markdown
## Commands

| Command | Description |
|---------|-------------|
| `/maestro {name}` | {frontmatter description, first sentence only} |
```

If a command file has no frontmatter, use the filename (without `.md`) as the command name and omit the description.

### Agents

```markdown
## Agents

| Agent | Model | Description |
|-------|-------|-------------|
| `{name}` | `{model}` | {description} |
```

### Squads

```markdown
## Squads

| Squad | Description |
|-------|-------------|
| `{name}` | {description} |
```

### Profiles

```markdown
## Profiles

| Profile | Description |
|---------|-------------|
| `{name}` | {description} |
```

### Preserved sections

Insert the preserved or placeholder versions of: Installation, Quick Start, Prerequisites, Configuration, Contributing, License.

---

## Step 6: Write README.md

Write the complete generated content to `README.md` at the plugin root. If `README.md` already exists, replace it entirely — the generated file is authoritative for all generated sections.

Do NOT modify any file other than `README.md`.

Print a confirmation summary after writing:

```
+---------------------------------------------+
| README.md Updated                           |
+---------------------------------------------+

  Skills:    <SKILLS> across <N> categories
  Commands:  <COMMANDS>
  Agents:    <AGENTS>
  Squads:    <SQUADS>
  Profiles:  <PROFILES>
  Version:   <VERSION>
  What's New: pulled from CHANGELOG v<VERSION>

  File: README.md
```

---

## Constraints

- Do NOT modify any file other than `README.md`.
- The generated README must be valid Markdown. No raw HTML unless it was already present in preserved sections.
- Preserve the exact shields.io badge URL format — only substitute the value portion after the last `-` in the badge label.
- Run time target: under 30 seconds for a full regeneration.
