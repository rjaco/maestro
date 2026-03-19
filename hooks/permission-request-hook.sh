#!/usr/bin/env bash
# Maestro PermissionRequest Hook
# Auto-approves safe Maestro read-only and housekeeping operations.
# For everything else: outputs nothing (pass-through to user's own settings).

set -euo pipefail

# Read JSON input from stdin
hook_input=""
if [[ ! -t 0 ]]; then
  hook_input=$(cat 2>/dev/null || true)
fi

if [[ -z "$hook_input" ]]; then
  exit 0
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

# Parse tool name
if command -v jq &>/dev/null; then
  tool_name=$(printf '%s' "$hook_input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
  bash_command=$(printf '%s' "$hook_input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
else
  tool_name=$(json_get "tool_name" "$hook_input")
  # For nested .tool_input.command we use a two-step extraction:
  # first isolate the tool_input block, then get command from it
  tool_input_block=$(printf '%s' "$hook_input" \
    | grep -o '"tool_input"[[:space:]]*:[[:space:]]*{[^}]*}' \
    | head -1 || true)
  bash_command=$(json_get "command" "$tool_input_block")
fi

# Always-safe tools (read-only by nature)
case "$tool_name" in
  Read|Glob|Grep)
    printf '{"decision":"approve"}\n'
    exit 0
    ;;
esac

# Bash tool: approve specific safe Maestro commands
if [[ "$tool_name" == "Bash" ]]; then
  case "$bash_command" in
    "mkdir -p .maestro"*|\
    "cat .maestro"*|\
    "ls .maestro"*|\
    "date"*)
      printf '{"decision":"approve"}\n'
      exit 0
      ;;
  esac
fi

# Everything else: pass-through (output nothing, let user's settings decide)
exit 0
