#!/usr/bin/env bash
# Maestro SessionEnd Hook
# Fires when a Claude session ends. Cleans up temp files and logs summary.

set -euo pipefail

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

STATE_FILE=".maestro/state.local.md"

# Clean up temp files
rm -f .maestro/locks/*.lock 2>/dev/null || true

# --- Worktree Cleanup on Session End ---
# Prune detached worktrees when session stops
git worktree prune 2>/dev/null || true

# Log session end
if [[ -f "$STATE_FILE" ]]; then
  mkdir -p .maestro/logs
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  FEATURE=$(grep -m1 "^feature:" "$STATE_FILE" 2>/dev/null | sed 's/^feature:[[:space:]]*//' || echo "unknown")
  echo "${TIMESTAMP} SessionEnd: ${FEATURE}" >> .maestro/logs/sessions.log
fi

exit 0
