#!/usr/bin/env bash
# Maestro Session Lock
# Prevents multiple Maestro sessions from running concurrently on the same project.
# Uses PID file locking (inspired by ClaudeClaw's lock pattern).
#
# Usage:
#   ./scripts/session-lock.sh acquire   # Acquire lock (kills stale)
#   ./scripts/session-lock.sh release   # Release lock
#   ./scripts/session-lock.sh check     # Check if locked
#   ./scripts/session-lock.sh force     # Force acquire (kill existing)

set -euo pipefail

LOCK_DIR=".maestro"
LOCK_FILE="${LOCK_DIR}/session.pid"
ACTION="${1:-check}"

acquire_lock() {
  local force="${1:-false}"

  mkdir -p "$LOCK_DIR"

  if [[ -f "$LOCK_FILE" ]]; then
    local existing_pid
    existing_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")

    if [[ -n "$existing_pid" ]]; then
      # Check if process is still alive
      if kill -0 "$existing_pid" 2>/dev/null; then
        if [[ "$force" == "true" ]]; then
          echo "⚠️  Killing existing Maestro session (PID: $existing_pid)"
          kill "$existing_pid" 2>/dev/null || true
          sleep 1
        else
          echo "❌ Maestro session already running (PID: $existing_pid)"
          echo "   Use 'force' to kill it, or 'release' to clear a stale lock."
          exit 1
        fi
      else
        echo "⚠️  Stale lock found (PID: $existing_pid not running). Overwriting."
      fi
    fi
  fi

  # Write our PID
  echo "$$" > "$LOCK_FILE"
  echo "✅ Lock acquired (PID: $$)"
}

release_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    rm -f "$LOCK_FILE"
    echo "✅ Lock released"
  else
    echo "ℹ️  No lock file found"
  fi
}

check_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    local pid
    pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "🔒 Locked by PID: $pid"
      exit 0
    else
      echo "⚠️  Stale lock (PID: ${pid:-unknown} not running)"
      exit 2
    fi
  else
    echo "🔓 No active lock"
    exit 0
  fi
}

case "$ACTION" in
  acquire) acquire_lock false ;;
  force)   acquire_lock true ;;
  release) release_lock ;;
  check)   check_lock ;;
  *)
    echo "Usage: $0 {acquire|release|check|force}"
    exit 1
    ;;
esac
