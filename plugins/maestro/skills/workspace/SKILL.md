---
name: workspace
description: "Isolate Maestro sessions by workspace. Support multiple projects, team collaboration, and safe experimentation with separate .maestro/ contexts."
---

# Workspace

Isolate Maestro sessions into named workspaces, each with its own `.maestro/` context: state, stories, config, trust, token ledger, and memory. Enables safe experimentation, parallel features, and team collaboration without cross-contamination.

## Core Concept

A workspace is a complete, self-contained `.maestro/` environment. Each workspace has:

```
.maestro/workspaces/{name}/
  ├── config.yaml         # Workspace-specific config overrides
  ├── dna.md              # Inherited from root (symlink or copy)
  ├── state.md            # Persistent state for this workspace
  ├── state.local.md      # Local execution state
  ├── trust.yaml          # Trust level (independent per workspace)
  ├── token-ledger.md     # Cost tracking scoped to workspace
  ├── notes.md            # User notes for this workspace
  ├── memory/
  │   └── semantic.md     # Workspace-specific memories
  ├── stories/
  │   └── *.md            # Stories for this workspace's features
  └── logs/
      └── *.md            # Awareness, notifications, CI logs
```

## Default Workspace

When no workspace is explicitly selected, Maestro uses the **root workspace**: the project's top-level `.maestro/` directory. This is the default behavior — existing projects work without any workspace configuration.

The root workspace is identified as `default`:

```
┌────────────────────────────────────┐
│  Active Workspace: default         │
│  Path: .maestro/                   │
│  Stories: 7 (3 done, 1 active)     │
│  Cost: $4.20                       │
└────────────────────────────────────┘
```

## Operations

### create NAME — Create a New Workspace

Create a new isolated workspace with its own `.maestro/` context:

```bash
mkdir -p .maestro/workspaces/{NAME}/stories
mkdir -p .maestro/workspaces/{NAME}/memory
mkdir -p .maestro/workspaces/{NAME}/logs
```

Initialize workspace files:

1. **config.yaml** — Copy from root `.maestro/config.yaml` with workspace-specific overrides section
2. **dna.md** — Symlink to root `.maestro/dna.md` (project DNA is shared, not duplicated)
3. **state.md** — Empty initial state
4. **state.local.md** — Empty (`.gitignore`d)
5. **trust.yaml** — Start at `novice` trust level (independent of root workspace)
6. **token-ledger.md** — Empty ledger header
7. **notes.md** — Empty

Output on creation:

```
┌──────────────────────────────────────────────────────┐
│  Workspace Created: experiment-v2                    │
├──────────────────────────────────────────────────────┤
│                                                      │
│  Path:    .maestro/workspaces/experiment-v2/         │
│  Branch:  (not linked — use --branch to link)        │
│  DNA:     symlinked from root                        │
│  Trust:   novice (fresh start)                       │
│  Config:  inherited from root                        │
│                                                      │
│  Switch to it:  /maestro workspace switch             │
│                 experiment-v2                         │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**With branch linking:**

```
/maestro workspace create experiment-v2 --branch feat/experiment-v2
```

This records the git branch association in the workspace's `config.yaml`:

```yaml
workspace:
  name: experiment-v2
  branch: feat/experiment-v2
  created_at: "2026-03-18T10:00:00Z"
```

### switch NAME — Set Active Workspace

Switch the active workspace. All subsequent Maestro operations use this workspace's context.

**How switching works:**
1. Write the active workspace name to `.maestro/active-workspace`:
   ```
   experiment-v2
   ```
2. All Maestro skills read `.maestro/active-workspace` to resolve paths
3. If the file does not exist or contains `default`, use root `.maestro/`

Path resolution after switch:
- `.maestro/stories/` resolves to `.maestro/workspaces/experiment-v2/stories/`
- `.maestro/state.md` resolves to `.maestro/workspaces/experiment-v2/state.md`
- `.maestro/dna.md` resolves to root `.maestro/dna.md` (always shared)
- `.maestro/config.yaml` merges root config with workspace overrides

Output on switch:

```
┌──────────────────────────────────────────────────────┐
│  Switched to: experiment-v2                          │
├──────────────────────────────────────────────────────┤
│                                                      │
│  Stories: 0 (empty workspace)                        │
│  Trust:   novice                                     │
│  Cost:    $0.00                                      │
│  Branch:  feat/experiment-v2                          │
│                                                      │
│  Previous: default (3/7 stories done)                │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Branch auto-switch:** If the workspace has a linked branch and the current git branch differs, ask the user:

- Question: "Workspace 'experiment-v2' is linked to branch 'feat/experiment-v2' but you are on 'main'. Switch git branch too?"
- Header: "Workspace"
- Options:
  - "Yes, switch branch" — Run `git checkout feat/experiment-v2`
  - "No, stay on current branch" — Just switch Maestro context
  - "Unlink branch" — Remove the branch association

### list — Show All Workspaces

Display all workspaces with their status:

```
┌───────────────────────────────────────────────────────────────────────┐
│  Workspaces                                                          │
├──────────────────┬──────────┬──────────┬──────────┬─────────────────┤
│  Name            │  Stories │  Trust   │  Cost    │  Branch         │
├──────────────────┼──────────┼──────────┼──────────┼─────────────────┤
│  ● default       │  3/7     │  expert  │  $12.40  │  main           │
│    experiment-v2  │  0/0     │  novice  │  $0.00   │  feat/exp-v2    │
│    refactor-auth  │  5/5     │  journey │  $8.75   │  refactor/auth  │
│    mobile-ui      │  2/4     │  apprent │  $3.20   │  feat/mobile    │
└──────────────────┴──────────┴──────────┴──────────┴─────────────────┘

● = active workspace
```

Implementation:

```bash
# List workspace directories
ls -d .maestro/workspaces/*/

# Read each workspace's state to build the table
# Read .maestro/active-workspace for the active indicator
```

### delete NAME — Remove a Workspace

Delete a workspace and all its state. Requires confirmation.

**Safety checks:**
1. Cannot delete `default` workspace
2. Cannot delete the currently active workspace (must switch first)
3. If the workspace has in-progress stories, warn before deleting

Confirmation via AskUserQuestion:
- Question: "Delete workspace '[NAME]'? This removes all stories, state, trust history, and logs for this workspace. This action cannot be undone."
- Header: "Workspace"
- Options:
  - "Delete permanently" — Remove the workspace directory
  - "Cancel" — Abort deletion

On confirmed deletion:

```bash
rm -rf .maestro/workspaces/{NAME}/
```

```
┌──────────────────────────────────────────┐
│  Workspace Deleted: experiment-v2        │
│                                          │
│  Removed:                                │
│    - 0 stories                           │
│    - $0.00 tracked spend                 │
│    - All logs and state                  │
│                                          │
│  Git branch feat/experiment-v2 was NOT   │
│  deleted. Remove manually if desired.    │
│                                          │
└──────────────────────────────────────────┘
```

### status — Show Active Workspace Detail

Display detailed information about the currently active workspace:

```
┌──────────────────────────────────────────────────────────────────┐
│  Workspace: experiment-v2                                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Created:    2026-03-18T10:00:00Z                                │
│  Branch:     feat/experiment-v2                                   │
│  Trust:      novice (2 commits scored)                           │
│  Total cost: $1.45                                               │
│                                                                  │
│  Stories:                                                        │
│    ✓  01-setup-schema       DONE                                 │
│    ◷  02-api-routes         IN_PROGRESS                          │
│    ·  03-frontend           PENDING                              │
│    ·  04-tests              PENDING                              │
│                                                                  │
│  Last activity: 14 minutes ago                                   │
│  Notes: 1 unread note in notes.md                                │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Use Case: Experiment with Different Approaches

A developer wants to try two different approaches to the same feature:

```
/maestro workspace create approach-a --branch feat/search-elastic
/maestro workspace switch approach-a
/maestro decompose "Full-text search with Elasticsearch"
/maestro dev-loop --mode checkpoint

# Try a different approach
/maestro workspace create approach-b --branch feat/search-sqlite
/maestro workspace switch approach-b
/maestro decompose "Full-text search with SQLite FTS5"
/maestro dev-loop --mode checkpoint

# Compare results
/maestro workspace list
# Pick the winner, delete the loser
/maestro workspace delete approach-a
```

Each approach has completely isolated state, trust levels, and cost tracking.

## Use Case: Team Collaboration

Multiple team members can work on the same repository with separate workspaces. Since `state.local.md` is `.gitignore`d, workspace directories can be committed:

```
.maestro/workspaces/
  alice-dashboard/    # Alice's feature workspace
  bob-api-refactor/   # Bob's feature workspace
  shared-config/      # Shared workspace for cross-cutting concerns
```

Each team member switches to their own workspace:
```
/maestro workspace switch alice-dashboard
```

## State Isolation

Each workspace maintains completely independent:

| Component | Isolation Level | Notes |
|-----------|----------------|-------|
| `stories/` | Full | Each workspace has its own story backlog |
| `state.md` | Full | Persistent state per workspace |
| `state.local.md` | Full | Local execution state per workspace |
| `trust.yaml` | Full | Trust earned independently |
| `token-ledger.md` | Full | Cost tracked per workspace |
| `notes.md` | Full | User notes scoped to workspace |
| `memory/` | Full | Memories accumulated per workspace |
| `logs/` | Full | Awareness, CI, notification logs |
| `config.yaml` | Merged | Workspace overrides merged with root |
| `dna.md` | Shared | Project DNA is always shared (symlinked) |
| `CLAUDE.md` | Shared | Project rules always apply globally |

### Config Merging

Workspace `config.yaml` overrides root config on a per-key basis:

**Root `.maestro/config.yaml`:**
```yaml
mode: checkpoint
notifications:
  enabled: true
  providers:
    slack:
      webhook_url: "https://hooks.slack.com/..."
```

**Workspace `.maestro/workspaces/experiment-v2/config.yaml`:**
```yaml
workspace:
  name: experiment-v2
  branch: feat/experiment-v2
  created_at: "2026-03-18T10:00:00Z"
mode: yolo    # Override: experiment freely
```

**Effective config:** `mode: yolo`, notifications from root.

## Git Integration

### Branch Mapping

Workspaces can optionally map to git branches:

```yaml
# In workspace config.yaml
workspace:
  name: experiment-v2
  branch: feat/experiment-v2
```

When switching workspaces with a branch mapping:
1. Check if the mapped branch exists locally
2. If yes, offer to `git checkout` to it
3. If no, offer to create it from current HEAD

### Workspace from Branch

Auto-detect workspace from the current git branch:

```bash
CURRENT_BRANCH=$(git branch --show-current)
```

Search all workspace configs for a matching `workspace.branch` value. If found, suggest switching:

```
┌─────────────────────────────────────────────────────┐
│  Branch Detection                                    │
│                                                      │
│  You are on branch: feat/experiment-v2                │
│  Linked workspace:  experiment-v2                     │
│                                                      │
│  Active workspace:  default                           │
│                                                      │
│  Switch to experiment-v2?                             │
└─────────────────────────────────────────────────────┘
```

### Workspace Cleanup

When a branch is merged and deleted, suggest cleaning up the workspace:

```
┌──────────────────────────────────────────────────────┐
│  Workspace Cleanup Suggestion                        │
│                                                      │
│  Branch feat/experiment-v2 has been merged and        │
│  deleted. Workspace 'experiment-v2' is now orphaned. │
│                                                      │
│  Delete workspace 'experiment-v2'?                    │
└──────────────────────────────────────────────────────┘
```

## WorktreeCreate / WorktreeRemove Hook Integration

Claude Code v2.1.69 introduced `WorktreeCreate` and `WorktreeRemove` hooks that fire when git worktrees are created or removed. Since Maestro dispatches agents in worktrees (`isolation: "worktree"`), these hooks enable automatic workspace lifecycle tracking.

### WorktreeCreate — Track Active Worktrees

When a worktree is created (by Maestro's agent dispatch):

1. Log the worktree to `.maestro/logs/worktrees.md`:
   ```
   [timestamp] CREATED worktree: [path] branch: [branch] agent: [agent_id]
   ```
2. If a workspace is branch-linked and the worktree branch matches, record the association
3. Increment `active_worktrees` counter in state

### WorktreeRemove — Cleanup on Worktree Removal

When a worktree is removed (by merge or cleanup):

1. Log the removal:
   ```
   [timestamp] REMOVED worktree: [path] duration: [time since creation]
   ```
2. Decrement `active_worktrees` counter
3. If the worktree was the last one for a workspace's branch, mark workspace as idle

### Orphan Detection

Periodically (via awareness heartbeat), scan for orphaned worktrees — worktrees that exist on disk but have no corresponding active agent:

```bash
git worktree list --porcelain | grep "^worktree " | while read -r _ path; do
  if [[ "$path" == *".claude/worktrees/"* ]]; then
    # Check if agent is still running
    # If not, flag for cleanup
  fi
done
```

## Subcommand Patterns

| Command | Description |
|---------|-------------|
| `/maestro workspace` | Show active workspace status |
| `/maestro workspace list` | List all workspaces |
| `/maestro workspace create NAME` | Create a new workspace |
| `/maestro workspace create NAME --branch BRANCH` | Create workspace linked to git branch |
| `/maestro workspace switch NAME` | Switch active workspace |
| `/maestro workspace delete NAME` | Delete a workspace |
| `/maestro workspace status` | Detailed active workspace info |

## Configuration

In `.maestro/config.yaml`:

```yaml
workspace:
  auto_detect_branch: true   # Auto-suggest workspace switch on branch change
  shared_dna: true           # Symlink dna.md (true) or copy (false)
  cleanup_on_merge: true     # Suggest cleanup when linked branch is merged
  max_workspaces: 10         # Limit total workspaces to prevent sprawl
```

## Output Contract

```yaml
output_contract:
  operations:
    create:
      fields: [name, path, branch, trust_level, created_at]
    switch:
      fields: [name, previous_workspace, stories_summary, branch]
    list:
      fields: [workspaces[].name, workspaces[].stories, workspaces[].trust, workspaces[].cost, workspaces[].branch, active]
    delete:
      fields: [name, stories_removed, cost_tracked]
    status:
      fields: [name, created_at, branch, trust, cost, stories_detail, last_activity]
  display:
    format: box-drawing
    active_indicator: "●"
```

## Error Handling

| Situation | Action |
|-----------|--------|
| Workspace name already exists | Report conflict, suggest alternate name |
| Workspace name contains invalid chars | Reject, allow only `[a-z0-9-]` |
| Workspace not found | Report error, show `workspace list` |
| Delete active workspace | Block, require `switch` first |
| Delete default workspace | Block, report "cannot delete default workspace" |
| Max workspaces exceeded | Block, suggest deleting unused workspaces |
| Branch conflict (two workspaces same branch) | Warn, allow but flag potential confusion |
| Corrupted workspace (missing files) | Attempt repair, recreate missing files from templates |
