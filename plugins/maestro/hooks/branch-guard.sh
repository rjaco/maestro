#!/usr/bin/env bash
# Maestro Branch Guard Hook (PreToolUse)
# Prevents direct commits and pushes to main branch.
# All work happens on 'development' branch or 'maestro/*' instance branches.
# Main is only updated via launch/release.
#
# Install in hooks.json under "PreToolUse":
#   { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/branch-guard.sh" }

set -euo pipefail

# Error handler — log but never block (fail-open: approve on error)
_hook_error_handler() {
  local exit_code=$?
  local line_no=$1
  local hook_name
  hook_name="$(basename "${BASH_SOURCE[0]}")"
  local log_dir="${MAESTRO_LOG_DIR:-.maestro/logs}"
  mkdir -p "$log_dir" 2>/dev/null || true
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: ${hook_name}:${line_no} exited with code ${exit_code}" >> "$log_dir/hooks.log" 2>/dev/null || true
  # Fail-open: approve on error so broken hook doesn't block user
  printf '{"decision":"approve","reason":"hook error fallback"}\n'
  exit 0
}
trap '_hook_error_handler $LINENO' ERR

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat)
fi

# Extract tool name from hook input
TOOL_NAME=""
if [[ -n "$HOOK_INPUT" ]]; then
  TOOL_NAME=$(printf '%s' "$HOOK_INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || true)
fi

# Only intercept Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  printf '{"decision":"approve"}\n'
  exit 0
fi

# Extract the command being run
COMMAND=""
if [[ -n "$HOOK_INPUT" ]]; then
  COMMAND=$(printf '%s' "$HOOK_INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || true)
fi

# Check for dangerous git operations on main
BLOCKED=false
REASON=""

# Block: git push to main/origin main
if echo "$COMMAND" | grep -qE 'git\s+push.*\b(main|origin\s+main)\b'; then
  # Allow if it's creating a tag (release)
  if ! echo "$COMMAND" | grep -qE 'git\s+push.*--tags'; then
    BLOCKED=true
    REASON="[MAESTRO] Direct push to main is blocked."
    REASON="$REASON Cause: main is a protected branch — it only receives changes via /maestro ship at release time."
    REASON="$REASON Fix: switch to the development branch with 'git checkout development' and push there instead."
  fi
fi

# Block: git commit on main branch (check current branch)
# Allowed branches: development, maestro/* (parallel instance branches)
if echo "$COMMAND" | grep -qE 'git\s+commit'; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    BLOCKED=true
    REASON="[MAESTRO] Cannot commit directly to main."
    REASON="$REASON Cause: main is a protected branch — all development work must happen on 'development' or a 'maestro/*' instance branch."
    REASON="$REASON Fix: run 'git checkout development' to switch branches, then commit there."
  elif [[ "$CURRENT_BRANCH" != "development" ]] && ! echo "$CURRENT_BRANCH" | grep -qE '^maestro/'; then
    BLOCKED=true
    REASON="[MAESTRO] Cannot commit on branch '$CURRENT_BRANCH'."
    REASON="$REASON Cause: commits are only allowed on 'development' or 'maestro/*' instance branches."
    REASON="$REASON Fix: switch to 'development' or your assigned 'maestro/{session_id}/{story_slug}' branch."
  fi
fi

# Block: git checkout main (warn, don't block)
# We allow checkout but the commit guard above prevents damage

# Block: git merge into main
if echo "$COMMAND" | grep -qE 'git\s+merge.*\bmain\b'; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    BLOCKED=true
    REASON="[MAESTRO] Cannot merge into main directly."
    REASON="$REASON Cause: main is a protected branch — merges are managed by Maestro's release process to ensure quality gates pass."
    REASON="$REASON Fix: work on 'development' and use '/maestro ship' when ready to promote to main."
  fi
fi

if [[ "$BLOCKED" == "true" ]]; then
  jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
else
  printf '{"decision":"approve"}\n'
fi

exit 0
