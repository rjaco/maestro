# W7-M2: Quality & Testing

## Scope
Add validation infrastructure so Maestro can catch broken configs before users do.

## Stories
- S7: scripts/validate-hooks.sh — verify every hooks.json entry points to executable script
- S8: Update doctor.md to call claude plugin validate
- S9: Create tests/ directory with smoke tests for core skills
- S10: Prompt-type Stop hook — use Haiku to verify task completion

## Acceptance Criteria
1. validate-hooks.sh exits non-zero if any hook script is missing or non-executable
2. /maestro doctor runs claude plugin validate
3. tests/ has at least 5 smoke tests
4. Prompt-type Stop hook evaluates completion state via LLM judgment
