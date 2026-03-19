# W8-M1: Agent Hardening & Functional Tests

## Scope
Add safety frontmatter to agents (maxTurns, disallowedTools) and build functional tests that validate hooks with mock JSON stdin.

## Stories
- S1: Add maxTurns + disallowedTools frontmatter to all agents
- S2: tests/hook-test.sh — functional tests for all hooks via mock JSON stdin

## Acceptance Criteria
1. All 6 agents have maxTurns set (implementer: 50, qa-reviewer: 10, proactive: 5, etc.)
2. Risky tools (Write, Bash) excluded from qa-reviewer via disallowedTools
3. hook-test.sh tests each hook with known-good and known-bad payloads
4. All hooks pass functional tests
