# S17: Enhanced Background Workers

**Milestone:** M5 — Ruflo Feature Adoption
**Priority:** Medium
**Effort:** Medium

## Tasks
- [ ] 1.1 Update `skills/background-workers/SKILL.md` — expand from 6 to 12 workers
- [ ] 1.2 New workers: security-vulnerability-scan, performance-regression-detect, api-contract-drift, test-coverage-monitor, documentation-staleness, code-complexity-alert
- [ ] 1.3 Add priority levels: critical (1h), high (2h), normal (4h), low (8h)
- [ ] 1.4 Add smart scheduling: critical workers run first, skip low-priority if budget tight
- [ ] 1.5 Workers log to `.maestro/logs/workers/{worker-name}.log`
- [ ] 1.6 Mirror to plugins/maestro/
