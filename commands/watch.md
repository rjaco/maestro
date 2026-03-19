---
name: watch
description: "Start continuous project health monitoring — tests, types, lint, Lighthouse, and dependency security. Auto-creates fix stories on failure. Runs alongside an active dev-loop without interfering."
argument-hint: "[start|stop|status|logs]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
---

# /maestro watch

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
██╗    ██╗ █████╗ ████████╗ ██████╗██╗  ██╗
██║    ██║██╔══██╗╚══██╔══╝██╔════╝██║  ██║
██║ █╗ ██║███████║   ██║   ██║     ███████║
██║███╗██║██╔══██║   ██║   ██║     ██╔══██║
╚███╔███╔╝██║  ██║   ██║   ╚██████╗██║  ██║
 ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝
```

Continuous autonomous project health monitoring. Watches tests, types, lint, Lighthouse performance, and dependency security. When a check fails, auto-creates a targeted fix story. Designed to run alongside an active dev-loop without interference.

---

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

Read `.maestro/dna.md` to detect the project type (Node, Python, Rust, Go) and auto-fill the appropriate test, lint, and typecheck commands where the config has `null`.

---

## Step 2: Handle Arguments

### No arguments or `start` — Start monitoring

Invoke the `maestro-watch` skill from `skills/maestro-watch/SKILL.md` to begin continuous monitoring.

**Configuration read from `.maestro/config.yaml` under the `maestro_watch` key:**

```yaml
maestro_watch:
  enabled: true
  checks:
    tests:
      enabled: true
      interval: "*/15 * * * *"
      command: null              # auto-detected from DNA
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
      on_failure: notify_only
    lighthouse:
      enabled: false             # requires dev server running
      interval: "0 * * * *"
      url: null
      budget:
        performance: 90
        accessibility: 95
        best_practices: 90
        seo: 80
      on_failure: create_story
    security:
      enabled: true
      interval: "0 */6 * * *"
      command: null
      on_failure: create_story
      severity_threshold: high
  auto_fix: false
  dev_loop_safe: true
  log_file: .maestro/watch.log
  fix_story_dir: .maestro/stories/watch-fixes/
```

If the `maestro_watch` section is absent, fall back to the defaults above.

Register each enabled check as a `CronCreate` job, then confirm:

```
+---------------------------------------------+
| Watch Started                               |
+---------------------------------------------+

  Check              Interval    Status
  tests              15 min      scheduled (maestro-watch-tests)
  typecheck          15 min      scheduled (maestro-watch-typecheck)
  lint               30 min      scheduled (maestro-watch-lint)
  lighthouse         --          disabled (no dev URL configured)
  security           6 hr        scheduled (maestro-watch-security)

  auto_fix:  off
  log:       .maestro/watch.log

  Stop with: /maestro watch stop
  Status:    /maestro watch status
```

If watch is already running (CronCreate jobs already registered):

```
[maestro] Watch is already running.

  Use /maestro watch status to see active checks.
  Use /maestro watch stop to cancel all checks before restarting.
```

---

### `stop` — Cancel all scheduled checks

Call `CronDelete` for each registered watch job:
- `maestro-watch-tests`
- `maestro-watch-typecheck`
- `maestro-watch-lint`
- `maestro-watch-lighthouse` (if it was scheduled)
- `maestro-watch-security`

Log the stop event to `.maestro/watch.log`. Then confirm:

```
+---------------------------------------------+
| Watch Stopped                               |
+---------------------------------------------+

  Removed 4 scheduled checks.
  Log preserved at .maestro/watch.log
  Alerts preserved at .maestro/watch-alerts.md

  Restart with: /maestro watch start
```

If no watch jobs are currently registered:

```
[maestro] Watch is not currently running.

  Start with: /maestro watch start
```

---

### `status` — Show active checks and last results

Read `.maestro/watch.log` for the most recent run entry. Read `.maestro/watch-alerts.md` for open alerts.

```
+---------------------------------------------+
| Watch Status                                |
+---------------------------------------------+

  State:     running
  Last run:  2026-03-18 15:00 (15 min ago)
  Next run:  2026-03-18 15:15 (in 0 min)

  Check              Last Result     Next Run
  tests              PASS (48/48)    15 min
  typecheck          PASS (clean)    15 min
  lint               PASS (clean)    30 min
  lighthouse         DISABLED        --
  security           PASS (0 vulns)  6 hr

  Open alerts:  0
  auto_fix:     off
  log:          .maestro/watch.log
```

If a check is in `REGRESS` state:

```
  tests              REGRESS         next: 15 min
    ! 2 failing since 15:00 — fix story created: fix-tests-token-regression
```

If watch is not running:

```
+---------------------------------------------+
| Watch Status                                |
+---------------------------------------------+

  State:   stopped

  Last run: 2026-03-18 14:30 (47 min ago)
  Alerts:  1 open

  Start with: /maestro watch start
```

---

### `logs` — Show recent log entries

Read `.maestro/watch.log` and display the last 20 entries:

```
+---------------------------------------------+
| Watch Log (last 20 entries)                 |
+---------------------------------------------+

  [2026-03-18T15:00:00Z] WATCH RUN
    tests:     PASS  (48 passing, 0 failing)
    typecheck: PASS  (clean)
    lint:      PASS  (clean)
    security:  PASS  (0 vulnerabilities)

  [2026-03-18T14:45:00Z] WATCH RUN
    tests:     REGRESS  (was: PASS — now: 2 failing)
      FAIL src/auth/token.test.ts — "should reject expired tokens"
      FAIL src/auth/token.test.ts — "should rotate refresh tokens on use"
    typecheck: PASS
    lint:      PASS
    security:  PASS

    Fix story created: .maestro/stories/watch-fixes/fix-tests-token-regression.md

  ...

  (i) Full log: .maestro/watch.log
```

If the log file does not exist:

```
[maestro] No watch log found.

  Start monitoring with: /maestro watch start
```

---

## On-Failure Behavior

### `notify_only`

Write a note to `.maestro/notes.md` for the dev-loop to pick up. No story created.

### `create_story`

Generate a targeted fix story in `.maestro/stories/watch-fixes/` with:
- Exact error output from the failing check
- Last passing run timestamp
- Affected files (inferred from error output)
- Source attribution (`maestro-watch`)

Write an alert entry to `.maestro/watch-alerts.md`.

### `auto_fix: true`

Immediately dispatch the fix story via dev-loop in yolo mode using `Agent()`. Respects `dev_loop_safe`: if a dev-loop session is active, queue the fix rather than dispatching immediately.

---

## Dev-Loop Coexistence

Watch is designed to run alongside an active dev-loop without interfering:

1. Watch checks run against the main branch state, not the active worktree.
2. If a watch failure involves a file the current story is modifying, tag the alert as "in-flight" — do not create a duplicate fix story.
3. Re-run the affected check after the dev-loop story completes.
4. If `auto_fix: true` and `dev_loop_safe: true`, queue fix stories instead of dispatching during active dev-loop.

---

## Error Handling

| Error | Action |
|-------|--------|
| Test command not found | Skip the check, note which command is missing |
| CronCreate unavailable | Fall back to manual polling; warn user |
| `.maestro/watch.log` missing | Create it before first write |
| `.maestro/stories/watch-fixes/` missing | Create it before writing fix stories |
| Dev server unreachable for Lighthouse | Disable Lighthouse check for this run; re-enable on next run |
| Security audit tool unavailable | Skip security check, note in log |

---

## Integration

- **maestro-watch skill**: `skills/maestro-watch/SKILL.md` — implements all check execution and fix story logic
- **scheduler skill**: same CronCreate/CronDelete primitives
- **dev-loop**: watch coexists with dev-loop; `dev_loop_safe` prevents interference
- **dashboard**: watch panel rendered in `/maestro dashboard` output
- **notify**: watch failures can trigger Slack/Discord/Telegram alerts if configured
- **ci-watch**: ci-watch monitors CI pipelines; watch monitors local dev quality
