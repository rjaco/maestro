#!/usr/bin/env bash
# Maestro Notification Hook
# Fires when Claude needs user input during an active Maestro session.
# Triggers desktop notifications and forwards key events to scripts/notify.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="${PROJECT_DIR}/.maestro/state.local.md"
NOTIFY_SCRIPT="${PROJECT_DIR}/scripts/notify.sh"

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

# Only act on checkpoint/paused phases (when user action is needed)
case "$phase" in
  checkpoint|paused)
    TITLE="Maestro needs your input"
    BODY="${feature:-Active session} — ${phase}"

    # ── Desktop notifications ─────────────────────────────────────────────────

    # macOS
    if command -v osascript &>/dev/null; then
      osascript -e "display notification \"$BODY\" with title \"$TITLE\"" 2>/dev/null || true
    fi

    # Linux (notify-send)
    if command -v notify-send &>/dev/null; then
      notify-send "$TITLE" "$BODY" 2>/dev/null || true
    fi

    # ── Remote notifications via notify.sh ────────────────────────────────────

    if [[ -x "$NOTIFY_SCRIPT" ]]; then
      case "$phase" in
        paused)
          EVENT="session_paused"
          ;;
        checkpoint)
          EVENT="story_complete"
          ;;
        *)
          EVENT="$phase"
          ;;
      esac

      # Fire-and-forget — never block Claude Code's hook pipeline
      "${NOTIFY_SCRIPT}" \
        --event "$EVENT" \
        --message "${TITLE}: ${BODY}" 2>/dev/null || true
    fi
    ;;
esac
