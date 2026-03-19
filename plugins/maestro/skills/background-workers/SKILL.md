---
name: background-workers
description: "12 autonomous background workers that run on schedule without user prompts: health-check, dependency-audit, convention-drift, memory-decay, stale-worktree-cleanup, cost-report, security-vulnerability-scan, performance-regression-detect, api-contract-drift, test-coverage-monitor, documentation-staleness, and code-complexity-alert. All workers log to .maestro/logs/workers/ and only run when Maestro is initialized."
---

# Background Workers

Twelve autonomous workers that run on a schedule without requiring user interaction. Each worker is a lightweight read-only agent that monitors project health, logs results, and surfaces issues for the next interactive session.

Inspired by background daemon patterns where persistent workers maintain project hygiene continuously.

## Guard Condition

All workers check for Maestro initialization before running:

```bash
if [ ! -f ".maestro/dna.md" ]; then
  echo "Maestro not initialized. Skipping worker." >> .maestro/logs/workers/guard.log
  exit 0
fi
```

No worker runs if `.maestro/dna.md` does not exist.

## Worker Configuration

All workers:
- Use `CronCreate` for scheduling.
- Dispatch `maestro:maestro-proactive` agent (haiku model, read-only tools).
- Log results to `.maestro/logs/workers/<worker-name>-<date>.log`.
- Never modify production code or project files.
- Are idempotent — safe to run multiple times.

### Read-only agent configuration

```yaml
name: maestro-proactive
model: haiku
tools: [Read, Bash, Grep, Glob]
maxTurns: 20
isolation: none
```

Workers do not write to the codebase. They write only to `.maestro/logs/workers/` and `.maestro/notes.md`.

## Worker 1: health-check

**Schedule:** Every 30 minutes

**Purpose:** Run quality gates and detect regressions before the developer notices them.

### CronCreate registration

```
CronCreate
  name: "maestro-health-check"
  schedule: "*/30 * * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Run: npx tsc --noEmit, npm run lint, npm test.
    Compare results to last health log in .maestro/logs/workers/.
    If regression detected:
      - Log to .maestro/logs/workers/health-<date>.log
      - Append note to .maestro/notes.md with intent: regression
    If clean: log a one-line OK entry.
```

### Log format

```
health-check 2026-03-18T14:30:00Z
  (ok) TypeScript    clean
  (ok) Linter        clean
  (ok) Tests         47/47 passing
  status: OK
```

On regression:

```
health-check 2026-03-18T15:00:00Z
  (ok) TypeScript    clean
  (x)  Linter        2 errors
         src/routes/users.ts:42 — 'email' is assigned but never used
         src/routes/users.ts:67 — Missing return type
  (ok) Tests         47/47 passing
  status: REGRESSION
  note: Added to .maestro/notes.md
```

## Worker 2: dependency-audit

**Schedule:** Every 6 hours

**Purpose:** Detect newly published vulnerabilities in project dependencies.

### CronCreate registration

```
CronCreate
  name: "maestro-dependency-audit"
  schedule: "0 */6 * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Run: npm audit --json
    Parse output for vulnerabilities at severity: high or critical.
    Log full results to .maestro/logs/workers/dependency-audit-<date>.log.
    If high/critical found:
      - Append note to .maestro/notes.md with intent: security
      - Include package name, severity, and CVE if available.
```

### Log format

```
dependency-audit 2026-03-18T06:00:00Z
  Packages audited: 342
  Vulnerabilities: 0
  status: CLEAN
```

On findings:

```
dependency-audit 2026-03-18T12:00:00Z
  Packages audited: 342
  Vulnerabilities:
    (critical) lodash@4.17.20 — prototype pollution — CVE-2021-23337
    (high)     axios@0.21.1   — SSRF via redirect — CVE-2021-3749
  status: FLAGGED
  note: Added to .maestro/notes.md
```

## Worker 3: convention-drift

**Schedule:** Every 1 hour

**Purpose:** Check recent commits against project DNA patterns to detect when the codebase is drifting from established conventions.

### CronCreate registration

```
CronCreate
  name: "maestro-convention-drift"
  schedule: "0 * * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Read .maestro/dna.md for active conventions.
    Read last 5 commits via git log --stat -5.
    For each modified file in recent commits:
      Check for violations of dna.md patterns (naming, import style, file structure).
    If violations found:
      - Log to .maestro/logs/workers/convention-drift-<date>.log
      - Append note to .maestro/notes.md with intent: convention_drift
    If clean: log OK entry.
```

### Log format

```
convention-drift 2026-03-18T13:00:00Z
  Commits scanned: 5 (last 1h)
  Files checked: 12
  Violations: 0
  status: OK
```

On drift:

```
convention-drift 2026-03-18T14:00:00Z
  Commits scanned: 5 (last 1h)
  Files checked: 8
  Violations:
    src/services/userService.ts — uses default export (dna.md: named exports only)
    src/routes/orders.ts        — import order: third-party before internal (dna.md: internal first)
  status: DRIFT_DETECTED
  note: Added to .maestro/notes.md
```

## Worker 4: memory-decay

**Schedule:** Every session start (approximated as daily at midnight)

**Purpose:** Run the memory decay cycle so that stale memories do not accumulate and pollute future context injections.

### CronCreate registration

```
CronCreate
  name: "maestro-memory-decay"
  schedule: "0 0 * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Read .maestro/memory/memories.md.
    Apply tier-based decay:
      - lesson entries: confidence -= 0.05
      - episode entries: confidence -= 0.20
    Archive entries below confidence 0.30 to .maestro/memory/archived.md.
    Promote episodes with access_count >= 5 to lesson tier.
    Write updated memories.md.
    Log decay summary to .maestro/logs/workers/memory-decay-<date>.log.
```

### Log format

```
memory-decay 2026-03-18T00:00:00Z
  Facts:    5 — no change
  Lessons:  11 — 2 decayed, 1 archived (mem_004, conf 0.25)
  Episodes: 4 — 1 promoted to lesson (mem_009), 1 archived (mem_010)
  status: OK
  archived: mem_004, mem_010
  promoted: mem_009
```

## Worker 5: stale-worktree-cleanup

**Schedule:** Every 1 hour

**Purpose:** Find and remove abandoned git worktrees from failed or interrupted dev-loop runs. Stale worktrees can cause merge conflicts and consume disk space.

### CronCreate registration

```
CronCreate
  name: "maestro-stale-worktree-cleanup"
  schedule: "0 * * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Run: git worktree list --porcelain
    For each worktree:
      Check last modified time of worktree directory.
      If older than 24 hours AND not the main worktree:
        Mark as stale.
    Log stale worktrees to .maestro/logs/workers/stale-worktree-<date>.log.
    If stale worktrees found:
      Append note to .maestro/notes.md with intent: cleanup
      List worktree paths for user review.
    Do NOT remove automatically — flag for human review.
```

### Log format

```
stale-worktree-cleanup 2026-03-18T13:00:00Z
  Worktrees scanned: 3
  Stale (> 24h): 0
  status: CLEAN
```

On stale worktrees found:

```
stale-worktree-cleanup 2026-03-18T14:00:00Z
  Worktrees scanned: 3
  Stale (> 24h):
    .maestro/worktrees/story-03-frontend-ui  (last modified: 2026-03-17T08:30:00Z, 29h ago)
    .maestro/worktrees/story-05-auth-routes  (last modified: 2026-03-16T22:00:00Z, 39h ago)
  status: STALE_FOUND
  note: Added to .maestro/notes.md — human review required before cleanup
```

Note: The worker flags, never auto-removes. Removal is always a human action (or explicit `/maestro cleanup` command) to prevent data loss from interrupted but still-useful worktrees.

## Worker 6: cost-report

**Schedule:** End of day (daily at 6pm on weekdays)

**Purpose:** Summarize token spend across all sessions for the day, surface expensive patterns, and give the user visibility into AI cost trends.

### CronCreate registration

```
CronCreate
  name: "maestro-cost-report"
  schedule: "0 18 * * 1-5"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Read .maestro/state.local.md for today's session token logs.
    Read .maestro/logs/workers/ for any prior cost entries today.
    Aggregate:
      - Total tokens by session
      - Total tokens by story
      - Total tokens by model (haiku / sonnet / opus)
      - Estimated cost (haiku: $0.80/MTok input, $4.00/MTok output;
                        sonnet: $3.00/MTok input, $15.00/MTok output;
                        opus: $15.00/MTok input, $75.00/MTok output)
    Identify:
      - Most expensive story
      - Most expensive model tier
      - Stories that exceeded their token estimate by > 50%
    Log to .maestro/logs/workers/cost-report-<date>.log.
    Append summary note to .maestro/notes.md with intent: cost_report.
```

### Log format

```
cost-report 2026-03-18T18:00:00Z

  Today's token spend
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  By model:
    haiku     142,000 tokens   ~$0.14
    sonnet    380,000 tokens   ~$1.19
    opus       48,000 tokens   ~$1.44

  Total: 570,000 tokens | estimated cost: ~$2.77

  By story:
    04-auth-middleware   128,000 tokens  (sonnet, 3 QA iterations)
    03-frontend-ui        84,000 tokens  (sonnet, first-pass)
    02-api-routes         62,000 tokens  (haiku, first-pass)

  Most expensive: 04-auth-middleware (128K tokens — 3 QA rejections)
  Over-budget:    04-auth-middleware (estimate: 60K, actual: 128K, +113%)

  status: OK
```

## Worker 7: security-vulnerability-scan

**Schedule:** Daily (midnight)

**Priority:** High

**Purpose:** Check project dependencies for known CVEs and surface any findings with severity >= high before the next development session.

### CronCreate registration

```
CronCreate
  name: "maestro-security-vulnerability-scan"
  schedule: "0 0 * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Detect ecosystem:
      If package.json exists: run npm audit --json 2>/dev/null | grep -c '"severity"'
      If requirements.txt or pyproject.toml exists: run pip-audit --format json 2>/dev/null
    Parse output for CVEs with severity: high or critical.
    Log full results to .maestro/logs/workers/security-vulnerability-scan-<date>.log.
    If any high/critical CVE found:
      - Append note to .maestro/notes.md with intent: security
      - Include package name, severity, CVE ID, and suggested fix.
      - Suggested fix: run `npm audit fix` or `pip install --upgrade <package>`
```

### Log format

```
security-vulnerability-scan 2026-03-18T00:00:00Z
  Ecosystem: npm
  Packages audited: 318
  CVEs found: 0 (high: 0, critical: 0)
  status: CLEAN
```

On findings:

```
security-vulnerability-scan 2026-03-18T00:00:00Z
  Ecosystem: npm
  Packages audited: 318
  CVEs found: 2 (high: 1, critical: 1)
    (critical) lodash@4.17.20        — prototype pollution    — CVE-2021-23337
    (high)     follow-redirects@1.14 — open redirect via URL  — CVE-2022-0536
  status: FLAGGED
  suggested fix: npm audit fix
  note: Added to .maestro/notes.md
```

## Worker 8: performance-regression-detect

**Schedule:** After each milestone

**Priority:** Medium

**Purpose:** Compare current test execution time against a stored baseline and alert when duration increases more than 20%.

### CronCreate registration

```
CronCreate
  name: "maestro-performance-regression-detect"
  schedule: "0 * * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Read baseline from .maestro/baselines/test-duration.md.
    If no baseline file exists: record current duration as baseline and exit.
    Run test suite and capture wall-clock duration (npm test or equivalent).
    Compare current duration to baseline.
    If increase > 20%:
      - Log to .maestro/logs/workers/performance-regression-detect-<date>.log
      - Append note to .maestro/notes.md with intent: regression
      - Suggested fix: review recent changes for performance-impacting patterns
    If within threshold: log OK entry and optionally update baseline if duration improved.
```

### Log format

```
performance-regression-detect 2026-03-18T10:00:00Z
  Baseline:  42.3s  (from .maestro/baselines/test-duration.md)
  Current:   44.1s
  Delta:     +4.3%
  Threshold: 20%
  status: OK
```

On regression:

```
performance-regression-detect 2026-03-18T11:00:00Z
  Baseline:  42.3s  (from .maestro/baselines/test-duration.md)
  Current:   61.8s
  Delta:     +46.1%
  Threshold: 20%
  status: REGRESSION
  suggested fix: Review recent changes for performance-impacting patterns (heavy loops, sync I/O, unindexed queries)
  note: Added to .maestro/notes.md
```

## Worker 9: api-contract-drift

**Schedule:** After each story

**Priority:** High

**Purpose:** Detect API endpoint changes that break backward compatibility by diffing route definitions against the last known snapshot.

### CronCreate registration

```
CronCreate
  name: "maestro-api-contract-drift"
  schedule: "0 * * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Scan source files for route definitions:
      grep -rE "app\.(get|post|put|delete|patch)|router\.(get|post|put|delete|patch)" --include="*.ts" --include="*.js"
    Compare current route signatures to snapshot in .maestro/baselines/api-routes.md.
    If snapshot missing: create it from current routes and exit.
    Detect:
      - Removed endpoints (breaking)
      - Changed path parameters (breaking)
      - Changed HTTP method for same path (breaking)
    If breaking changes found without a version bump in package.json or API version header:
      - Log to .maestro/logs/workers/api-contract-drift-<date>.log
      - Append note to .maestro/notes.md with intent: security
      - Suggested fix: add API versioning (e.g. /v2/) or update API docs and bump version
    If clean: log OK entry and refresh snapshot.
```

### Log format

```
api-contract-drift 2026-03-18T10:00:00Z
  Routes scanned: 24
  Snapshot: .maestro/baselines/api-routes.md (last updated: 2026-03-17)
  Breaking changes: 0
  status: CLEAN
```

On drift:

```
api-contract-drift 2026-03-18T11:00:00Z
  Routes scanned: 23
  Snapshot: .maestro/baselines/api-routes.md (last updated: 2026-03-17)
  Breaking changes:
    (removed)  DELETE /api/users/:id/sessions  — no replacement found
    (modified) PUT /api/orders/:id             — param :id renamed to :orderId
  Version bump detected: NO
  status: DRIFT_DETECTED
  suggested fix: Add API versioning (e.g. /v2/) or update API docs and bump version in package.json
  note: Added to .maestro/notes.md
```

## Worker 10: test-coverage-monitor

**Schedule:** After each story

**Priority:** Medium

**Purpose:** Track test coverage trends and alert when coverage drops more than 5% from the established baseline.

### CronCreate registration

```
CronCreate
  name: "maestro-test-coverage-monitor"
  schedule: "0 * * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Detect test framework:
      If package.json contains jest: run npx jest --coverage --json 2>/dev/null
      If pytest is available: run pytest --cov --cov-report=json 2>/dev/null
    Parse coverage percentage from output.
    Read baseline from .maestro/baselines/test-coverage.md.
    If no baseline: record current coverage and exit.
    If coverage drop > 5% from baseline:
      - Log to .maestro/logs/workers/test-coverage-monitor-<date>.log
      - Append note to .maestro/notes.md with intent: regression
      - List files with lowest coverage
      - Suggested fix: add tests for uncovered code in recent changes
    If within threshold: log OK entry and update baseline if coverage improved.
```

### Log format

```
test-coverage-monitor 2026-03-18T10:00:00Z
  Framework: jest
  Baseline:  84.2%  (from .maestro/baselines/test-coverage.md)
  Current:   85.1%
  Delta:     +0.9%
  Threshold: -5%
  status: OK
```

On drop:

```
test-coverage-monitor 2026-03-18T11:00:00Z
  Framework: jest
  Baseline:  84.2%  (from .maestro/baselines/test-coverage.md)
  Current:   76.8%
  Delta:     -7.4%
  Threshold: -5%
  Lowest coverage files:
    src/services/paymentService.ts   — 41% (12 uncovered lines)
    src/routes/webhook.ts            — 53% (8 uncovered lines)
  status: DROP_DETECTED
  suggested fix: Add tests for uncovered code in recent changes, starting with lowest-coverage files above
  note: Added to .maestro/notes.md
```

## Worker 11: documentation-staleness

**Schedule:** Weekly (Monday at 9am)

**Priority:** Low

**Purpose:** Detect documentation files that reference function or file names that no longer exist in the source, surfacing stale docs before they mislead contributors.

### CronCreate registration

```
CronCreate
  name: "maestro-documentation-staleness"
  schedule: "0 9 * * 1"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Collect all markdown files in docs/, README.md, and .maestro/*.md.
    Extract code references: function names (word followed by `()`), file paths (containing / or .)
    For each reference:
      Check if the symbol or file still exists in the source tree via grep/glob.
    Count stale references (not found in source).
    If stale count > 3:
      - Log to .maestro/logs/workers/documentation-staleness-<date>.log
      - Append note to .maestro/notes.md with intent: cleanup
      - List doc file, line number, and stale reference for each finding
      - Suggested fix: update or remove references to deleted/renamed items
    If stale count <= 3: log OK entry with count.
```

### Log format

```
documentation-staleness 2026-03-18T09:00:00Z
  Docs scanned: 14
  References checked: 87
  Stale references: 1
  Threshold: > 3
  status: OK
```

On staleness found:

```
documentation-staleness 2026-03-18T09:00:00Z
  Docs scanned: 14
  References checked: 87
  Stale references: 5
  Threshold: > 3
  Findings:
    docs/api.md:34       — getUser()         — function deleted in src/services/userService.ts
    docs/api.md:78       — createSession()   — renamed to startSession()
    README.md:112        — src/lib/cache.ts  — file moved to src/utils/cache.ts
    docs/setup.md:22     — initDB()          — function removed, replaced by migration runner
    docs/setup.md:55     — config/db.json    — file deleted, config now in env vars
  status: STALE_FOUND
  suggested fix: Update or remove references to deleted/renamed items in the docs listed above
  note: Added to .maestro/notes.md
```

## Worker 12: code-complexity-alert

**Schedule:** After each story

**Priority:** Medium

**Purpose:** Track cyclomatic complexity of recently changed functions and alert when any function exceeds the complexity threshold.

### CronCreate registration

```
CronCreate
  name: "maestro-code-complexity-alert"
  schedule: "0 * * * *"
  command: >
    Guard: exit if .maestro/dna.md missing.
    Identify recently changed source files via git diff --name-only HEAD~1 HEAD.
    For each changed file, scan functions longer than 20 lines:
      Count complexity indicators: if, else, for, while, case, &&, ||
      A function's complexity score = number of those keywords within its body.
    Threshold: complexity score > 15 is flagged.
    If any function exceeds threshold:
      - Log to .maestro/logs/workers/code-complexity-alert-<date>.log
      - Append note to .maestro/notes.md with intent: convention_drift
      - List file, function name, and score for each offender
      - Suggested fix: refactor into smaller, single-responsibility functions
    If all functions within threshold: log OK entry.
```

### Log format

```
code-complexity-alert 2026-03-18T10:00:00Z
  Files scanned: 4  (changed in HEAD~1..HEAD)
  Functions > 20 lines: 6
  Threshold: complexity > 15
  Violations: 0
  status: OK
```

On violation:

```
code-complexity-alert 2026-03-18T11:00:00Z
  Files scanned: 4  (changed in HEAD~1..HEAD)
  Functions > 20 lines: 6
  Threshold: complexity > 15
  Violations:
    src/services/orderService.ts  processOrder()       — complexity: 23
    src/routes/checkout.ts        handleCheckout()     — complexity: 18
  status: COMPLEXITY_EXCEEDED
  suggested fix: Refactor into smaller, single-responsibility functions (target: complexity <= 10 per function)
  note: Added to .maestro/notes.md
```

## Log Directory Structure

```
.maestro/logs/workers/
  health-2026-03-18.log
  dependency-audit-2026-03-18.log
  convention-drift-2026-03-18.log
  memory-decay-2026-03-18.log
  stale-worktree-2026-03-18.log
  cost-report-2026-03-18.log
  security-vulnerability-scan-2026-03-18.log
  performance-regression-detect-2026-03-18.log
  api-contract-drift-2026-03-18.log
  test-coverage-monitor-2026-03-18.log
  documentation-staleness-2026-03-18.log
  code-complexity-alert-2026-03-18.log
```

Log files are append-only. Each run appends a timestamped block. Files rotate daily (one file per worker per day).

## Registering All Workers

To register all workers at once, run the following setup (typically called by `/maestro init` or `auto-init`):

```
CronCreate name: "maestro-health-check"                    schedule: "*/30 * * * *"  command: [see Worker 1]
CronCreate name: "maestro-dependency-audit"                schedule: "0 */6 * * *"   command: [see Worker 2]
CronCreate name: "maestro-convention-drift"                schedule: "0 * * * *"     command: [see Worker 3]
CronCreate name: "maestro-memory-decay"                    schedule: "0 0 * * *"     command: [see Worker 4]
CronCreate name: "maestro-stale-worktree-cleanup"          schedule: "0 * * * *"     command: [see Worker 5]
CronCreate name: "maestro-cost-report"                     schedule: "0 18 * * 1-5"  command: [see Worker 6]
CronCreate name: "maestro-security-vulnerability-scan"     schedule: "0 0 * * *"     command: [see Worker 7]
CronCreate name: "maestro-performance-regression-detect"   schedule: "0 * * * *"     command: [see Worker 8]
CronCreate name: "maestro-api-contract-drift"              schedule: "0 * * * *"     command: [see Worker 9]
CronCreate name: "maestro-test-coverage-monitor"           schedule: "0 * * * *"     command: [see Worker 10]
CronCreate name: "maestro-documentation-staleness"         schedule: "0 9 * * 1"     command: [see Worker 11]
CronCreate name: "maestro-code-complexity-alert"           schedule: "0 * * * *"     command: [see Worker 12]
```

To list registered workers: `CronList`

To remove a worker: `CronDelete name: "maestro-<worker-name>"`

## notes.md Integration

Workers surface findings to the user via `.maestro/notes.md`. The dev-loop reads this file between stories. Notes written by workers use a standard format:

```markdown
## [date] worker: <worker-name>
intent: <regression | security | convention_drift | cleanup | cost_report>
source: background-worker

[finding summary]
```

The dev-loop reads `intent` to decide urgency:
- `regression` — pause before starting the next story
- `security` — pause immediately if a story is in progress
- `convention_drift` — surface at next checkpoint
- `cleanup` — surface at next checkpoint (non-blocking)
- `cost_report` — informational, no action required

## Scheduling Improvements

Beyond fixed cron schedules, the worker system supports event-triggered execution, priority queuing, and automatic health tracking. These improvements reduce unnecessary polling while ensuring critical workers fire at the right moment.

### Event-Triggered Scheduling

In addition to periodic scheduling, workers can trigger on events:

| Trigger | Event | Workers Activated |
|---------|-------|-------------------|
| story_complete | After any story passes QA | test-coverage-monitor, code-complexity-alert |
| milestone_complete | After all stories in milestone done | security-vulnerability-scan, api-contract-drift |
| file_change | Specific file patterns changed | documentation-staleness (when *.md changes) |
| dependency_change | package.json/Cargo.toml modified | dependency-audit |
| error_threshold | 3+ consecutive failures | health-check, convention-drift |

#### Implementation

After each story completes in dev-loop, check triggered workers:

1. Get list of changed files from the story's diff
2. Match against worker trigger patterns
3. Run matching workers in priority order
4. Log results

```bash
# Pseudo-implementation within dev-loop story completion hook
CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)

# Check file_change triggers
if echo "$CHANGED_FILES" | grep -q '\.md$'; then
  trigger_worker "documentation-staleness" "file_change"
fi

# Check dependency_change triggers
if echo "$CHANGED_FILES" | grep -qE 'package\.json|Cargo\.toml|requirements\.txt|pyproject\.toml'; then
  trigger_worker "dependency-audit" "dependency_change"
fi
```

Event triggers fire the worker immediately, independent of its cron schedule. A worker triggered by an event does not reset or skip its next scheduled run.

#### Trigger Registration Format

Workers declare their triggers alongside their schedule:

```yaml
# .maestro/config.yaml
workers:
  security-scan:
    schedule: daily
    priority: critical
    enabled: true
    triggers: [milestone_complete, dependency_change]
  test-coverage-monitor:
    schedule: hourly
    priority: high
    enabled: true
    triggers: [story_complete]
  api-contract-drift:
    schedule: hourly
    priority: high
    enabled: true
    triggers: [milestone_complete, story_complete]
  convention-drift:
    schedule: hourly
    priority: medium
    enabled: true
    triggers: [story_complete, error_threshold]
  documentation-staleness:
    schedule: weekly
    priority: low
    enabled: true
    triggers: [file_change]
  dependency-audit:
    schedule: every-6h
    priority: high
    enabled: true
    triggers: [dependency_change]
  code-complexity-alert:
    schedule: hourly
    priority: medium
    enabled: true
    triggers: [story_complete]
```

### Worker Priority

Workers run in priority order. Higher priority workers execute first when multiple workers are triggered simultaneously:

| Priority | Workers | Rationale |
|----------|---------|-----------|
| CRITICAL | security-vulnerability-scan | Security issues block everything |
| HIGH | test-coverage-monitor, api-contract-drift, dependency-audit | Quality gates |
| MEDIUM | convention-drift, code-complexity-alert, performance-regression-detect | Standards |
| LOW | documentation-staleness, cost-report, memory-decay, stale-worktree-cleanup, health-check | Informational or background hygiene |

If multiple workers trigger simultaneously, run CRITICAL first, then HIGH, then MEDIUM, then LOW. Within the same priority tier, run in the order they were triggered.

#### Priority Execution Example

A milestone completes and three workers trigger:

```
Triggered: security-vulnerability-scan (CRITICAL), api-contract-drift (HIGH), convention-drift (MEDIUM)

Execution order:
  1. security-vulnerability-scan  [CRITICAL]
  2. api-contract-drift           [HIGH]
  3. convention-drift             [MEDIUM]
```

Workers in the same priority tier that both trigger on the same event run sequentially. No parallel execution — each worker completes before the next starts.

### Worker Health

Track per-worker health metrics to detect flaky or broken workers before they silently stop providing value:

```
.maestro/logs/workers/health-status.md
```

#### Health Record Format

```markdown
## worker: security-vulnerability-scan
last_run: 2026-03-18T00:00:00Z
status: active
consecutive_failures: 0
success_rate: 1.00  (12/12 runs)
avg_duration: 4.2s

## worker: convention-drift
last_run: 2026-03-18T14:00:00Z
status: active
consecutive_failures: 0
success_rate: 0.97  (34/35 runs)
avg_duration: 2.1s

## worker: api-contract-drift
last_run: 2026-03-18T11:00:00Z
status: disabled
consecutive_failures: 3
success_rate: 0.72  (18/25 runs)
avg_duration: 3.8s
disabled_at: 2026-03-18T11:00:00Z
disable_reason: 3 consecutive failures
```

#### Automatic Disable on Repeated Failure

If a worker fails 3 consecutive times:

1. Log warning to `.maestro/logs/workers/<worker-name>-failure.log`
2. Update health status to `disabled` in `health-status.md`
3. Alert user at next session start: `[MAESTRO] Worker <name> disabled after 3 consecutive failures. Run /maestro workers enable <name> to re-enable.`
4. Do not run the worker again until explicitly re-enabled

This prevents broken workers from flooding logs and consuming tokens on repeated no-op executions.

#### Re-enabling a Disabled Worker

```
/maestro workers enable api-contract-drift
```

The command:
1. Resets `consecutive_failures` to 0
2. Sets status back to `active`
3. Runs the worker once immediately to confirm it now succeeds
4. If it succeeds: resumes normal schedule
5. If it fails again: re-disables and prompts user to investigate

#### Health Metrics Update

Each worker run updates the health record:

```bash
# After each worker execution
if [ $EXIT_CODE -eq 0 ]; then
  update_health_record "$WORKER_NAME" success "$DURATION"
else
  increment_failure_count "$WORKER_NAME"
  if [ $(get_consecutive_failures "$WORKER_NAME") -ge 3 ]; then
    disable_worker "$WORKER_NAME"
    queue_user_alert "[MAESTRO] Worker $WORKER_NAME disabled after 3 failures"
  fi
fi
```

### Full Configuration Format

The complete `.maestro/config.yaml` worker configuration reference:

```yaml
# .maestro/config.yaml
workers:
  security-scan:
    schedule: daily          # cron alias: daily = "0 0 * * *"
    priority: critical
    enabled: true
    triggers: [milestone_complete, dependency_change]
    max_consecutive_failures: 3
  test-coverage-monitor:
    schedule: hourly         # cron alias: hourly = "0 * * * *"
    priority: high
    enabled: true
    triggers: [story_complete]
    max_consecutive_failures: 3
  api-contract-drift:
    schedule: hourly
    priority: high
    enabled: true
    triggers: [milestone_complete, story_complete]
    max_consecutive_failures: 3
  convention-drift:
    schedule: hourly
    priority: medium
    enabled: true
    triggers: [story_complete, error_threshold]
    max_consecutive_failures: 3
  code-complexity-alert:
    schedule: hourly
    priority: medium
    enabled: true
    triggers: [story_complete]
    max_consecutive_failures: 3
  dependency-audit:
    schedule: every-6h       # cron alias: every-6h = "0 */6 * * *"
    priority: high
    enabled: true
    triggers: [dependency_change]
    max_consecutive_failures: 3
  documentation-staleness:
    schedule: weekly         # cron alias: weekly = "0 9 * * 1"
    priority: low
    enabled: true
    triggers: [file_change]
    max_consecutive_failures: 3
  cost-report:
    schedule: "0 18 * * 1-5"
    priority: low
    enabled: true
    triggers: []
    max_consecutive_failures: 3
  health-check:
    schedule: "*/30 * * * *"
    priority: low
    enabled: true
    triggers: [error_threshold]
    max_consecutive_failures: 3
  performance-regression-detect:
    schedule: hourly
    priority: medium
    enabled: true
    triggers: [milestone_complete]
    max_consecutive_failures: 3
  memory-decay:
    schedule: daily
    priority: low
    enabled: true
    triggers: []
    max_consecutive_failures: 3
  stale-worktree-cleanup:
    schedule: hourly
    priority: low
    enabled: true
    triggers: []
    max_consecutive_failures: 3
```

Cron schedule aliases:

| Alias | Cron Expression | Runs |
|-------|----------------|------|
| `daily` | `0 0 * * *` | Midnight every day |
| `hourly` | `0 * * * *` | Top of every hour |
| `every-6h` | `0 */6 * * *` | Every 6 hours |
| `weekly` | `0 9 * * 1` | Monday at 9am |
| `every-30m` | `*/30 * * * *` | Every 30 minutes |

## Integration Points

| Skill | Integration |
|-------|-------------|
| **scheduler** | Workers are registered via the same CronCreate interface. background-workers defines the 12 Maestro-specific workers; scheduler manages the generic scheduling infrastructure. |
| **memory** | Worker 4 (memory-decay) calls the same decay logic defined in the memory skill. |
| **learning-loop** | Convention drift findings (Worker 3) and complexity alerts (Worker 12) are injected as `self_heal` signals in the learning loop's RETRIEVE phase when the next milestone runs. |
| **dev-loop** | Workers write to `.maestro/notes.md`. dev-loop reads notes between stories and pauses for high-urgency findings. dev-loop also fires event triggers (story_complete, milestone_complete) after QA passes. |
| **token-ledger** | Worker 6 (cost-report) reads token actuals from the token-ledger skill. |
| **auto-init** | auto-init calls this skill's registration block during project initialization to activate all 12 workers. |
| **baselines** | Workers 8, 9, and 10 read and write baseline snapshots to `.maestro/baselines/` for delta comparison. |
