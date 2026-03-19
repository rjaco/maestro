---
id: M2-05
slug: consensus-mechanisms
title: "Consensus mechanisms for multi-agent decision quality"
type: feature
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. New skill `skills/consensus/SKILL.md` exists (150+ lines)
2. Implements 3 consensus patterns:
   - **Weighted voting**: Multiple agents vote on a decision, weighted by role (reviewer=3x, implementer=1x)
   - **Quorum check**: Decision only proceeds when N of M agents agree (configurable threshold)
   - **Conflict resolution**: When agents disagree, escalate to higher-tier model or human
3. Skill integrates with existing multi-review skill (dispatches N reviewers, collects votes)
4. Documents when to use each consensus pattern (code review, architecture decisions, merge decisions)
5. Includes decision logging — every consensus decision logged with votes and rationale
6. Mirror: skill exists in both root and plugins/maestro/skills/

## Context for Implementer

Ruflo uses Raft consensus, BFT voting, and weighted consensus for multi-agent coordination. Maestro's equivalent should be simpler — we don't need distributed systems consensus, we need decision-quality consensus:

- When 3 review agents disagree on a PR, how do we decide? Weighted voting.
- When an architecture decision is contentious, how do we validate? Quorum.
- When human and agent disagree, who wins? Claims system (separate story).

The skill should define:
1. A consensus protocol interface (input: list of agent votes, output: decision + confidence)
2. Three protocol implementations
3. Integration points with existing skills (multi-review, decompose, QA)

Reference: skills/multi-review/SKILL.md for current multi-agent review pattern
Reference: skills/delegation/SKILL.md for agent dispatch patterns
