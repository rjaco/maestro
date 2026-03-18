#!/usr/bin/env bash
# Maestro Branch Guard Hook (PreToolUse)
# Prevents direct commits and pushes to main branch.
# All work happens on 'development' branch. Main is only updated via launch/release.
#
# Install in hooks.json under "PreToolUse":
#   { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/branch-guard.sh" }

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat)
fi

# Extract tool name from hook input
TOOL_NAME=""
if [[ -n "$HOOK_INPUT" ]]; then
  TOOL_NAME=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)
fi

# Only intercept Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
  printf '{"decision":"approve"}\n'
  exit 0
fi

# Extract the command being run
COMMAND=""
if [[ -n "$HOOK_INPUT" ]]; then
  COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
fi

# Check for dangerous git operations on main
BLOCKED=false
REASON=""

# Block: git push to main/origin main
if echo "$COMMAND" | grep -qE 'git\s+push.*\b(main|origin\s+main)\b'; then
  # Allow if it's creating a tag (release)
  if ! echo "$COMMAND" | grep -qE 'git\s+push.*--tags'; then
    BLOCKED=true
    REASON="Direct push to main is blocked. Work on 'development' branch. Use /maestro ship to merge to main when ready to launch."
  fi
fi

# Block: git commit on main branch (check current branch)
if echo "$COMMAND" | grep -qE 'git\s+commit'; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    BLOCKED=true
    REASON="Cannot commit directly to main. Switch to 'development': git checkout development"
  fi
fi

# Block: git checkout main (warn, don't block)
# We allow checkout but the commit guard above prevents damage

# Block: git merge into main
if echo "$COMMAND" | grep -qE 'git\s+merge.*\bmain\b'; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
  if [[ "$CURRENT_BRANCH" == "main" ]]; then
    BLOCKED=true
    REASON="Cannot merge into main directly. Use 'development' branch for all work. Merge to main only via /maestro ship."
  fi
fi

if [[ "$BLOCKED" == "true" ]]; then
  printf '{"decision":"block","reason":"%s"}\n' "$REASON"
else
  printf '{"decision":"approve"}\n'
fi

exit 0
