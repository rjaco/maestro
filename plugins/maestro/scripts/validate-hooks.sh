#!/usr/bin/env bash
# Maestro Hook Validator
# Validates that every entry in hooks.json points to an executable script.
# Exit 0: all checks pass. Exit 1: one or more failures.
#
# Usage: ./scripts/validate-hooks.sh [path/to/hooks.json]

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$SCRIPT_DIR")}"

HOOKS_JSON="${1:-${PROJECT_ROOT}/hooks/hooks.json}"

if [[ ! -f "$HOOKS_JSON" ]]; then
  echo "ERROR: hooks.json not found: $HOOKS_JSON" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse and validate
# ---------------------------------------------------------------------------

fail_count=0
warn_count=0
pass_count=0

echo "Maestro Hook Validator"
echo "======================"

# Iterate over every event type in hooks.json, then every hook group,
# then every individual hook entry with "type": "command".
#
# jq query produces tab-separated lines: EventName<TAB>command_path
while IFS=$'\t' read -r event_name raw_command; do
  # Replace ${CLAUDE_PLUGIN_ROOT} with the actual project root
  # shellcheck disable=SC2001
  command_path="$(echo "$raw_command" | sed "s|\${CLAUDE_PLUGIN_ROOT}|${PROJECT_ROOT}|g")"

  # Strip the project root prefix for display purposes
  display_path="${command_path#"${PROJECT_ROOT}/"}"

  if [[ ! -f "$command_path" ]]; then
    echo "[FAIL] ${event_name} → ${display_path} (file not found)"
    fail_count=$((fail_count + 1))
  elif [[ ! -x "$command_path" ]]; then
    echo "[WARN] ${event_name} → ${display_path} (exists, not executable)"
    warn_count=$((warn_count + 1))
  else
    echo "[PASS] ${event_name} → ${display_path} (exists, executable)"
    pass_count=$((pass_count + 1))
  fi
done < <(
  jq -r '
    .hooks
    | to_entries[]
    | .key as $event
    | .value[]
    | .hooks[]
    | select(.type == "command")
    | [$event, .command]
    | @tsv
  ' "$HOOKS_JSON"
)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""

total=$((pass_count + fail_count + warn_count))

if [[ "$total" -eq 0 ]]; then
  echo "Result: no hook entries found in ${HOOKS_JSON}."
elif [[ "$fail_count" -eq 0 && "$warn_count" -eq 0 ]]; then
  echo "Result: all ${pass_count} hook(s) OK."
elif [[ "$fail_count" -eq 0 ]]; then
  echo "Result: ${warn_count} WARN. Review before deploying."
else
  parts=()
  [[ "$fail_count" -gt 0 ]] && parts+=("${fail_count} FAIL")
  [[ "$warn_count" -gt 0 ]] && parts+=("${warn_count} WARN")
  result_str="$(IFS=', '; echo "${parts[*]}")"
  echo "Result: ${result_str}. Fix before deploying."
fi

# Exit 1 only when there are FAILs (missing files).
# WARNs (not executable) are non-fatal.
[[ "$fail_count" -eq 0 ]]
