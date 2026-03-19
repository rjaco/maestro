---
name: plugin-data
description: "Plugin data persistence via CLAUDE_PLUGIN_DATA. Documents what belongs in CLAUDE_PLUGIN_DATA (global, durable, cross-project) vs .maestro/ (project-specific, session state), and how to handle migration when Maestro updates."
---

# Plugin Data Persistence

`${CLAUDE_PLUGIN_DATA}` is a durable storage directory provided by Claude Code that survives plugin updates. Maestro uses it for global state that should persist across projects and versions — separate from `.maestro/`, which holds project-specific state.

## Storage Boundary

The core question for every piece of Maestro data: does this belong to the project, or to the user?

| Criterion | Store in `CLAUDE_PLUGIN_DATA` | Store in `.maestro/` |
|-----------|------------------------------|----------------------|
| Scope | Global — applies across all projects | Project-specific |
| Survives plugin update? | Yes — PLUGIN_DATA is preserved | No — may need migration |
| Survives project deletion? | Yes | No — lives in the project repo |
| Committed to git? | No | Optionally (some files) |
| Shared across machines? | No (local to this install) | Yes (if committed) |
| Examples | Trust history, cost metrics, soul | Stories, DNA, research, logs |

## File Layout

### `${CLAUDE_PLUGIN_DATA}/`

```
${CLAUDE_PLUGIN_DATA}/
  preferences.md          Global user preferences (preferred model tier, output verbosity, etc.)
  soul.md                 Global soul — personality and collaboration style across all projects
  trust-history.yaml      Cross-project trust data (story counts, QA pass rates by project)
  skill-packs/            Installed skill packs (not bundled with the plugin)
    base-pack/
      SKILL.md
      ...
    custom-pack/
      SKILL.md
      ...
  metrics/                Cross-project cost analytics
    2026-03.yaml
    2026-04.yaml
    all-time.yaml
```

### `.maestro/` (project-specific)

```
.maestro/
  config.yaml             Project configuration
  state.md                Current project state (milestone, active story)
  state.local.md          Session-local state (not committed)
  dna.md                  Project DNA (codebase scan output)
  stories/                Story files for this project
  milestones/             Milestone specs
  research/               Research findings for this project
  logs/                   Session logs, audit trail, CI output
  trust.yaml              Project-level trust (distinct from cross-project trust history)
  token-ledger.md         Cost tracking for this project
  webhooks/               Webhook queue and archive
```

## What Lives in PLUGIN_DATA

### `preferences.md`

Global user preferences that apply across all projects. These are set once and apply everywhere, unlike `.maestro/config.yaml` which is project-specific.

```markdown
---
schema_version: "1"
updated: 2026-03-18
---

# Global Preferences

model_tier: sonnet          # default model tier for new projects
output_verbosity: normal    # normal | minimal | verbose
checkpoint_style: box       # box | inline
explain_mode: off           # off | auto | always
cost_alerts: true           # warn when session exceeds threshold
cost_alert_threshold_usd: 5.00
```

### `soul.md`

The global soul defines Maestro's personality and collaboration style. Projects can override individual settings in their own soul file, but the global soul is the baseline.

```markdown
---
schema_version: "1"
updated: 2026-03-18
source: global
---

# Global Soul

[Global collaboration style, tone, and personality content]
```

Project-specific soul at `.maestro/soul.md` overlays the global soul — project keys take precedence over global keys.

### `trust-history.yaml`

Cross-project trust records. Each project contributes to the user's cumulative trust profile, which informs default trust levels when starting a new project.

```yaml
schema_version: "1"
updated: 2026-03-18

projects:
  myapp:
    path: /home/rodrigo/dev/myapp
    first_session: 2026-01-10
    last_session: 2026-03-15
    stories_completed: 47
    qa_pass_rate: 0.94
    final_trust_level: high

  another-project:
    path: /home/rodrigo/dev/another-project
    first_session: 2026-02-20
    last_session: 2026-03-10
    stories_completed: 12
    qa_pass_rate: 0.83
    final_trust_level: medium

summary:
  total_projects: 2
  total_stories: 59
  lifetime_qa_pass_rate: 0.92
  recommended_default_trust: high
```

When initializing a new project, Maestro reads `trust-history.yaml` to set a sensible default trust level based on the user's track record, rather than always starting at the lowest trust tier.

### `skill-packs/`

Installed skill packs that are not bundled with the core Maestro plugin. Each pack is a subdirectory with its own `SKILL.md` files.

```
skill-packs/
  mobile-pack/
    SKILL.md              Pack manifest
    ios-deploy/SKILL.md
    android-build/SKILL.md
  data-science-pack/
    SKILL.md
    notebook/SKILL.md
    dbt/SKILL.md
```

Skill packs installed via `/maestro skills install <pack>` are written here so they survive plugin updates. The plugin's bundled skills live inside the plugin installation directory.

### `metrics/`

Cross-project cost and performance analytics, organized by month.

```yaml
# metrics/2026-03.yaml
schema_version: "1"
month: 2026-03

projects:
  myapp:
    sessions: 8
    stories_completed: 23
    total_cost_usd: 34.12
    avg_story_cost_usd: 1.48

  another-project:
    sessions: 3
    stories_completed: 6
    total_cost_usd: 9.44
    avg_story_cost_usd: 1.57

totals:
  sessions: 11
  stories_completed: 29
  total_cost_usd: 43.56
  avg_story_cost_usd: 1.50
```

```yaml
# metrics/all-time.yaml
schema_version: "1"
updated: 2026-03-18

totals:
  sessions: 31
  stories_completed: 87
  total_cost_usd: 128.44
  avg_story_cost_usd: 1.48
  months_active: 3
```

After each session, Maestro appends the session cost to the current month's metrics file and updates `all-time.yaml`. Both are atomic writes (write to `.tmp`, then rename).

## What Lives in `.maestro/`

Project-specific state belongs in `.maestro/`. This directory is created per project and may be committed to git (selectively — see below).

### Committed to git (safe)

- `config.yaml` — project config (no secrets)
- `dna.md` — project DNA
- `milestones/` — milestone specs
- `stories/` — story files

### Not committed (gitignored)

- `state.local.md` — session-local ephemeral state
- `logs/` — verbose session logs
- `ci-output.json` — CI run artifacts
- `trust.yaml` — project trust (sensitive)
- `token-ledger.md` — cost data (may be sensitive)

## Migration

When Maestro updates, `CLAUDE_PLUGIN_DATA` is preserved. However, `.maestro/` state may need migration if the schema changes between versions.

### Migration Strategy

On session start, Maestro checks schema versions:

```
Read CLAUDE_PLUGIN_DATA/preferences.md schema_version
Read .maestro/config.yaml schema_version (if present)
    |
    v
Compare against current plugin version's expected schema
    |
    +-- Match → proceed normally
    |
    +-- Mismatch → run migration for that schema
```

### Migration Principles

1. **PLUGIN_DATA migrations are additive** — new keys are added with defaults, no keys are removed. Old schema versions remain readable.
2. **.maestro/ migrations may be breaking** — if story or config format changes incompatibly, Maestro runs a migration script and logs what changed to `.maestro/logs/migration.log`.
3. **Migration is never silent** — always inform the user that migration ran:
   ```
   (i) Migrated .maestro/config.yaml from schema v1 to v2.
       See .maestro/logs/migration.log for details.
   ```
4. **Migration failures are non-fatal for PLUGIN_DATA** — if a PLUGIN_DATA migration fails, Maestro falls back to defaults and warns. It never refuses to start because of PLUGIN_DATA state.
5. **Migration failures in .maestro/ are reported** — the user should be told and offered the option to reset the affected file.

### Migration Log Format

```
.maestro/logs/migration.log

2026-03-18T10:00:00Z  schema_version: 1 → 2
  config.yaml:   added `http_hooks` block with defaults
  config.yaml:   renamed `integrations.kanban.enabled` → `integrations.kanban.sync_enabled`
  trust.yaml:    no changes required
```

## Reading PLUGIN_DATA in Skills

Skills access PLUGIN_DATA via the environment variable:

```
PLUGIN_DATA_DIR = env("CLAUDE_PLUGIN_DATA") ?? ".maestro/plugin-data-fallback"

preferences_path = PLUGIN_DATA_DIR + "/preferences.md"
trust_history_path = PLUGIN_DATA_DIR + "/trust-history.yaml"
metrics_dir = PLUGIN_DATA_DIR + "/metrics/"
```

If `CLAUDE_PLUGIN_DATA` is not set (older Claude Code versions), fall back to `.maestro/plugin-data-fallback/` so the skill still works — just without cross-install persistence.

## Shell Script Access Pattern

Use the env var directly, with a fallback if the variable is not set:

```sh
DATA_ROOT="${CLAUDE_PLUGIN_DATA:-$(pwd)/.maestro/plugin-data-fallback}"

PREFERENCES="${DATA_ROOT}/preferences.md"
TRUST_HISTORY="${DATA_ROOT}/trust-history.yaml"
METRICS_DIR="${DATA_ROOT}/metrics"

mkdir -p "${DATA_ROOT}/metrics"
mkdir -p "${DATA_ROOT}/skill-packs"
```

Always create subdirectories before writing — `CLAUDE_PLUGIN_DATA` itself is guaranteed to exist when set, but subdirectories are not.

## Error Handling

| Error | Action |
|-------|--------|
| `CLAUDE_PLUGIN_DATA` not set | Fall back to `.maestro/plugin-data-fallback/`, warn once |
| PLUGIN_DATA file not readable | Use defaults, warn once per session |
| PLUGIN_DATA file not writable | Log warn, continue — data for this session is in memory only |
| Schema version mismatch | Run migration, log result, continue |
| Migration fails | Use defaults for affected key, warn, continue |
| `.maestro/` not found | Auto-create with defaults (normal first-run behavior) |

All PLUGIN_DATA operations are non-blocking. A PLUGIN_DATA read failure never prevents Maestro from running.
