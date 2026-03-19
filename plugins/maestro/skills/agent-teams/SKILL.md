---
name: agent-teams
description: "Native Claude Code Agent Teams integration. Coordinates within-story parallelism via native teams and cross-story orchestration via Maestro."
---

# Agent Teams

Maestro integrates with Claude Code's native Agent Teams for parallel execution. This skill defines when to use native teams vs. Maestro orchestration, and how they work together.

## Native Claude Code Agent Teams

Claude Code v2.1.32+ supports native agent teams via:
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### Integration with Maestro

Maestro's existing hooks integrate automatically:
- `TeammateIdle` hook → triggers story reassignment
- `TaskCompleted` hook → updates .maestro/state.local.md

### When to Use Native vs Maestro Teams

| Scenario | Use Native | Use Maestro |
|----------|-----------|-------------|
| 2-3 agents on shared task | ✓ | |
| 5+ agents across milestones | | ✓ |
| Need file-level locking | ✓ | |
| Need story-level orchestration | | ✓ |
| tmux split-pane visualization | ✓ | |
| Telegram progress reporting | | ✓ |

### Enabling Both

Set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in your environment.
Maestro will use native teams for within-story parallelism and
its own orchestration for cross-story coordination.
