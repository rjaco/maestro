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

# Parse active status
active=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null | grep '^active:' | head -1 | sed 's/active:[[:space:]]*//' | xargs 2>/dev/null || echo "false")

if [[ "$active" != "true" ]]; then
  exit 0
fi

# Parse feature and phase
feature=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null | grep '^feature:' | head -1 | sed 's/feature:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | xargs 2>/dev/null || echo "")
phase=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null | grep '^phase:' | head -1 | sed 's/phase:[[:space:]]*//' | xargs 2>/dev/null || echo "")

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
