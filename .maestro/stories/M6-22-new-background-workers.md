---
id: M6-22
slug: new-background-workers
title: "6 new background workers — security, perf, API, coverage, docs, complexity"
type: feature
depends_on: []
parallel_safe: true
complexity: high
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/background-workers/SKILL.md` with 6 new worker definitions (expand by 150+ lines)
2. New workers:
   - **security-vulnerability-scan**: Check dependencies for known CVEs (npm audit, pip-audit, cargo audit)
   - **performance-regression-detect**: Compare benchmark results before/after changes
   - **api-contract-drift**: Detect API endpoint changes that break backward compatibility
   - **test-coverage-monitor**: Track test coverage trends, alert on drops > 5%
   - **documentation-staleness**: Detect docs that reference outdated code (functions/files that changed)
   - **code-complexity-alert**: Track cyclomatic complexity, alert on functions > threshold
3. Each worker has:
   - Detection command (bash one-liner that checks for the condition)
   - Alert format (consistent with existing workers)
   - Schedule recommendation (how often to run)
   - Severity level (info/warning/critical)
4. Worker scheduling integrates with existing CronCreate-based system
5. All workers log to `.maestro/logs/workers/`
6. Mirror: skill in both root and plugins/maestro/

## Context for Implementer

Read the current `skills/background-workers/SKILL.md` first. It defines 6 existing workers. Add 6 more following the same pattern.

Each worker definition should include:
- Name and purpose
- Detection command (what to check)
- Threshold (when to alert)
- Schedule (how often: every 30min, hourly, daily)
- Alert format
- Recovery suggestion (what to do when alert fires)

The workers are defined as skill specifications. The actual scheduling is done via CronCreate tool when the user enables them. The skill just defines WHAT each worker checks and HOW.

Reference: skills/background-workers/SKILL.md (existing 6 workers)
Reference: skills/watch/SKILL.md for monitoring patterns
Reference: skills/health-score/SKILL.md for health metric patterns
