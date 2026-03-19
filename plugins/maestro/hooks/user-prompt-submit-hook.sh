#!/usr/bin/env bash
# Maestro UserPromptSubmit Hook
# Fires on every user prompt. Injects Maestro context (phase, milestone, story)
# into the prompt context so Claude always knows the Maestro state.

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

# No state file? Nothing to inject.
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse active status
ACTIVE=$(grep -m1 "^active:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "false")
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# Extract key state
FEATURE=$(grep -m1 "^feature:" "$STATE_FILE" 2>/dev/null | sed 's/^feature:[[:space:]]*//' || echo "")
PHASE=$(grep -m1 "^phase:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "")
MILESTONE=$(grep -m1 "^current_milestone:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "")
STORY=$(grep -m1 "^current_story:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "")

# Inject as additional context (shows in Claude's system prompt)
echo "[Maestro] Active: ${FEATURE} | Phase: ${PHASE} | M${MILESTONE} S${STORY}"
