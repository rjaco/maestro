---
name: ci-watch
description: "Monitor CI/CD pipelines (GitHub Actions, GitLab CI) during and after builds. Alert on failures, wait for completion, integrate with ship workflow."
---

# CI Watch

Monitor CI/CD pipelines in real-time during and after builds. Polls GitHub Actions (or GitLab CI) for status changes, alerts on failures, parses error logs, and suggests fixes. Designed to close the feedback loop between shipping code and knowing it works.

## When to Use

- After `ship` skill creates a PR — automatically watch the triggered CI run
- Manual invocation: `/maestro ci-watch` to check current pipeline status
- Periodic health checks via `awareness` skill integration
- When waiting for a specific workflow run to complete before proceeding

## Platform Detection

Detect the CI platform from the repository:

```bash
# GitHub Actions
ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null

# GitLab CI
ls .gitlab-ci.yml 2>/dev/null
```

If both exist, default to GitHub Actions. If neither exists, report:
```
┌─────────────────────────────────────────────┐
│  CI Watch: No CI configuration detected     │
│                                             │
│  Expected:                                  │
│    .github/workflows/*.yml (GitHub Actions) │
│    .gitlab-ci.yml          (GitLab CI)      │
│                                             │
│  Tip: Use /maestro ci-watch --setup to      │
│  generate a starter workflow.               │
└─────────────────────────────────────────────┘
```

## Operations

### list — Show Recent Runs

List the most recent workflow runs for the current repository:

```bash
gh run list --limit 10 --json databaseId,displayTitle,status,conclusion,headBranch,createdAt
```

Display as a formatted table:

```
┌─────────────────────────────────────────────────────────────────────┐
│  CI Runs — myorg/myrepo                                            │
├──────┬──────────────────────────────────┬──────────┬───────────────┤
│  ID  │  Title                           │  Status  │  Branch       │
├──────┼──────────────────────────────────┼──────────┼───────────────┤
│  ✓   │  CI / test-suite                 │  passed  │  feat/dash    │
│  ✓   │  CI / lint                       │  passed  │  feat/dash    │
│  ✗   │  CI / e2e-tests                  │  failed  │  feat/dash    │
│  ◷   │  CI / deploy-preview             │  running │  feat/dash    │
│  ✓   │  CI / test-suite                 │  passed  │  main         │
└──────┴──────────────────────────────────┴──────────┴───────────────┘
```

Indicators:
- `✓` — passed (conclusion: success)
- `✗` — failed (conclusion: failure)
- `◷` — in progress (status: in_progress)
- `⊘` — cancelled (conclusion: cancelled)
- `⊖` — skipped (conclusion: skipped)

### view — Inspect a Specific Run

```bash
gh run view RUN_ID --json jobs,status,conclusion,name
```

Show job-level detail:

```
┌─────────────────────────────────────────────────────────┐
│  Run #4827 — CI Pipeline                                │
│  Branch: feat/dashboard  |  Triggered: 3m ago           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Jobs:                                                  │
│    ✓  lint           passed    (22s)                    │
│    ✓  typecheck      passed    (34s)                    │
│    ✗  test-unit      failed    (1m12s)                  │
│    ⊘  test-e2e       cancelled (skipped, dependency)    │
│    ⊘  deploy         cancelled (skipped, dependency)    │
│                                                         │
│  Overall: FAILED                                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### watch — Wait for Run Completion

Poll a running workflow until it completes:

```bash
gh run watch RUN_ID --exit-status
```

If `--exit-status` returns non-zero, the run failed. Parse the logs.

**Polling behavior:**
- Poll every 15 seconds for the first 2 minutes
- Poll every 30 seconds for minutes 2-10
- Poll every 60 seconds after 10 minutes
- Timeout after 30 minutes (configurable)

**Progress output during watch:**

```
┌───────────────────────────────────────────┐
│  Watching Run #4827...  (elapsed: 1m 34s) │
│                                           │
│    ✓  lint           passed               │
│    ✓  typecheck      passed               │
│    ◷  test-unit      running...           │
│    ·  test-e2e       queued               │
│    ·  deploy         queued               │
└───────────────────────────────────────────┘
```

### logs — Fetch Failure Logs

When a run fails, fetch the logs for the failed job:

```bash
gh run view RUN_ID --log-failed 2>&1 | tail -80
```

Parse the log output to extract:
1. The failing test name or command
2. The error message
3. The file and line number (if available)
4. The stack trace (truncated to last 20 lines)

## Error Recovery: Parse and Suggest Fix

When CI fails, analyze the error logs and suggest a fix:

### Step 1: Classify the Failure

| Failure Type | Detection Pattern | Severity |
|-------------|-------------------|----------|
| Test failure | `FAIL`, `AssertionError`, `Expected.*Received` | High |
| Type error | `error TS`, `Type.*is not assignable` | High |
| Lint error | `eslint`, `warning.*no-unused` | Medium |
| Build error | `Module not found`, `Cannot resolve` | High |
| Timeout | `exceeded timeout`, `ETIMEDOUT` | Medium |
| OOM | `JavaScript heap out of memory` | High |
| Flaky test | Same test passes locally, fails in CI | Low |
| Dependency | `npm ERR!`, `ERESOLVE`, `peer dep` | Medium |

### Step 2: Generate Fix Suggestion

```
┌─────────────────────────────────────────────────────────────┐
│  CI Failure Analysis — Run #4827                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Type: Test failure                                         │
│  Job:  test-unit                                            │
│  File: src/utils/pricing.test.ts:47                         │
│                                                             │
│  Error:                                                     │
│    Expected: 29.99                                          │
│    Received: 30.00                                          │
│                                                             │
│  Suggestion:                                                │
│    Rounding issue in calculateDiscount(). The CI            │
│    environment may use different floating-point             │
│    precision. Use toBeCloseTo() instead of toBe()          │
│    for price assertions.                                    │
│                                                             │
│  Affected file: src/utils/pricing.ts                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Step 3: Offer Actions

Present options via AskUserQuestion:
- Question: "CI run #[ID] failed: [failure type] in [job name]. How should I proceed?"
- Header: "CI Watch"
- Options:
  - "Fix and re-push" — Apply the suggested fix, commit, push
  - "View full logs" — Show the complete failure log
  - "Ignore and continue" — Mark as acknowledged, move on
  - "Re-run workflow" — Trigger a re-run (for flaky tests)

Re-run command:
```bash
gh run rerun RUN_ID --failed
```

## Integration with Ship Skill

After the `ship` skill creates a PR, `ci-watch` is invoked automatically:

1. Ship creates PR via `gh pr create`
2. Extract the PR number from the output
3. Wait 5 seconds for GitHub to trigger workflows
4. Find the triggered run:
   ```bash
   gh run list --branch BRANCH_NAME --limit 1 --json databaseId,status
   ```
5. Begin watching the run
6. On completion:
   - **Passed**: Report success, update `.maestro/state.local.md`
   - **Failed**: Parse logs, suggest fix, ask user

Post-ship CI result:

```
┌──────────────────────────────────────────────┐
│  Ship + CI Summary                           │
├──────────────────────────────────────────────┤
│                                              │
│  PR:  #142 — feat: add dashboard             │
│  CI:  ✓ All checks passed (3m 22s)           │
│                                              │
│  Jobs:                                       │
│    ✓  lint           12s                     │
│    ✓  typecheck      28s                     │
│    ✓  test-unit      1m 44s                  │
│    ✓  test-e2e       2m 58s                  │
│    ✓  deploy-preview 48s                     │
│                                              │
│  Ready for review and merge.                 │
│                                              │
└──────────────────────────────────────────────┘
```

## Integration with Notify Skill

When CI fails and the notify skill is configured, push an alert:

**Event type:** `ci_failure`

```
[Maestro] CI Failed: Run #4827
Job: test-unit | Branch: feat/dashboard
Error: Test failure in pricing.test.ts:47
Action: Fix suggested — awaiting user decision
```

**Event type:** `ci_passed`

```
[Maestro] CI Passed: Run #4827
PR: #142 | Branch: feat/dashboard
All 5 jobs passed in 3m 22s
```

Only send `ci_passed` notifications if the run was previously failing (recovery notification). Do not spam on routine passes.

## Integration with Awareness Skill

The awareness skill can invoke `ci-watch list` during periodic health checks:

1. Fetch the last 5 runs on the default branch (main/master)
2. Check for patterns:
   - Consecutive failures on main (broken pipeline)
   - Increasing run times (performance regression)
   - Flaky tests (same test alternating pass/fail)
3. Report findings in the awareness report under `## CI Health`

```
## CI Health
- Pipeline status: healthy (last 5 runs passed)
- Average run time: 3m 42s (stable, no regression)
- Flaky tests: none detected
```

Or if unhealthy:

```
## CI Health
- Pipeline status: WARNING — 2 of last 5 runs failed on main
- Failing job: test-e2e (flaky: UserAuth.spec.ts)
- Average run time: 5m 12s (up 40% from last week)
- Recommendation: Investigate flaky e2e test, consider retry strategy
```

## Subcommand Patterns

| Command | Description |
|---------|-------------|
| `/maestro ci-watch` | Show latest CI runs (alias for `list`) |
| `/maestro ci-watch list` | List recent workflow runs |
| `/maestro ci-watch view RUN_ID` | Inspect a specific run |
| `/maestro ci-watch watch` | Watch the most recent in-progress run |
| `/maestro ci-watch watch RUN_ID` | Watch a specific run |
| `/maestro ci-watch logs RUN_ID` | Fetch and parse failure logs |
| `/maestro ci-watch health` | CI health summary (last 10 runs) |
| `/maestro ci-watch fix` | Analyze latest failure and suggest fix |

## Configuration

In `.maestro/config.yaml`:

```yaml
ci_watch:
  enabled: true
  platform: auto          # auto | github | gitlab
  poll_interval_s: 15     # initial poll interval
  timeout_minutes: 30     # max time to watch a run
  auto_watch_after_ship: true
  notify_on_failure: true
  notify_on_recovery: true
  parse_logs: true
  max_log_lines: 80
```

## Output Contract

```yaml
output_contract:
  events:
    ci_started:
      fields: [run_id, branch, trigger, workflow_name]
    ci_passed:
      fields: [run_id, branch, duration_s, jobs_summary]
    ci_failed:
      fields: [run_id, branch, failed_job, error_type, error_message, suggestion]
    ci_watching:
      fields: [run_id, elapsed_s, jobs_status]
  display:
    format: box-drawing
    indicators: [pass, fail, running, queued, cancelled, skipped]
```

## Error Handling

| Situation | Action |
|-----------|--------|
| `gh` CLI not installed | Log warning, skip CI watch, suggest `brew install gh` |
| `gh` not authenticated | Log warning, suggest `gh auth login` |
| No workflows found | Report "no CI configuration detected" |
| Run not found | Report "run ID not found", suggest `ci-watch list` |
| Network timeout | Retry once after 5s, then log warning and continue |
| Rate limit hit | Back off to 60s polling, warn user |
| Watch timeout (30m) | PAUSE, report last known status, ask user |

## State Tracking

Track CI run results in `.maestro/logs/ci-watch.log`:

```
[2026-03-18T10:30:00Z] RUN#4827 started  branch=feat/dashboard  workflow=CI
[2026-03-18T10:33:22Z] RUN#4827 passed   duration=202s  jobs=5/5
[2026-03-18T14:15:00Z] RUN#4830 started  branch=feat/dashboard  workflow=CI
[2026-03-18T14:17:45Z] RUN#4830 failed   duration=165s  job=test-unit  error=TestFailure
[2026-03-18T14:20:00Z] RUN#4830 rerun    triggered_by=user
[2026-03-18T14:23:12Z] RUN#4831 passed   duration=192s  jobs=5/5  (recovery)
```
