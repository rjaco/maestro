#!/usr/bin/env bash
set -euo pipefail
# Maestro WorktreeCreate Hook
# Runs when Claude Code creates a new worktree. Bootstraps the environment.
# Reads JSON from stdin: {"worktree_path": "/path/to/worktree", "branch": "name"}

HOOK_INPUT=""
if [[ ! -t 0 ]]; then HOOK_INPUT=$(cat 2>/dev/null || true); fi

WORKTREE_PATH=""
if [[ -n "$HOOK_INPUT" ]]; then
  WORKTREE_PATH=$(printf '%s' "$HOOK_INPUT" | grep -o '"worktree_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"worktree_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || true)
fi

[[ -z "$WORKTREE_PATH" ]] && exit 0

# Copy .env if it exists in project root
PROJECT_ROOT="$(pwd)"
if [[ -f "$PROJECT_ROOT/.env" ]] && [[ ! -f "$WORKTREE_PATH/.env" ]]; then
  cp "$PROJECT_ROOT/.env" "$WORKTREE_PATH/.env"
  echo "[MAESTRO] Copied .env to worktree" >&2
fi

# If package.json exists, install deps
if [[ -f "$WORKTREE_PATH/package.json" ]] && [[ ! -d "$WORKTREE_PATH/node_modules" ]]; then
  echo "[MAESTRO] Installing dependencies in worktree..." >&2
  (cd "$WORKTREE_PATH" && npm install --silent 2>/dev/null) &
fi

# Log the worktree creation
mkdir -p .maestro/logs
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WorktreeCreate: $WORKTREE_PATH" >> .maestro/logs/worktree.log

exit 0
