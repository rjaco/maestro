#!/usr/bin/env bash
# Maestro PreCompact Hook
# Fires before Claude compacts its context window.
# Snapshots state and roadmap so they survive compaction.

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

LOG_DIR=".maestro/logs"
STATE_FILE=".maestro/state.local.md"
ROADMAP_FILE=".maestro/roadmap.md"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

SAFE_TS=$(date +"%Y%m%dT%H%M%S")

# Check if state file exists and is active
if [[ ! -f "$STATE_FILE" ]]; then
  # Nothing to snapshot
  exit 0
fi

# Check active flag in frontmatter
active=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null \
  | grep '^active:' | head -1 \
  | sed 's/active:[[:space:]]*//' | xargs 2>/dev/null || echo "false")

if [[ "$active" == "true" ]]; then
  # Snapshot state
  STATE_BACKUP="${LOG_DIR}/pre-compact-state-${SAFE_TS}.md"
  cp "$STATE_FILE" "$STATE_BACKUP" 2>/dev/null || true
  echo "[MAESTRO] Pre-compact state snapshot saved: ${STATE_BACKUP}" >&2
fi

# Always snapshot roadmap if it exists (regardless of active status)
if [[ -f "$ROADMAP_FILE" ]]; then
  ROADMAP_BACKUP="${LOG_DIR}/pre-compact-roadmap-${SAFE_TS}.md"
  cp "$ROADMAP_FILE" "$ROADMAP_BACKUP" 2>/dev/null || true
fi

exit 0
