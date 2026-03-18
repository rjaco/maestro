#!/usr/bin/env bash
# Maestro Notification Hook
# Fires when Claude needs user input during an active Maestro session.
# Can trigger desktop notifications to bring attention back.

set -euo pipefail

STATE_FILE=".maestro/state.local.md"

# No state file? Not a Maestro session.
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse frontmatter
frontmatter=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || true)

yaml_val() {
  local key="$1"
  local line
  line=$(printf '%s\n' "$frontmatter" | grep -E "^${key}:" | head -1)
  [[ -z "$line" ]] && echo "" && return
  local val="${line#*:}"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%\"}" ; val="${val#\"}"
  val="${val%\'}" ; val="${val#\'}"
  printf '%s' "$val"
}

active=$(yaml_val "active")

if [[ "$active" != "true" ]]; then
  exit 0
fi

feature=$(yaml_val "feature")
phase=$(yaml_val "phase")

# Only notify on checkpoint/paused phases (when user action is needed)
case "$phase" in
  checkpoint|paused)
    # Try desktop notification
    TITLE="Maestro needs your input"
    BODY="${feature:-Active session} — ${phase}"

    # macOS
    if command -v osascript &>/dev/null; then
      osascript -e "display notification \"$BODY\" with title \"$TITLE\"" 2>/dev/null || true
    fi

    # Linux (notify-send)
    if command -v notify-send &>/dev/null; then
      notify-send "$TITLE" "$BODY" 2>/dev/null || true
    fi
    ;;
esac
