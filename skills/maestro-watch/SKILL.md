---
name: maestro-watch
description: "Enhanced continuous monitoring that wraps CronCreate for one-command autonomous project health. Monitors tests, types, lint, Lighthouse, and dependency security. Auto-creates fix stories on failure. Dashboard-integrated."
---

# Maestro Watch

One-command autonomous project monitoring. `/maestro watch` starts continuous health checks across tests, type checking, lint, performance, and security. When a check fails, it auto-creates a targeted fix story and optionally auto-fixes. Runs alongside an active dev-loop without interfering.

This skill extends the base `watch` skill with /loop-style monitoring: a persistent, self-healing watchdog that surfaces failures as actionable stories rather than raw log entries.

## Commands

| Command | Action |
|---------|--------|
| `/maestro watch` | Start monitoring with current config |
| `/maestro watch start` | Explicit start (same as above) |
| `/maestro watch stop` | Cancel all scheduled checks |
| `/maestro watch status` | Show active checks, schedule, last results |
| `/maestro watch run` | One-shot: run all checks immediately |
| `/maestro watch log` | Show last 20 log entries |
| `/maestro watch config` | Print current watch configuration |

## Configuration

Read from `.maestro/config.yaml` under the `maestro_watch` key:

```yaml
maestro_watch:
  enabled: true

  checks:
    tests:
      enabled: true
      interval: "*/15 * * * *"    # every 15 minutes
      command: null               # null = read from DNA
      on_failure: create_story

    typecheck:
      enabled: true
      interval: "*/15 * * * *"
      command: null
      on_failure: create_story

    lint:
      enabled: true
      interval: "*/30 * * * *"
      command: null
      on_failure: notify_only     # lint failures are informational

    lighthouse:
      enabled: false              # requires dev server running
      interval: "0 * * * *"      # hourly
      url: null                   # set to your local dev URL
      budget:
        performance: 90
        accessibility: 95
        best_practices: 90
        seo: 80
      on_failure: create_story

    security:
      enabled: true
      interval: "0 */6 * * *"    # every 6 hours
      command: null               # null = npm audit / pip audit / cargo audit
      on_failure: create_story
      severity_threshold: high    # low | medium | high | critical

  auto_fix: false                 # set true to auto-execute fix stories (yolo mode)
  dev_loop_safe: true             # pause auto-fix if a dev-loop is actively running
  log_file: .maestro/watch.log
  fix_story_dir: .maestro/stories/watch-fixes/
```

If the `maestro_watch` section is absent, fall back to base `watch` skill defaults.

## Setup

When `/maestro watch` is invoked:

1. Read `.maestro/config.yaml` for `maestro_watch` settings
2. Read `.maestro/dna.md` for project-specific commands (test runner, lint, typecheck)
3. Detect the project type (Node, Python, Rust, etc.) and auto-fill `null` commands
4. Register each enabled check as a CronCreate job:

```
CronCreate
  name: "maestro-watch-tests"
  schedule: "*/15 * * * *"
  command: "Run Maestro watch check: tests. Execute [test command from DNA]. Parse exit code and output. Append results to .maestro/watch.log. If failing, write alert to .maestro/watch-alerts.md."

CronCreate
  name: "maestro-watch-typecheck"
  schedule: "*/15 * * * *"
  command: "Run Maestro watch check: typecheck. Execute [tsc command from DNA]. Parse exit code and output. Append results to .maestro/watch.log."

CronCreate
  name: "maestro-watch-security"
  schedule: "0 */6 * * *"
  command: "Run Maestro watch check: security audit. Execute npm audit --audit-level=high. Parse vulnerabilities. Append to .maestro/watch.log. If new high/critical vulns found, write alert to .maestro/watch-alerts.md."
```

5. Confirm all jobs registered:

```
Watch started

  Check              Interval    Status
  tests              15 min      scheduled (maestro-watch-tests)
  typecheck          15 min      scheduled (maestro-watch-typecheck)
  lint               30 min      scheduled (maestro-watch-lint)
  lighthouse         --          disabled (no dev URL configured)
  security           6 hr        scheduled (maestro-watch-security)

  auto_fix: off
  log: .maestro/watch.log

  Stop with: /maestro watch stop
```

## Check Execution

Each scheduled run for a check:

### 1. Execute Check

```bash
# Tests
[test command from DNA — e.g., npm test, pytest, cargo test]

# TypeScript
npx tsc --noEmit

# Lint
[lint command from DNA — e.g., npm run lint, ruff check ., cargo clippy]

# Lighthouse (if enabled and URL is set)
npx lighthouse [url] --output json --quiet

# Security
npm audit --json        # Node
pip-audit --format json # Python
cargo audit --json      # Rust
```

### 2. Parse Results

| Outcome | Condition |
|---------|-----------|
| PASS | Clean exit (code 0), no errors |
| FAIL | Non-zero exit, parse output for specifics |
| SKIP | Check disabled, command unavailable, or dev server unreachable |
| REGRESS | Check was passing in the previous run and is now failing |

The `REGRESS` state is the critical signal — it means something broke between runs.

### 3. Log Results

Append to `.maestro/watch.log`:

```
[2026-03-18T14:30:00Z] WATCH RUN
  tests:     PASS  (48 passing, 0 failing)
  typecheck: PASS  (clean)
  lint:      PASS  (clean)
  security:  PASS  (0 vulnerabilities)

[2026-03-18T15:00:00Z] WATCH RUN
  tests:     REGRESS  (was: PASS — now: 2 failing)
    FAIL src/auth/token.test.ts — "should reject expired tokens"
    FAIL src/auth/token.test.ts — "should rotate refresh tokens on use"
  typecheck: PASS
  lint:      PASS
  security:  PASS

  Alert written to .maestro/watch-alerts.md
```

### 4. Handle Failures

#### on_failure: notify_only

Write to `.maestro/notes.md`:

```markdown
## [2026-03-18T15:00:00Z] — Watch Alert: tests REGRESS

**Check:** tests
**Status:** REGRESS (was passing, now failing)
**Errors:**
  - src/auth/token.test.ts — "should reject expired tokens"
  - src/auth/token.test.ts — "should rotate refresh tokens on use"
**Action:** Logged. No auto-fix. Review when ready.
```

#### on_failure: create_story

Generate a targeted fix story in `.maestro/stories/watch-fixes/`:

```yaml
---
id: WATCH-FIX-20260318-150000
slug: fix-tests-token-regression
title: "Fix: test regression — token expiry and refresh rotation"
model_recommendation: sonnet
type: infrastructure
satisfies: []
source: maestro-watch
created: "2026-03-18T15:00:00Z"
---

## Problem

Two tests began failing at 15:00 UTC. These tests were passing at 14:30 UTC.
The regression likely coincides with recent changes to src/auth/.

## Acceptance Criteria

1. `npm test` passes cleanly with 0 failing tests
2. The specific tests listed below pass individually when run in isolation
3. No existing passing tests are broken by the fix

## Failing Tests

- `src/auth/token.test.ts` — "should reject expired tokens"
- `src/auth/token.test.ts` — "should rotate refresh tokens on use"

## Error Output

[exact error output from the failing check]

## Context for Implementer

- Last passing run: 2026-03-18T14:30:00Z
- Current failing run: 2026-03-18T15:00:00Z
- Affected file(s): src/auth/token.test.ts, likely src/auth/token.ts
- Source: Automated watch check (maestro-watch-tests)
```

Write an alert to `.maestro/watch-alerts.md`:

```markdown
## [2026-03-18T15:00:00Z] REGRESS — tests

Fix story created: `.maestro/stories/watch-fixes/fix-tests-token-regression.md`
Status: awaiting execution
```

#### auto_fix: true

When `auto_fix: true`, immediately execute the fix story:

1. Check `dev_loop_safe` setting:
   - If `true` and a dev-loop session is active (`.maestro/state.local.md` has `status: IN_PROGRESS`): queue the fix, do not execute now. Add to `.maestro/notes.md` for the orchestrator to pick up between stories.
   - If `false` or no dev-loop is active: execute immediately.

2. Dispatch fix story via dev-loop in yolo mode:

```yaml
Agent(
  subagent_type: "maestro:maestro-implementer",
  description: "Auto-fix: [check type] regression from watch",
  isolation: "worktree",
  run_in_background: true,
  model: "sonnet",
  prompt: "[fix story content]"
)
```

3. Re-run the failing check after fix completes.
4. Log outcome to `.maestro/watch.log`:

```
[2026-03-18T15:12:00Z] AUTO-FIX RESULT
  story: fix-tests-token-regression
  fix: APPLIED
  re-check: PASS (48 passing, 0 failing)
  commit: fix(auth): restore token expiry and refresh rotation logic
```

## Dev-Loop Coexistence

`/maestro watch` is designed to run alongside an active dev-loop without interfering.

```
Active dev-loop: Building story 03-frontend-ui
Active watch:    Monitoring tests, typecheck, lint

Rules:
1. Watch checks run on the MAIN branch state, not the active worktree
2. If a watch check detects a failure in a file the current story is modifying:
   - Tag the alert as "in-flight" — likely being fixed by current story
   - Do not create a duplicate fix story
   - Re-run the check after the dev-loop story completes
3. If auto_fix is true and dev_loop_safe is true:
   - Queue fix stories, do not dispatch during active dev-loop
   - Orchestrator picks them up at the next story checkpoint
4. Watch results appear in /maestro dashboard under the "Watch" panel
```

## Lighthouse Integration

When `lighthouse.enabled: true` and a `url` is configured:

```yaml
lighthouse:
  enabled: true
  interval: "0 * * * *"
  url: "http://localhost:3000"
  budget:
    performance: 90
    accessibility: 95
    best_practices: 90
    seo: 80
  on_failure: create_story
```

Watch runs Lighthouse against the URL and compares scores to budget:

```
[2026-03-18T16:00:00Z] LIGHTHOUSE
  performance:    87  (budget: 90) FAIL  -3
  accessibility: 100  (budget: 95) PASS  +5
  best_practices: 92  (budget: 90) PASS  +2
  seo:            85  (budget: 80) PASS  +5

  Budget exceeded: performance (87 < 90)
  Fix story created: fix-lighthouse-performance-regression
```

The fix story for Lighthouse regressions includes the full JSON report as context.

## Security Audit Integration

Runs the appropriate audit tool for the detected ecosystem:

| Ecosystem | Command | Vuln Source |
|-----------|---------|------------|
| Node.js | `npm audit --json` | npm advisory database |
| Python | `pip-audit --format json` | PyPI advisories |
| Rust | `cargo audit --json` | RustSec |
| Go | `govulncheck ./...` | Go vuln database |

Fix stories for security findings include:
- CVE ID(s) and severity
- Affected package and version
- Recommended upgrade path
- Whether the vulnerability is in a direct or transitive dependency

## Dashboard Integration

When `/maestro dashboard` is rendered, a Watch panel shows:

```
+----------------------------------------------+
| Watch                               [running] |
+----------------------------------------------+
  Last run:   2026-03-18 15:00 (15 min ago)
  Next run:   2026-03-18 15:15 (in 0 min)

  tests        PASS  48/48
  typecheck    PASS  clean
  lint         PASS  clean
  security     PASS  0 vulns

  Alerts:      0 open
  Auto-fix:    off

  [run now]  [stop]  [config]
+----------------------------------------------+
```

Alert count links to `.maestro/watch-alerts.md`. The panel updates after each watch run.

## Stopping Watch

```
/maestro watch stop
```

1. Call `CronDelete` for each registered watch job:
   ```
   CronDelete name: "maestro-watch-tests"
   CronDelete name: "maestro-watch-typecheck"
   CronDelete name: "maestro-watch-lint"
   CronDelete name: "maestro-watch-security"
   ```
2. Log stop event to `.maestro/watch.log`
3. Confirm:

```
Watch stopped

  Removed 4 scheduled checks.
  Log preserved at .maestro/watch.log
  Alerts preserved at .maestro/watch-alerts.md
```

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `watch` | Base skill; maestro-watch adds auto-fix stories, Lighthouse, security, and dashboard integration |
| `scheduler` | Uses the same CronCreate/CronDelete primitives |
| `dev-loop` | Watch coexists with dev-loop; dev_loop_safe prevents interference |
| `dashboard` | Watch panel rendered in dashboard output |
| `notify` | If configured, watch failures can trigger Slack/Discord/Telegram alerts |
| `ci-watch` | ci-watch monitors CI pipelines; maestro-watch monitors local dev quality |
