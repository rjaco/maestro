---
name: aware
description: "Run awareness checks — proactive heartbeat monitoring for quality gates, dependencies, conventions, coverage trends, and tech debt"
argument-hint: "[check|status|history]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
  - AskUserQuestion
---

# Maestro Aware

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
 █████╗ ██╗    ██╗ █████╗ ██████╗ ███████╗
██╔══██╗██║    ██║██╔══██╗██╔══██╗██╔════╝
███████║██║ █╗ ██║███████║██████╔╝█████╗
██╔══██║██║███╗██║██╔══██║██╔══██╗██╔══╝
██║  ██║╚███╔███╔╝██║  ██║██║  ██║███████╗
╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
```

Heartbeat-style proactive monitoring. Checks quality gates, dependency security, convention compliance, coverage trends, and tech debt. Surfaces issues without being asked.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

Check `awareness.enabled` in config. If disabled:

```
[maestro] Awareness monitoring is currently disabled.

  Enable it with:
    /maestro config set awareness.enabled true

  Or run a one-time check now with:
    /maestro aware check
```

## Step 2: Handle Arguments

### No arguments — Show awareness overview

Read `.maestro/config.yaml` for `awareness` settings. Glob `.maestro/logs/awareness-*.md` to find the most recent report.

```
+---------------------------------------------+
| Awareness Monitor                           |
+---------------------------------------------+

  Monitoring: <enabled|disabled>
  Interval:   every <N> minutes
  Last check: <timestamp | never>

  Checks configured:
    (ok) Quality gates
    (ok) Dependency audit
    (ok) Convention review
    ( -) Coverage trends   (disabled)
    ( -) Tech debt scan    (disabled)

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Aware"
- Options:
  1. label: "Run a check now", description: "Execute all configured awareness checks immediately"
  2. label: "View current status", description: "Show the result of the last awareness run"
  3. label: "Browse history", description: "List all past awareness reports"

### `check` — Run awareness checks now

Invoke the awareness skill from `skills/awareness/SKILL.md` with the currently configured checks. The skill runs each enabled check in sequence:

**1. Quality Gates**

```bash
tsc --noEmit 2>&1 | tail -20
npm run lint 2>&1 | tail -20
npm test 2>&1 | tail -20
```

Compare results against the last report. Flag new failures only (do not re-alert on known failures).

**2. Dependency Security Audit**

```bash
npm audit --json 2>/dev/null | head -100
```

Flag critical and high severity vulnerabilities discovered since the last check.

**3. Convention Review**

Read the last 5 commits via `git log --oneline -5`. Check commit messages and file naming against project conventions (from `.maestro/dna.md` or config). Flag violations in recent work.

**4. Coverage Trends** _(if enabled)_

```bash
npm test -- --coverage --reporter=json 2>/dev/null | tail -50
```

Compare line, branch, and function coverage against the previous report. Flag decreases.

**5. Tech Debt Scan** _(if enabled)_

Count `TODO`, `FIXME`, and `HACK` comments in `src/`. Track count versus the previous check. Flag when tech debt is growing faster than it is being resolved.

Display results in the standard awareness format:

```
+---------------------------------------------+
| Awareness Check — <timestamp>               |
+---------------------------------------------+

  Quality gates:  <ok | (!) N failing>
  Dependencies:   <ok | (!) N critical/high>
  Conventions:    <ok | (!) N violations>
  Coverage:       <N>% (trend: stable | up | (!) down)
  Tech debt:      <N> items (trend: stable | up | (!) growing)

  --

  Findings:
  <detailed findings with file:line references, if any>

  Recommendations:
  <actionable suggestions, if any>

  (i) Full report: .maestro/logs/awareness-<date>-<time>.md
```

Alert thresholds applied:

| Check | Info | Warning | Alert |
|-------|------|---------|-------|
| Quality gates | All passing | New warnings | Tests/tsc failing |
| Dependencies | No issues | Low/medium | Critical/high |
| Conventions | Compliant | Minor deviations | Pattern violations |
| Coverage | Stable/increasing | Slight decrease | >5% decrease |
| Tech debt | Stable | Growing slowly | Growing fast |

If any check hits Warning or Alert level, also append a note to `.maestro/notes.md` for the dev-loop to pick up.

Save the full report to `.maestro/logs/awareness-{YYYY-MM-DD}-{HH-MM}.md`.

### `status` — Show current status

Read the most recent `.maestro/logs/awareness-*.md` file (sort by filename descending). Display its summary section.

```
+---------------------------------------------+
| Last Awareness Report                       |
+---------------------------------------------+

  Run at:         <timestamp>
  Quality gates:  <status>
  Dependencies:   <status>
  Conventions:    <status>
  Coverage:       <N>% (<trend>)
  Tech debt:      <N> items (<trend>)

  Findings: <N> total  (<N> alerts, <N> warnings, <N> info)
```

If findings exist:

```
  Alerts
  ------
  <list of alert-level findings>

  Warnings
  --------
  <list of warning-level findings>

  (i) Run /maestro aware check to refresh.
  (i) Full report: .maestro/logs/awareness-<date>-<time>.md
```

If no reports have been run:

```
[maestro] No awareness reports found.

  Run your first check with:
    /maestro aware check
```

### `history` — Browse past reports

Glob `.maestro/logs/awareness-*.md` sorted by modification time descending.

```
+---------------------------------------------+
| Awareness History                           |
+---------------------------------------------+

  Date                   Quality  Deps   Conv   Coverage  Debt
  ---------------------  -------  -----  -----  --------  ----
  2026-03-18 14:30       ok       ok     ok     82.1%     12
  2026-03-18 14:00       ok       (!)    ok     82.1%     12
  2026-03-18 13:30       ok       (!)    ok     81.8%     12
  2026-03-18 09:00       ok       ok     ok     82.3%     11

  Total: <N> reports
  (i) Reports stored in .maestro/logs/
```

If no reports exist:

```
[maestro] No awareness history found.

  Run your first check with:
    /maestro aware check

  Enable automated monitoring in .maestro/config.yaml:
    awareness.enabled: true
    awareness.interval_minutes: 30
```

## Configuration Reference

Awareness is configured in `.maestro/config.yaml`:

```yaml
awareness:
  enabled: false
  interval_minutes: 30
  checks:
    quality_gates: true
    dependency_audit: true
    convention_review: true
    coverage_trends: false
    tech_debt_scan: false
```

Enable automated scheduling with `/maestro schedule add` after enabling awareness.

## Error Handling

| Error | Action |
|-------|--------|
| Quality gate commands not found | Skip the gate, note which commands are missing |
| npm audit unavailable | Skip dependency check, note in report |
| No git history | Skip convention review |
| Coverage reporter not configured | Skip coverage trends, note in report |
| No previous report for comparison | Run without comparison, establish baseline |
| `.maestro/logs/` directory missing | Create it before saving the report |
