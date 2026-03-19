#!/usr/bin/env bash
set -euo pipefail
# Maestro WorktreeRemove Hook
# Error handler — log but never block
_hook_error_handler() {
  local exit_code=$?
  local line_no=$1
  local hook_name
  hook_name="$(basename "${BASH_SOURCE[0]}")"
  local log_dir="${MAESTRO_LOG_DIR:-.maestro/logs}"
  mkdir -p "$log_dir" 2>/dev/null || true
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: ${hook_name}:${line_no} exited with code ${exit_code}" >> "$log_dir/hooks.log" 2>/dev/null || true
}
trap '_hook_error_handler $LINENO' ERR
# Runs when a worktree is removed. Logs the removal.
# Reads JSON from stdin: {"worktree_path": "/path/to/worktree"}

HOOK_INPUT=""
if [[ ! -t 0 ]]; then HOOK_INPUT=$(cat 2>/dev/null || true); fi

WORKTREE_PATH=""
if [[ -n "$HOOK_INPUT" ]]; then
  WORKTREE_PATH=$(printf '%s' "$HOOK_INPUT" | grep -o '"worktree_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"worktree_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || true)
fi

mkdir -p .maestro/logs
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WorktreeRemove: ${WORKTREE_PATH:-unknown}" >> .maestro/logs/worktree.log

exit 0
