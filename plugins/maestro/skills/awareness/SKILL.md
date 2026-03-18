---
name: awareness
description: "Heartbeat-style proactive monitoring. Periodic awareness checks for quality, dependencies, conventions, and tech debt. Surfaces issues without being asked."
---

# Awareness (Heartbeat Monitoring)

OpenClaw-inspired heartbeat system that periodically checks project health beyond simple test execution. Identifies patterns, trends, and emerging issues that standard quality gates miss.

## Awareness Checks

Run every 30 minutes (configurable) via CronCreate or `/loop`:

### 1. Quality Gates (standard)
```bash
tsc --noEmit 2>&1 | tail -20
npm run lint 2>&1 | tail -20
npm test 2>&1 | tail -20
```
Compare against last health check. Flag new failures.

### 2. Dependency Security Audit
```bash
npm audit --json 2>/dev/null | head -100
```
Flag: critical/high severity vulnerabilities, newly discovered since last check.

### 3. Convention Review
- Read last 5 commits: `git log --oneline -5 --format="%h %s"`
- Check commit messages follow project conventions (from DNA)
- Check for files that don't match naming patterns
- Flag: convention violations in recent work

### 4. Coverage Trends
```bash
npm test -- --coverage --reporter=json 2>/dev/null | tail -50
```
Track: line coverage, branch coverage, function coverage.
Flag: coverage decreased since last check.

### 5. Tech Debt Scan (optional)
- Count TODO/FIXME/HACK comments: `grep -rn 'TODO\|FIXME\|HACK' src/ | wc -l`
- Track count over time
- Flag: tech debt growing faster than resolved

## Awareness Report

Output to `.maestro/logs/awareness-{date}-{time}.md`:

```markdown
# Awareness Report — {date} {time}

## Summary
- Quality gates: [pass/fail]
- Dependencies: [N] vulnerabilities ([critical/high])
- Conventions: [N] violations in recent commits
- Coverage: [N]% (trend: [up/down/stable])
- Tech debt: [N] items (trend: [up/down/stable])

## Findings
[detailed findings with file:line references]

## Recommendations
[actionable suggestions based on findings]
```

## Alert Thresholds

| Check | Info | Warning | Alert |
|-------|------|---------|-------|
| Quality gates | All passing | New warnings | Tests/tsc failing |
| Dependencies | No issues | Low/medium vulns | Critical/high vulns |
| Conventions | Compliant | Minor deviations | Pattern violations |
| Coverage | Stable/increasing | Slight decrease | >5% decrease |
| Tech debt | Stable | Growing slowly | Growing fast |

Only notify on Warning and Alert levels. Info is logged but not pushed.

## Configuration

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

## Integration

- Uses CronCreate for scheduling
- Pushes alerts via notify skill (if configured)
- Adds critical findings to `.maestro/notes.md` (picked up by dev-loop)
- Feeds into daily briefing (brain skill)
- Proactive agent can be dispatched for deeper analysis on Warning/Alert
