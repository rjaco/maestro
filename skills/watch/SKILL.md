---
name: watch
description: "Continuous project monitoring via CronCreate. Schedules periodic checks for tests, type errors, and performance regressions."
---

# Watch

Schedules periodic health checks for the project using CronCreate. Catches regressions early by running the test suite, type checker, and performance audits on a configurable schedule.

## Configuration

Read watch settings from `.maestro/config.yaml`:

```yaml
watch:
  enabled: true
  frequency: "*/30 * * * *"    # every 30 minutes during active development
  checks:
    tests: true
    typecheck: true
    lint: false                 # optional, can be noisy
    lighthouse: false           # requires dev server
  severity_threshold: error     # error | warning | info
  auto_fix: false               # create fix stories automatically
  log_file: .maestro/watch.log
```

If the `watch` section does not exist in config.yaml, use these defaults:
- frequency: every 30 minutes
- checks: tests + typecheck
- severity_threshold: error
- auto_fix: false

## Setup

When the watch skill is invoked:

1. Read `.maestro/config.yaml` for watch settings
2. Read `.maestro/dna.md` for the correct test and typecheck commands
3. Schedule the checks via CronCreate:

```
Schedule: [frequency from config]
Task: Run project health checks (tests, typecheck)
Commands:
  - [test command from DNA]
  - [typecheck command from DNA]
  - [lint command if enabled]
```

## Check Execution

Each scheduled run:

### 1. Run Checks

Execute each enabled check in sequence:

```bash
# Tests
npm test 2>&1

# TypeScript
npx tsc --noEmit 2>&1

# Lint (if enabled)
npm run lint 2>&1
```

### 2. Parse Results

For each check, determine:
- **PASS** — Clean exit, no errors
- **FAIL** — Non-zero exit code, parse error output for specifics
- **SKIP** — Check is disabled or command not available

### 3. Log Results

Append to `.maestro/watch.log`:

```
[ISO timestamp] CHECK RESULTS
  tests:     PASS (42 passing, 0 failing)
  typecheck: FAIL (3 errors in src/components/Widget.tsx)
  lint:      SKIP (disabled)
```

### 4. Handle Failures

If any check fails and severity meets the threshold:

**If `auto_fix: false` (default):**
- Log the failure to `.maestro/watch.log`
- If a Maestro session is active, add a note to `.maestro/notes.md`:
  ```
  ## [timestamp] — Watch Alert
  **Intent:** urgent-fix
  **Message:** TypeScript check failed: 3 errors in src/components/Widget.tsx
  **Action taken:** Logged to watch.log. Manual fix required.
  ```

**If `auto_fix: true`:**
- Generate a fix story for each failure:
  ```yaml
  ---
  id: WATCH-FIX-[timestamp]
  slug: fix-[check-type]-[short-description]
  title: "Fix: [check type] failure — [short description]"
  model_recommendation: sonnet
  type: infrastructure
  ---
  ## Acceptance Criteria
  1. [The check command] passes cleanly

  ## Context for Implementer
  - Error output: [exact error]
  - Affected files: [parsed from error output]
  ```
- Execute the fix story via dev-loop in yolo mode
- Re-run the failing check to verify the fix
- Log the outcome

## Commands

The watch skill responds to these subcommands:

| Command | Action |
|---------|--------|
| `watch start` | Schedule checks based on config |
| `watch stop` | Cancel scheduled checks |
| `watch status` | Show current schedule, last run results, and log tail |
| `watch run` | Run all checks immediately (one-shot, no scheduling) |
| `watch log` | Show the last 20 entries from `.maestro/watch.log` |

## Integration with Opus

During an active Opus session, watch results are processed by the conversation-channel:
- PASS results are logged silently
- FAIL results are treated as `information` notes if the failure is in code not touched by the current milestone, or `urgent-fix` if the failure is in code the current milestone modified
