#!/usr/bin/env bash
<<<<<<< HEAD
# Maestro StopFailure Hook
# Fires when a Claude session stops due to an API or runtime error.
# Reads JSON from stdin: { "error": "...", "error_type": "...", "session_id": "..." }
# Logs the failure and backs up state.

set -euo pipefail

LOG_DIR=".maestro/logs"
STATE_FILE=".maestro/state.local.md"
NOTIFY_SCRIPT="scripts/notify.sh"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read JSON input from stdin (non-blocking: skip if none)
hook_input=""
if [[ ! -t 0 ]]; then
  hook_input=$(cat 2>/dev/null || true)
fi

# Extract a JSON string field by key (simple grep/sed, handles common cases)
json_get() {
  local key="$1"
  local json="$2"
  printf '%s' "$json" \
    | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed "s/\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\"/\1/" \
    || true
}

# Parse fields with jq if available, fallback to grep-based parsing
if command -v jq &>/dev/null && [[ -n "$hook_input" ]]; then
  error_msg=$(printf '%s' "$hook_input" | jq -r '.error // "unknown error"' 2>/dev/null || echo "unknown error")
  error_type=$(printf '%s' "$hook_input" | jq -r '.error_type // "unknown"' 2>/dev/null || echo "unknown")
  session_id=$(printf '%s' "$hook_input" | jq -r '.session_id // ""' 2>/dev/null || echo "")
elif [[ -n "$hook_input" ]]; then
  error_msg=$(json_get "error" "$hook_input")
  error_type=$(json_get "error_type" "$hook_input")
  session_id=$(json_get "session_id" "$hook_input")
  : "${error_msg:=unknown error}"
  : "${error_type:=unknown}"
else
  error_msg="unknown error"
  error_type="unknown"
  session_id=""
fi

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%S")

# Log the failure
LOG_FILE="${LOG_DIR}/stop-failures.log"
printf '[%s] error_type=%s session_id=%s error=%s\n' \
  "$TIMESTAMP" "$error_type" "$session_id" "$error_msg" >> "$LOG_FILE"

# Send notification if notify script exists
if [[ -x "$NOTIFY_SCRIPT" ]]; then
  "$NOTIFY_SCRIPT" --event error --message "API error: ${error_type}" 2>/dev/null || true
fi

# Back up state file if it exists
if [[ -f "$STATE_FILE" ]]; then
  SAFE_TS=$(date +"%Y%m%dT%H%M%S")
  BACKUP_FILE="${LOG_DIR}/state-backup-${SAFE_TS}.md"
  cp "$STATE_FILE" "$BACKUP_FILE" 2>/dev/null || true
fi

# StopFailure hook is informational — no output required
=======
# Maestro Stop Failure Hook
# Fires when a hook or tool fails with an error.
# Logs the failure to .maestro/failure.log for diagnostics.
# Always exits 0 (non-blocking).

set -euo pipefail

LOG_FILE=".maestro/failure.log"
LOG_DIR=".maestro"

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat)
fi

# Ensure log directory exists
if [[ ! -d "$LOG_DIR" ]]; then
  mkdir -p "$LOG_DIR"
fi

# Extract error details
ERROR=""
ERROR_TYPE=""
if [[ -n "$HOOK_INPUT" ]]; then
  ERROR=$(printf '%s' "$HOOK_INPUT" | grep -o '"error":"[^"]*"' | sed 's/"error":"//;s/"//' 2>/dev/null || true)
  ERROR_TYPE=$(printf '%s' "$HOOK_INPUT" | grep -o '"error_type":"[^"]*"' | sed 's/"error_type":"//;s/"//' 2>/dev/null || true)
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")

# Log to file
printf '[%s] error=%s type=%s\n' "$TIMESTAMP" "${ERROR:-unknown}" "${ERROR_TYPE:-unknown}" >> "$LOG_FILE"

# Log to stderr for visibility
printf 'Maestro: stop-failure logged: error=%s type=%s\n' "${ERROR:-unknown}" "${ERROR_TYPE:-unknown}" >&2

>>>>>>> worktree-agent-ab0f24c1
exit 0
