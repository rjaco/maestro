# M2: Multi-Instance Coordination

## Scope
Enable multiple Maestro instances to work simultaneously on the same repository without conflicts. Each instance claims stories, works in its own branch/worktree, and merges back to development with automatic conflict resolution.

## Architecture
```
Instance A (opus-daemon)          Instance B (opus-daemon)
    │                                 │
    ├─ claims M1-S1, M1-S2           ├─ claims M1-S3, M1-S4
    ├─ works in worktree-A           ├─ works in worktree-B
    ├─ merges to development ────────┤─ waits for merge lock
    │                                 ├─ rebases on latest development
    │                                 ├─ resolves conflicts if any
    │                                 └─ merges to development
    └─ next story
```

## Acceptance Criteria
1. Each Maestro instance writes a registration file to `.maestro/instances/`
2. Instance registration includes: session_id, PID, started_at, current_story, branch
3. Before claiming a story, check if another instance already claimed it
4. Dead instances (stale heartbeat > 10 min) are cleaned up
5. Merge conflicts are detected before push and resolved via rebase
6. Branch guard allows feature branches (not just development)

## Stories
- S5: Instance registry with lock files
- S6: Branch manager with per-instance branches
- S7: Merge coordinator with conflict resolution
