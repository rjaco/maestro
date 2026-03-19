---
name: background-workers
description: "6 autonomous background workers that run on schedule without user prompts: health-check, dependency-audit, convention-drift, memory-decay, stale-worktree-cleanup, and cost-report. All workers log to .maestro/logs/workers/ and only run when Maestro is initialized."
---

# Background Workers

Six autonomous workers that run on a schedule without requiring user interaction. Each worker is a lightweight read-only agent that monitors project health, logs results, and surfaces issues for the next interactive session.

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

## Log Directory Structure

```
.maestro/logs/workers/
  health-2026-03-18.log
  dependency-audit-2026-03-18.log
  convention-drift-2026-03-18.log
  memory-decay-2026-03-18.log
  stale-worktree-2026-03-18.log
  cost-report-2026-03-18.log
```

Log files are append-only. Each run appends a timestamped block. Files rotate daily (one file per worker per day).

## Registering All Workers

To register all workers at once, run the following setup (typically called by `/maestro init` or `auto-init`):

```
CronCreate name: "maestro-health-check"         schedule: "*/30 * * * *"  command: [see Worker 1]
CronCreate name: "maestro-dependency-audit"     schedule: "0 */6 * * *"   command: [see Worker 2]
CronCreate name: "maestro-convention-drift"     schedule: "0 * * * *"     command: [see Worker 3]
CronCreate name: "maestro-memory-decay"         schedule: "0 0 * * *"     command: [see Worker 4]
CronCreate name: "maestro-stale-worktree-cleanup" schedule: "0 * * * *"   command: [see Worker 5]
CronCreate name: "maestro-cost-report"          schedule: "0 18 * * 1-5"  command: [see Worker 6]
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

## Integration Points

| Skill | Integration |
|-------|-------------|
| **scheduler** | Workers are registered via the same CronCreate interface. background-workers defines the 6 Maestro-specific workers; scheduler manages the generic scheduling infrastructure. |
| **memory** | Worker 4 (memory-decay) calls the same decay logic defined in the memory skill. |
| **learning-loop** | Convention drift findings (Worker 3) are injected as `self_heal` signals in the learning loop's RETRIEVE phase when the next milestone runs. |
| **dev-loop** | Workers write to `.maestro/notes.md`. dev-loop reads notes between stories and pauses for high-urgency findings. |
| **token-ledger** | Worker 6 (cost-report) reads token actuals from the token-ledger skill. |
| **auto-init** | auto-init calls this skill's registration block during project initialization to activate all 6 workers. |
