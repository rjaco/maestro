# W8-M2: Parallel Daemon & Worktree Hooks

## Scope
Enable opus-daemon.sh to spawn multiple Claude instances in parallel, each working on a different story in its own worktree. Add WorktreeCreate/Remove hooks for env bootstrap.

## Stories
- S3: WorktreeCreate + WorktreeRemove hooks (env bootstrap + cleanup)
- S4: --parallel N flag in opus-daemon.sh using claude --worktree + file-based claiming
- S5: SubagentStart + PostToolUseFailure hooks (observability)

## Acceptance Criteria
1. WorktreeCreate hook runs env setup (copies .env, installs deps if package.json exists)
2. WorktreeRemove hook cleans up temp files
3. opus-daemon.sh --parallel 3 spawns 3 claude processes working on different stories
4. File-based claiming prevents duplicate work (bash noclobber)
5. SubagentStart logs agent ID to instances directory
