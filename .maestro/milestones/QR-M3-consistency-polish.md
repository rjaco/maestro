# QR-M3: Consistency & Polish

## Focus
Standardize formats, clean up orphaned files, expand minimal content, verify mirror sync.

## Stories

### S8: Standardize command allowed-tools format
- Convert all inline space-separated allowed-tools to YAML array format
- Verify all 43 commands use consistent frontmatter
- Acceptance: All commands use array format for allowed-tools

### S9: Clean up orphaned files and worktrees
- Remove leftover worktree directories in .claude/worktrees/
- Remove or archive temp/ directory contents
- Clean any other orphaned artifacts
- Acceptance: No orphaned temp files or abandoned worktrees

### S10: Expand minimal agent definitions and verify completeness
- Expand fixer.md from 2 lines to proper agent specification
- Add consistent fields across all agents (background, isolation where appropriate)
- Verify all agents have complete, well-specified definitions
- Sync all changes to plugins/maestro/ mirror
- Acceptance: All 6 agents have comprehensive definitions, mirror synced
