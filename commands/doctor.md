---
name: doctor
description: "Run a full health check on Maestro — validates config, DNA, trust metrics, git state, hooks, and integration connectivity"
argument-hint: ""
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Skill
---

# Maestro Doctor

## Usage

```
/maestro doctor
```

## Examples

```
/maestro doctor
```

_(Doctor runs automatically and produces a structured report. No flags or subcommands are needed.)_

## What It Checks

| Check | Description |
|-------|-------------|
| Core files | `.maestro/` directory, `dna.md`, `config.yaml`, `trust.yaml` |
| Config validation | Mode, quality gates, and provider names are valid |
| Trust metrics | `trust_level` and rates are within expected ranges |
| Session state | Warns on stale sessions older than 24 hours |
| Git status | Branch, uncommitted changes, session branch alignment |
| Hook installation | Stop hook is installed and executable |
| Integration detection | MCP servers and CLI tools vs. configured providers |
| Knowledge base | Vault path exists (Obsidian) or MCP available (Notion) |
| Kanban connectivity | Provider authentication and reachability |

## See Also

- `/maestro config` — Fix configuration issues found by doctor
- `/maestro init` — Re-initialize if core files are missing
- `/maestro help integrations` — Set up MCP integrations

Runs a comprehensive diagnostic on the Maestro installation and reports health status with actionable recommendations.

## Diagnostic Checks

Run all checks in order. Track pass/warn/fail counts.

### 1. Core Files

Check that `.maestro/` directory exists and contains required files:

| File | Required | Check |
|------|----------|-------|
| `.maestro/dna.md` | Yes | Exists and is not empty |
| `.maestro/config.yaml` | Yes | Exists and parses as valid YAML |
| `.maestro/trust.yaml` | Yes | Exists and contains `trust_level` |
| `.maestro/state.md` | Yes | Exists |
| `.maestro/stories/` | Yes | Directory exists |
| `.maestro/logs/` | No | Directory exists |
| `.maestro/research/` | No | Directory exists |

### 2. Config Validation

Read `.maestro/config.yaml` and validate:
- `default_mode` is one of: yolo, checkpoint, careful
- `quality.max_qa_iterations` is a positive integer
- `quality.max_self_heal` is a positive integer
- If `integrations` section exists, validate provider names

### 3. Trust Metrics

Read `.maestro/trust.yaml` and check:
- `trust_level` is one of: novice, apprentice, journeyman, expert
- `total_stories` is a non-negative integer
- `qa_first_pass_rate` is between 0.0 and 1.0

### 4. Session State

Check `.maestro/state.local.md`:
- If it exists and `active: true`, check age. If older than 24h, warn about stale session.
- If it does not exist, report as clean (no active session).

### 5. Git Status

Run `git status --porcelain` and `git branch --show-current`:
- Report current branch
- Warn if there are uncommitted changes
- Warn if not on the expected branch for an active session

### 6. Hook Installation

Check if the stop hook is properly installed:
- Read `hooks/hooks.json` (relative to plugin root)
- Verify the `Stop` hook is defined
- Check that `stop-hook.sh` exists and is executable

### 7. Integration Detection

Invoke the `mcp-detect` skill logic:
- Check for each MCP server (Asana, Jira, Linear, Notion, Playwright)
- Check for CLI tools (gh, obsidian)
- Compare detected integrations against configured integrations in `config.yaml`
- Warn if a provider is configured but not detected

### 8. Knowledge Base Connectivity

If `integrations.knowledge_base.provider` is set:
- Obsidian: check that `vault_path` exists and is a directory
- Notion: check that Notion MCP tools are available

### 9. Kanban Connectivity

If `integrations.kanban.provider` is set:
- GitHub: check that `gh` is authenticated (`gh auth status`)
- Asana: check that Asana MCP tools respond
- Linear: check that Linear MCP tools respond
- Jira: check that Atlassian MCP tools respond

## Output Format

Follow the output-format standard:

```
+---------------------------------------------+
| Maestro Doctor                              |
+---------------------------------------------+

  Core:
    (ok) Directory        .maestro/ present
    (ok) Project DNA      dna.md valid
    (ok) Config           config.yaml valid
    (ok) Trust metrics    novice (0 stories)
    (ok) State            no active session

  Git:
    (ok) Branch           main
    (ok) Working tree     clean

  Hooks:
    (ok) Stop hook        installed

  Integrations:
    (ok) Playwright       available
    (ok) GitHub CLI       v2.45.0
    (x)  Asana MCP        not detected
    (x)  Linear MCP       not detected
    (ok) Obsidian CLI     v1.12.3
    (x)  Notion MCP       not detected

  Knowledge Base:
    (x)  Not configured

  Kanban:
    (x)  Not configured

  ---- Summary: 8 passed, 0 warnings, 5 not configured ----

  Recommendations:
    [1] Connect a kanban provider:
        /maestro config set integrations.kanban.provider github
    [2] Connect a knowledge base:
        /maestro brain connect
    [3] Install Asana MCP for richer kanban:
        See /maestro help integrations
```

## Recommendations Engine

Based on the diagnostic results, generate actionable recommendations:

| Condition | Recommendation |
|-----------|----------------|
| No kanban configured | Suggest connecting one (start with GitHub as simplest) |
| No knowledge base configured | Suggest connecting Obsidian or Notion |
| Stale session (>24h) | Suggest aborting: `/maestro status abort` |
| Uncommitted changes | Suggest committing or stashing before starting Maestro |
| Config validation errors | Suggest resetting: `/maestro config reset` |
| Hook not installed | Warn that the stop hook prevents accidental session exit |
| Configured provider not detected | Suggest checking MCP server setup |
| Trust level novice with >5 stories | Suggest checking trust.yaml for corruption |

Number each recommendation for easy reference. Maximum 5 recommendations (most important first).
