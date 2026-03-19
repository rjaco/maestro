#!/usr/bin/env bash
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

exit 0
