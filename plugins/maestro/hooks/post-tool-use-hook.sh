#!/usr/bin/env bash
set -euo pipefail

# Maestro PostToolUse Hook
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
# Warns when context usage approaches limits.
# Reads hook input from stdin, checks context_tokens field.

HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat 2>/dev/null || true)
fi

# Extract context token usage from hook input if available
CONTEXT_USED=""
CONTEXT_MAX=""
if [[ -n "$HOOK_INPUT" ]]; then
  CONTEXT_USED=$(printf '%s' "$HOOK_INPUT" | jq -r '.context_tokens_used // empty' 2>/dev/null || true)
  CONTEXT_MAX=$(printf '%s' "$HOOK_INPUT" | jq -r '.context_tokens_max // empty' 2>/dev/null || true)
fi

# If we have both values, calculate percentage
if [[ -n "$CONTEXT_USED" && -n "$CONTEXT_MAX" && "$CONTEXT_MAX" -gt 0 ]] 2>/dev/null; then
  PCT=$(( CONTEXT_USED * 100 / CONTEXT_MAX ))

  if [[ "$PCT" -ge 90 ]]; then
    echo "[MAESTRO] WARNING: Context usage at ${PCT}% (${CONTEXT_USED}/${CONTEXT_MAX} tokens). Compaction imminent." >&2
    echo "  → Consider: /compact or checkpoint your current work" >&2
  elif [[ "$PCT" -ge 70 ]]; then
    echo "[MAESTRO] Context usage at ${PCT}% (${CONTEXT_USED}/${CONTEXT_MAX} tokens)." >&2
  fi
fi

exit 0
