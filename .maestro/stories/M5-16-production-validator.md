# S16: Production Validator

**Milestone:** M5 — Ruflo Feature Adoption
**Priority:** High
**Effort:** Small

## Tasks
- [ ] 1.1 Create `skills/production-validator/SKILL.md` — mock/stub detection gate
- [ ] 1.2 Scan for patterns: mock/fake/stub prefixes, TODO/FIXME comments, unimplemented throws, placeholder data
- [ ] 1.3 Check for: console.log/print debugging, hardcoded test credentials, in-memory databases
- [ ] 1.4 Run as pre-ship hook — block /maestro ship if validator fails
- [ ] 1.5 Create `scripts/production-validate.sh` for command-line validation
- [ ] 1.6 Integrate with ship skill — validator runs before PR creation
- [ ] 1.7 Mirror to plugins/maestro/
