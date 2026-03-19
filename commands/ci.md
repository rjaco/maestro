---
name: ci
description: "Manage CI/headless mode — enable non-interactive operation for pipelines, disable it, check current status, or run a specific feature without prompts"
argument-hint: "[enable|disable|status|run <feature>]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - AskUserQuestion
---

# Maestro CI

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Manage Maestro's CI/headless mode. In CI mode all interactive prompts are suppressed, output is JSON lines, visual chrome is removed, and the session exits with a standard exit code. Designed for GitHub Actions, scheduled builds, and any automated pipeline.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments — Show CI status

Check two sources in order:
1. `MAESTRO_CI` environment variable (`echo $MAESTRO_CI`)
2. `ci_mode.enabled` in `.maestro/config.yaml`

```
+---------------------------------------------+
| CI Mode                                     |
+---------------------------------------------+

  Status:     active | inactive
  Source:     env var (MAESTRO_CI=true) | config | not set
  fail_fast:  true | false
  Timeouts:
    story:      <N>ms (<M> minutes)
    milestone:  <N>ms (<M> minutes)
    session:    <N>ms (<M> hours)
  Artifact:   .maestro/ci-output.json

  (i) The env var MAESTRO_CI=true always takes precedence over config.
```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "CI Mode"
- Options:
  1. label: "Enable CI mode", description: "Set ci_mode.enabled: true in config"
  2. label: "Disable CI mode", description: "Set ci_mode.enabled: false in config"
  3. label: "Run a feature headlessly", description: "Execute a specific skill or loop in CI mode"
  4. label: "View last CI artifact", description: "Show .maestro/ci-output.json from the last run"

---

### `enable` — Enable CI mode in config

Update `.maestro/config.yaml`, setting `ci_mode.enabled: true`. If the `ci_mode` block does not exist, add it with all default values.

```yaml
ci_mode:
  enabled: true
  fail_fast: false
  ci_notifications: false
  timeouts:
    story_ms: 600000
    milestone_ms: 3600000
    session_ms: 14400000
  output:
    jsonl_file: null
    artifact: .maestro/ci-output.json
```

Confirm:

```
+---------------------------------------------+
| CI Mode Enabled                             |
+---------------------------------------------+

  Config:  .maestro/config.yaml updated
  Effect:  All subsequent Maestro runs will use headless mode

  (i) To override per-run, set MAESTRO_CI=true in your environment.
  (i) To disable, run /maestro ci disable.

  Behavioral changes in CI mode:
    - All AskUserQuestion prompts are auto-resolved (first option selected)
    - Output switches to JSON lines (one event per line)
    - Visual chrome suppressed (banners, box-drawing, color, emoji)
    - Desktop and audio notifications suppressed
    - Session exits with standard exit codes (0=ok, 1=story-fail, 2=milestone-fail, 3=abort)
```

---

### `disable` — Disable CI mode in config

Update `.maestro/config.yaml`, setting `ci_mode.enabled: false`.

Note: This does not unset the `MAESTRO_CI` environment variable. If the env var is set in the shell, CI mode will still be active for that session.

Confirm:

```
[maestro] CI mode disabled in config.

  (i) If MAESTRO_CI is set in your shell, it still overrides config.
  (i) To fully disable, also unset the env var: unset MAESTRO_CI
```

---

### `status` — Show detailed CI status

Show full CI configuration, last run artifact summary, and active environment state.

1. Check `MAESTRO_CI` env var.
2. Read `ci_mode` block from `.maestro/config.yaml`.
3. Check if `.maestro/ci-output.json` exists. If it does, read and summarize it.

```
+---------------------------------------------+
| CI Mode Status                              |
+---------------------------------------------+

  Environment:
    MAESTRO_CI:   true | not set
    Active:       yes | no (env var | config | neither)

  Config (.maestro/config.yaml):
    enabled:      true | false
    fail_fast:    true | false
    notifications: on | off
    Timeouts:
      story:       600,000ms (10 min)
      milestone: 3,600,000ms (60 min)
      session:  14,400,000ms (4 hr)
    Artifact:   .maestro/ci-output.json
    JSONL file: <path | none>

  Last run (.maestro/ci-output.json):
    session_id:  <id>
    started_at:  <ISO-8601>
    ended_at:    <ISO-8601>
    exit_code:   0 | 1 | 2 | 3
    milestones:  <N> complete / <N> attempted
    stories:     <N> complete / <N> attempted
    total_cost:  $<N>
```

If `.maestro/ci-output.json` does not exist:

```
  Last run: no artifact found
```

---

### `run <feature>` — Run a feature in CI mode

Run any named Maestro feature (skill, loop, or command) in headless CI mode for the current session, without modifying the persistent config.

**Supported features:** `opus-loop`, `dev-loop`, `health-check`, `story <id>`, `milestone <id>`

1. Validate the feature name. If unknown:

   ```
   [maestro] Unknown feature: <name>

     Supported features:
       opus-loop       Run the full opus-loop in headless mode
       dev-loop        Run dev-loop without prompts
       health-check    Run the health-check worker once, headlessly
       story <id>      Run a single story in headless mode
       milestone <id>  Run a single milestone in headless mode
   ```

2. Confirm before running:

   Use AskUserQuestion:
   - Question: "Run <feature> in CI mode (headless, no prompts, JSON output)?"
   - Header: "Confirm CI Run"
   - Options:
     1. label: "Yes, run now", description: "Execute with MAESTRO_CI=true for this invocation"
     2. label: "Cancel", description: "Do not run"

3. On confirmation, set `MAESTRO_CI=true` for the invocation and invoke the skill. All output is JSON lines per the CI mode output format defined in `skills/ci-mode/SKILL.md`.

4. After completion, display a human-readable summary of the JSON output:

   ```
   +---------------------------------------------+
   | CI Run Complete                             |
   +---------------------------------------------+

     Feature:    <feature>
     Exit code:  <N> (<meaning>)
     Duration:   <elapsed>
     Artifact:   .maestro/ci-output.json

     (i) Full JSON output above.
     (i) Artifact written to .maestro/ci-output.json.
   ```

---

## Exit Code Reference

| Code | Meaning |
|------|---------|
| `0` | All milestones completed successfully |
| `1` | One or more stories failed (after all retries) |
| `2` | One or more milestones failed |
| `3` | Session aborted — unrecoverable error or timeout |

---

## GitHub Actions Quick Start

To wire Maestro into a GitHub Actions workflow, add this to `.github/workflows/maestro.yml`:

```yaml
- name: Run Maestro
  env:
    MAESTRO_CI: 'true'
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: npx claude /maestro opus-loop
```

See `skills/ci-mode/SKILL.md` for the full workflow template including artifact upload and PR summary posting.
