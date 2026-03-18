---
name: config
description: "Interactive configuration editor for Maestro"
argument-hint: "[show|set KEY VALUE|reset]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Config

View and edit Maestro configuration for this project. All settings are stored in `.maestro/config.yaml`.

## No Arguments or `show` — Display Current Config

Read `.maestro/config.yaml` and display it with inline annotations:

```
+---------------------------------------------+
| Maestro Configuration                       |
+---------------------------------------------+

  Execution:
    default_mode         checkpoint
    default_model        sonnet

  Quality Gates:
    max_qa_iterations    5          (QA review cycles per story)
    max_self_heal        3          (auto-fix attempts per story)
    run_tsc              true       (TypeScript type checking)
    run_lint             true       (linter)
    run_tests            true       (test suite)

  Cost Tracking:
    enabled              true
    forecast             true       (estimate before starting)
    ledger               true       (log per-story costs)
    budget_enforcement   true       (pause at budget limit)

  Integrations:
    Kanban:
      provider           (not set)
      sync_enabled       false
    Knowledge Base:
      provider           (not set)
      vault_path         (not set)
      sync_enabled       false

  (i) Use /maestro config set KEY VALUE to change settings.
  (i) Use /maestro config reset to restore defaults.
```

If `.maestro/config.yaml` does not exist:

```
[maestro] Config not found. Run /maestro init first.
```

## `set KEY VALUE` — Update a Setting

Support dot-notation for nested keys. Validate both key and value.

### Valid Keys and Values

| Key | Valid Values | Description |
|-----|-------------|-------------|
| `default_mode` | yolo, checkpoint, careful | Execution mode |
| `default_model` | haiku, sonnet, opus | Default implementation model |
| `quality.max_qa_iterations` | 1-10 (integer) | Max QA review cycles |
| `quality.max_self_heal` | 1-5 (integer) | Max auto-fix attempts |
| `quality.run_tsc` | true, false | Run TypeScript checks |
| `quality.run_lint` | true, false | Run linter |
| `quality.run_tests` | true, false | Run tests |
| `cost_tracking.enabled` | true, false | Enable cost tracking |
| `cost_tracking.forecast` | true, false | Show forecast before start |
| `cost_tracking.ledger` | true, false | Log per-story costs |
| `cost_tracking.budget_enforcement` | true, false | Pause at budget limit |
| `integrations.kanban.provider` | asana, jira, linear, github, null | Kanban provider |
| `integrations.kanban.sync_enabled` | true, false | Auto-sync stories |
| `integrations.kanban.project_id` | (string) | Project/board ID |
| `integrations.knowledge_base.provider` | obsidian, notion, null | Knowledge base provider |
| `integrations.knowledge_base.vault_path` | (path string) | Path to vault/workspace |
| `integrations.knowledge_base.sync_enabled` | true, false | Auto-sync enabled |
| `models.planning` | haiku, sonnet, opus | Model for decomposition/architecture |
| `models.execution` | haiku, sonnet, opus | Model for story implementation |
| `models.review` | haiku, sonnet, opus | Model for QA review |
| `models.simple` | haiku, sonnet, opus | Model for fix agents |
| `models.research` | haiku, sonnet, opus | Model for web research |
| `scheduler.enabled` | true, false | Enable cron-based scheduling |

### Validation Rules

1. Reject unknown keys with a helpful message listing valid keys.
2. Reject invalid values with the list of allowed values for that key.
3. For integration providers, check that the corresponding MCP server or CLI tool is available. Warn if not detected but still allow setting (user may install it later).
4. For `vault_path`, verify the path exists if it's set.

### Output on Success

```
[maestro] Updated: default_mode = yolo

  (i) This affects all future Maestro sessions on this project.
```

### Output on Integration Provider Change

When setting a kanban or knowledge base provider, run a quick connectivity check:

```
[maestro] Updated: integrations.kanban.provider = asana

  Connectivity check:
    (ok) Asana MCP server detected
    (!)  No project_id configured yet.
         Set it with: /maestro config set integrations.kanban.project_id YOUR_PROJECT_ID

  (i) Enable auto-sync: /maestro config set integrations.kanban.sync_enabled true
```

## `reset` — Restore Defaults

Ask for confirmation before resetting:

Use AskUserQuestion:
- Question: "Reset all configuration to defaults? Integration settings will be cleared."
- Header: "Reset"
- Options:
  1. label: "Yes, reset everything", description: "Overwrite config.yaml with default values"
  2. label: "Cancel", description: "Keep current configuration"

On confirmation, regenerate `config.yaml` with the default template (same as `maestro init` generates).

## Interactive Mode (no arguments)

When `$ARGUMENTS` is empty, after showing the current config, use AskUserQuestion to offer an interactive menu:

**Question:** "What would you like to configure?"

**Options:**
1. **Execution mode** — "Change default mode (currently: [mode])"
2. **Quality gates** — "Toggle tsc, lint, tests, adjust QA/self-heal limits"
3. **Integrations** — "Configure kanban or knowledge base providers"
4. **Cost tracking** — "Toggle forecast, ledger, budget enforcement"

### If "Execution mode":

Use AskUserQuestion:

**Question:** "Default execution mode?"

**Options:**
1. **yolo** — "Auto-approve everything. Maximum speed, minimum oversight"
2. **checkpoint** — "Pause after each story for review (recommended)"
3. **careful** — "Pause after each phase for granular control"

Update `default_mode` in config.

### If "Quality gates":

Use AskUserQuestion with multiSelect:

**Question:** "Which quality checks should run during self-heal? (select all that apply)"

**Options (multiSelect: true):**
1. **TypeScript (tsc)** — "Run tsc --noEmit to catch type errors"
2. **Linter** — "Run the project linter (eslint, etc.)"
3. **Tests** — "Run the test suite"

Update `quality.run_tsc`, `quality.run_lint`, `quality.run_tests` accordingly.

Then use AskUserQuestion:

**Question:** "Adjust QA and self-heal limits?"

**Options:**
1. **Keep current** — "QA: [max_qa] iterations, Self-heal: [max_self_heal] attempts"
2. **Strict** — "QA: 3 iterations, Self-heal: 2 attempts (fail faster)"
3. **Patient** — "QA: 8 iterations, Self-heal: 5 attempts (try harder)"

### If "Integrations":

Use AskUserQuestion:

**Question:** "Which integration to configure?"

**Options:**
1. **Kanban provider** — "Sync stories with project management (currently: [provider or 'none'])"
2. **Knowledge base** — "Connect second brain (currently: [provider or 'none'])"
3. **Back** — "Return to main menu"

If Kanban selected, use AskUserQuestion:

**Question:** "Kanban provider?"

**Options:**
1. **GitHub Issues** — "Uses gh CLI. No extra setup needed"
2. **Asana** — "Requires Asana MCP Server"
3. **Jira** — "Requires Atlassian MCP Server"
4. **Linear** — "Requires Linear MCP Server"

Update config and run connectivity check.

If Knowledge base selected, suggest running `/maestro brain connect` for the full guided setup.

### If "Cost tracking":

Use AskUserQuestion with multiSelect:

**Question:** "Cost tracking settings? (select all to enable)"

**Options (multiSelect: true):**
1. **Show forecast before starting** — "Estimate cost before execution begins"
2. **Log per-story costs** — "Track token usage in token-ledger.md"
3. **Enforce budget limits** — "Pause execution when budget is reached"

Update `cost_tracking` settings accordingly.

After any change, show confirmation and ask if they want to configure something else.
