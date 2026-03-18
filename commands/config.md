---
name: config
description: "Interactive configuration editor for Maestro"
argument-hint: "[show|set KEY VALUE|reset]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
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

```
[maestro] Reset all configuration to defaults?

  This will overwrite .maestro/config.yaml with default values.
  Your integration settings will be cleared.

  [1] Yes, reset everything
  [2] Cancel
```

On confirmation, regenerate `config.yaml` with the default template (same as `maestro-init` generates).
