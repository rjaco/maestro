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
| Hooks | All hook scripts present and executable |
| Skills | All SKILL.md files have valid frontmatter |
| Mirror | `skills/` and `plugins/maestro/skills/` are in sync |
| JSON | All JSON files in `hooks/` parse correctly |
| Plugin | `claude plugin validate` — manifest, skill frontmatter, command definitions |
| Agents | Command files have valid YAML frontmatter |
| Session state | Warns on stale sessions (>1h heartbeat) |
| Dependencies | Required CLI tools (`jq`, `git`) are installed |
| Trust metrics | `trust_level` and rates are within expected ranges |
| Git status | Branch, uncommitted changes, session branch alignment |
| Integrations | MCP servers and CLI tools vs. configured providers |

## See Also

- `/maestro config` — Fix configuration issues found by doctor
- `/maestro init` — Re-initialize if core files are missing
- `/maestro help integrations` — Set up MCP integrations

Runs a comprehensive diagnostic on the Maestro installation and reports health status with actionable recommendations.

## Diagnostic Checks

Run all checks in order. Assign each result to one of three buckets: PASSED, WARNINGS (with `(!)`), or FAILED (with `(x)`).

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

Report as a single check: `(ok) Core files  .maestro/ directory present` if all required files pass, or `(x) Core files  [missing file]` listing which are missing.

### 2. Config Validation

Read `.maestro/config.yaml` and validate:
- `default_mode` is one of: yolo, checkpoint, careful
- `quality.max_qa_iterations` is a positive integer
- `quality.max_self_heal` is a positive integer
- If `integrations` section exists, validate provider names

Report as: `(ok) Config  valid YAML` or `(x) Config  [specific error]`.

### 3. Hooks

Check hook installation:
- Read `hooks/hooks.json` (relative to plugin root)
- Verify each defined hook script exists and is executable
- Count total hooks defined and how many are executable

Report as: `(ok) Hooks  N/N scripts executable` or `(x) Hooks validation  [script] not executable`.

### 4. Skills

Check all SKILL.md files:
- Count SKILL.md files under `skills/`
- Verify each has valid YAML frontmatter (name, description fields)

Report as: `(ok) Skills  N/N valid SKILL.md`.

### 5. Mirror Sync

Check that `skills/` and `plugins/maestro/skills/` are in sync:
- Count SKILL.md files in each location
- Warn if counts differ

Report as: `(ok) Mirror  N/N synced` or `(!) Mirror  X skills out of sync`.

### 6. JSON Validation

Check that all JSON files in `hooks/` parse correctly:
- `hooks/hooks.json`
- Any other `.json` files in `hooks/`

Report as: `(ok) JSON  N/N files parse`.

### 7. Plugin Validation

If `claude` CLI is available, run `claude plugin validate` (or equivalent check).
Otherwise, verify `.claude-plugin/plugin.json` parses as valid JSON with required fields.

Report as: `(ok) Plugin  claude plugin validate passed` or `(!) Plugin  [issue]`.

### 8. Agent Frontmatter

Check that agent-facing command files have valid YAML frontmatter:
- Scan `commands/*.md` for frontmatter
- Verify `description` field is present in each

Report as: `(ok) Agents  N/N valid frontmatter`.

### 9. Session State

Check `.maestro/state.local.md`:
- If it exists and `active: true`, check `last_updated`. If older than 1 hour, warn about stale heartbeat.
- If it does not exist, report as clean (no active session).

Report as: `(ok) Session  no active session`, `(ok) Session  active (fresh)`, or `(!) Session  stale heartbeat (>1h ago)`.

### 10. Dependencies

Check for required and optional CLI tools:
- `git` — required
- `jq` — required for JSON processing
- `gh` — optional, needed for GitHub integration

Report warnings for missing tools: `(!) Dependencies  jq not installed`.
Report failures for missing required tools: `(x) Dependencies  git not installed`.

### 11. Trust Metrics

Read `.maestro/trust.yaml` and check:
- `trust_level` is one of: novice, apprentice, journeyman, expert
- `total_stories` is a non-negative integer
- `qa_first_pass_rate` is between 0.0 and 1.0

Report as: `(ok) Trust metrics  [trust_level] ([total_stories] stories)` or `(x) Trust metrics  [issue]`.

### 12. Git Status

Run `git status --porcelain` and `git branch --show-current`:
- Report current branch
- Warn if there are uncommitted changes
- Warn if not on the expected branch for an active session

Report as: `(ok) Git  branch [name], clean` or `(!) Git  uncommitted changes`.

### 13. Integration Detection

Invoke the `mcp-detect` skill logic:
- Check for each MCP server (Asana, Jira, Linear, Notion, Playwright)
- Check for CLI tools (gh, obsidian)
- Compare detected integrations against configured integrations in `config.yaml`
- Warn if a provider is configured but not detected

Report as: `(ok) Integrations  [list]` or `(!) Integrations  [provider] configured but not detected`.

## Output Format

Group all check results into three severity sections: PASSED, WARNINGS, FAILED.
List PASSED first, then WARNINGS, then FAILED.
Omit a section header entirely if it has zero checks in that bucket.

```
+---------------------------------------------+
| Maestro Doctor                              |
+---------------------------------------------+

  PASSED (8 checks)
    (ok) Core files        .maestro/ directory present
    (ok) Config            valid YAML
    (ok) Hooks             13/13 scripts executable
    (ok) Skills            138/138 valid SKILL.md
    (ok) Mirror            138/138 synced
    (ok) JSON              3/3 files parse
    (ok) Plugin            claude plugin validate passed
    (ok) Agents            6/6 valid frontmatter

  WARNINGS (2 checks)
    (!) Session            stale heartbeat (>1h ago)
    (!) Dependencies       jq not installed

  FAILED (1 check)
    (x) Hooks validation   permission-request-hook.sh not executable

  Recommendations (by priority):
    1. (x) Fix: chmod +x hooks/permission-request-hook.sh
    2. (!) Install: sudo apt install jq
    3. (i) Optional: Connect a kanban provider
```

### Formatting rules

- List PASSED checks first, then WARNINGS, then FAILED.
- Omit a section header entirely if it has zero checks (e.g., no "FAILED (0 checks)" line).
- If all checks pass, show only the PASSED section and a clean summary line.
- Align check names and descriptions using spaces so descriptions start at a consistent column.
- Use 2-space indent for content within each severity section.
- No blank lines within a severity block; one blank line between blocks.

### Clean output (no warnings or failures)

```
+---------------------------------------------+
| Maestro Doctor                              |
+---------------------------------------------+

  PASSED (11 checks)
    (ok) Core files        .maestro/ directory present
    (ok) Config            valid YAML
    (ok) Hooks             13/13 scripts executable
    (ok) Skills            138/138 valid SKILL.md
    (ok) Mirror            138/138 synced
    (ok) JSON              3/3 files parse
    (ok) Plugin            claude plugin validate passed
    (ok) Agents            6/6 valid frontmatter
    (ok) Session           no active session
    (ok) Trust metrics     journeyman (82 stories)
    (ok) Git               branch main, clean

  All checks passed. Maestro is healthy.
```

## Recommendations Engine

Based on the diagnostic results, generate actionable recommendations grouped by priority.
Each recommendation must be labeled with its severity indicator.
List (x) failures first, then (!) warnings, then (i) optional improvements.
Maximum 5 recommendations total.

Format:
```
  Recommendations (by priority):
    N. (x) Fix: [specific action with exact command]
    N. (!) Install: [tool with install command]
    N. (i) Optional: [suggestion]
```

| Condition | Recommendation |
|-----------|----------------|
| Hook not executable | `(x) Fix: chmod +x hooks/[script-name]` |
| Core files missing | `(x) Fix: /maestro init` |
| Config validation errors | `(x) Fix: /maestro config reset` |
| Mirror out of sync | `(x) Fix: re-run plugin install or sync script` |
| `jq` not installed | `(!) Install: sudo apt install jq` |
| `git` not installed | `(!) Install: sudo apt install git` |
| Stale session (>1h heartbeat) | `(!) Check: /maestro status` |
| Stale session (>24h heartbeat) | `(!) Abort: /maestro status abort` |
| Uncommitted changes | `(!) Stash or commit changes before starting Maestro` |
| Configured provider not detected | `(!) Check MCP server setup for [provider]` |
| Trust level novice with >5 stories | `(!) Check trust.yaml for corruption` |
| No kanban configured | `(i) Optional: Connect a kanban provider` |
| No knowledge base configured | `(i) Optional: /maestro brain connect` |
