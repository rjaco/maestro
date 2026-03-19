---
name: readme-gen
description: "Auto-generate or update README.md from the current plugin inventory. Counts all components, rebuilds the table of contents by category, updates shields.io badges, and pulls the latest CHANGELOG entry into a What's New section."
effort: low
maxTurns: 8
---

# readme-gen

Auto-generate or refresh the plugin's README.md from the live plugin inventory. Run at any time via `/maestro readme` to produce a README that accurately reflects the current state of the plugin — component counts, feature list, badges, and release notes.

## When to Use

- **After adding new skills, commands, agents, or squads** — badges and tables go stale immediately without this
- **Before cutting a release** — ensure README version numbers match `plugin.json`
- **After a CHANGELOG update** — pull the new "What's New" section into README automatically
- **On demand:** `/maestro readme` to do a full refresh

## Input

The skill reads entirely from the plugin's own file tree. No external input is required:

| Source | What it provides |
|--------|-----------------|
| `skills/*/SKILL.md` | Skill names, descriptions, and categories |
| `commands/*.md` | Slash command list and descriptions |
| `agents/*.md` | Agent names and roles |
| `squads/*/squad.md` | Squad names and descriptions |
| `profiles/configs/*.yaml` | Profile names |
| `templates/*.md` | Template names |
| `hooks/hooks.json` | Active hook event types |
| `.claude-plugin/plugin.json` | Current version |
| `CHANGELOG.md` | Latest release entry for "What's New" |

## Process

### Step 1: Inventory the Plugin

Count every component by walking the directory tree:

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

### Step 2: Categorize Skills

Read the `description` field from each `SKILL.md` frontmatter and group skills into categories. Use the following heuristic for auto-categorization:

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

### Step 3: Extract "What's New"

Read `CHANGELOG.md` and extract the most recent versioned entry (everything between the first `## [x.y.z]` heading and the next one). Strip the heading line itself; keep the body verbatim.

### Step 4: Build the Updated README

Produce a complete README.md. The structure must include all of the following sections, in order:

#### 4a. Header block

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

#### 4b. Table of Contents

Generate a ToC from the major README sections. At minimum include:

- What's New
- Skills (with each category as a sub-entry)
- Commands
- Agents
- Squads
- Profiles
- Installation
- Quick Start
- Contributing

#### 4c. What's New

```markdown
## What's New in v{VERSION}

{latest CHANGELOG entry body}
```

#### 4d. Skills by Category

For each category (only if it has at least one skill), emit a subsection:

```markdown
### {Category Name}

| Skill | Description |
|-------|-------------|
| `{name}` | {description} |
```

Sort skills alphabetically within each category.

#### 4e. Commands

```markdown
## Commands

| Command | Description |
|---------|-------------|
| `/maestro {name}` | {frontmatter description, first sentence only} |
```

Extract the description from the frontmatter `description` field. If no frontmatter description exists, use the first non-empty line after the first `#` heading.

#### 4f. Agents

```markdown
## Agents

| Agent | Model | Description |
|-------|-------|-------------|
| `{name}` | `{model}` | {description} |
```

#### 4g. Squads

```markdown
## Squads

| Squad | Description |
|-------|-------------|
| `{name}` | {description} |
```

#### 4h. Profiles

```markdown
## Profiles

| Profile | Description |
|---------|-------------|
| `{name}` | {description} |
```

#### 4i. Preserve existing sections

The following sections should be **preserved verbatim** from the current README.md if they already exist. Do NOT regenerate them — copy them unchanged:

- Installation
- Quick Start / Getting Started
- Prerequisites
- Configuration
- Contributing
- License

If any of these sections are absent from the current README, insert a minimal placeholder.

### Step 5: Write the File

Write the complete generated content to `README.md` at the plugin root. If `README.md` already exists, replace it entirely — the generated file is authoritative.

Print a confirmation summary after writing:

```
README.md updated:
  - {SKILLS} skills across {N} categories
  - {COMMANDS} commands
  - {AGENTS} agents
  - {SQUADS} squads
  - {PROFILES} profiles
  - Version: {VERSION}
  - What's New: pulled from CHANGELOG v{VERSION}
```

## Output

A single updated `README.md` at the plugin root.

## Error Handling

| Problem | Action |
|---------|--------|
| `CHANGELOG.md` missing | Omit "What's New" section; warn in output |
| `CHANGELOG.md` has no versioned entry | Omit "What's New" section; warn |
| A SKILL.md has no frontmatter description | Use skill directory name as description, warn |
| A command file has no frontmatter | Use filename (without .md) as command name, skip description |
| Version in plugin.json is empty | Use "unknown" in badge; warn |

## Constraints

- Do NOT modify any file other than `README.md`.
- Do NOT install dependencies. Use only shell tools (bash, awk, grep, python3) or Claude's native file reading.
- The generated README must be valid Markdown. No raw HTML unless it was already present in preserved sections.
- Preserve the exact shield.io badge URL format — only substitute the value portion after the last `-` in the badge label.
- Run time target: under 30 seconds for a full regeneration.
