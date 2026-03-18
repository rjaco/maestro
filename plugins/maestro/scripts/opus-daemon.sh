#!/usr/bin/env bash
# Maestro Opus Daemon — External loop driver for 24/7 Magnum Opus operation
#
# Usage:
#   ./scripts/opus-daemon.sh                        # Start loop (reads .maestro/state.local.md)
#   ./scripts/opus-daemon.sh --interval 30          # Wait 30s between iterations (default: 10)
#   ./scripts/opus-daemon.sh --max-iterations 50    # Stop after 50 iterations (default: unlimited)
#   ./scripts/opus-daemon.sh --stop                 # Gracefully stop by setting active: false
#
# How it works:
#   1. Reads .maestro/state.local.md to check if an Opus session is active
#   2. Calls `claude --continue "Continue the Magnum Opus loop..."`
#   3. Waits for Claude to finish
#   4. Checks state again — if still active, loops back to step 2
#   5. If active: false or phase: completed/paused/aborted, exits
#
# This is the same pattern OpenClaw uses for always-on operation.
# It works because each `claude` invocation is a fresh CLI process,
# bypassing the stop_hook_active limitation.

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$PROJECT_DIR/.maestro/state.local.md"
LOG_DIR="$PROJECT_DIR/.maestro/logs"
LOG_FILE="$LOG_DIR/daemon.log"
PID_FILE="$PROJECT_DIR/.maestro/opus-daemon.pid"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
INTERVAL=10
MAX_ITERATIONS=0  # 0 = unlimited
ITERATION=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      INTERVAL="${2:?--interval requires a value}"
      shift 2
      ;;
    --max-iterations)
      MAX_ITERATIONS="${2:?--max-iterations requires a value}"
      shift 2
      ;;
    --stop)
      # Gracefully stop a running daemon by flipping active: false in state
      if [[ ! -f "$STATE_FILE" ]]; then
        echo "No state file found at $STATE_FILE — nothing to stop."
        exit 0
      fi
      # Replace 'active: true' -> 'active: false' in frontmatter
      sed -i 's/^active: true$/active: false/' "$STATE_FILE"
      echo "Daemon stop requested: active set to false in $STATE_FILE"
      # Also signal the running daemon if PID file exists
      if [[ -f "$PID_FILE" ]]; then
        local_pid="$(cat "$PID_FILE")"
        if kill -0 "$local_pid" 2>/dev/null; then
          kill -TERM "$local_pid"
          echo "SIGTERM sent to daemon PID $local_pid"
        else
          echo "PID $local_pid is not running. Stale PID file removed."
          rm -f "$PID_FILE"
        fi
      fi
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--interval N] [--max-iterations N] [--stop]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Logging helper
# ---------------------------------------------------------------------------
log() {
  local msg="$1"
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local line="[$ts] $msg"
  echo "$line"
  mkdir -p "$LOG_DIR"
  echo "$line" >> "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# YAML frontmatter parser (reads key: value from between --- delimiters)
# ---------------------------------------------------------------------------
parse_state() {
  local key="$1"
  # Extract value for a given key from the YAML frontmatter block
  awk -v key="$key" '
    /^---$/ { block++; next }
    block == 1 && /^[a-z_]+:/ {
      # Match "key: value"
      split($0, parts, ": ")
      if (parts[1] == key) {
        # Strip surrounding quotes if present
        val = parts[2]
        gsub(/^"/, "", val)
        gsub(/"$/, "", val)
        print val
        exit
      }
    }
    block >= 2 { exit }
  ' "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# State mutator — replaces a scalar frontmatter value in-place
# Only works for simple key: value lines (not nested YAML)
# ---------------------------------------------------------------------------
set_state() {
  local key="$1"
  local value="$2"
  sed -i "s|^${key}: .*$|${key}: ${value}|" "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# Signal handler — graceful shutdown on SIGTERM/SIGINT
# ---------------------------------------------------------------------------
cleanup() {
  log "Daemon received stop signal. Setting phase: paused."
  if [[ -f "$STATE_FILE" ]]; then
    set_state "phase" "paused"
  fi
  rm -f "$PID_FILE"
  exit 0
}
trap cleanup SIGTERM SIGINT

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: State file not found: $STATE_FILE" >&2
  echo "Run Magnum Opus first to create an active session." >&2
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Write PID file
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$PID_FILE")"
echo "$$" > "$PID_FILE"

log "Opus Daemon started (PID $$, interval=${INTERVAL}s, max_iterations=${MAX_ITERATIONS:-unlimited})"

# ---------------------------------------------------------------------------
# The continuation prompt injected on every iteration
# ---------------------------------------------------------------------------
PROMPT="Continue the Maestro Magnum Opus autonomous loop.
Read .maestro/state.local.md for current state.
Read .maestro/vision.md for the North Star.
Execute the next story or milestone.
When all milestones are complete, research new improvements and create new milestones.
This is an INFINITE improvement cycle. Do not stop."

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
while true; do
  # -- Guard: max iterations --
  if [[ "$MAX_ITERATIONS" -gt 0 && "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
    log "Max iterations ($MAX_ITERATIONS) reached. Daemon exiting."
    break
  fi

  # -- Read current state --
  if [[ ! -f "$STATE_FILE" ]]; then
    log "State file disappeared. Daemon exiting."
    break
  fi

  ACTIVE="$(parse_state active)"
  PHASE="$(parse_state phase)"
  CURRENT_MILESTONE="$(parse_state current_milestone)"
  TOTAL_MILESTONES="$(parse_state total_milestones)"
  CURRENT_STORY="$(parse_state current_story)"
  TOTAL_STORIES="$(parse_state total_stories)"
  CONSECUTIVE_FAILURES="$(parse_state consecutive_failures)"
  MAX_CONSECUTIVE_FAILURES="$(parse_state max_consecutive_failures)"

  # -- Safety: active flag --
  if [[ "$ACTIVE" != "true" ]]; then
    log "active: false — Daemon exiting gracefully."
    break
  fi

  # -- Safety: phase check --
  case "$PHASE" in
    paused|completed|aborted)
      log "Phase is '$PHASE' — Daemon exiting gracefully."
      break
      ;;
  esac

  # -- Safety: consecutive failures --
  if [[ -n "$CONSECUTIVE_FAILURES" && -n "$MAX_CONSECUTIVE_FAILURES" ]] \
      && [[ "$MAX_CONSECUTIVE_FAILURES" -gt 0 ]] \
      && [[ "$CONSECUTIVE_FAILURES" -ge "$MAX_CONSECUTIVE_FAILURES" ]]; then
    log "consecutive_failures ($CONSECUTIVE_FAILURES) >= max ($MAX_CONSECUTIVE_FAILURES). Daemon exiting."
    break
  fi

  # -- Increment counter before call so log lines match --
  ITERATION=$(( ITERATION + 1 ))

  log "Iteration $ITERATION: Starting (M${CURRENT_MILESTONE}/${TOTAL_MILESTONES}, story ${CURRENT_STORY}/${TOTAL_STORIES})"

  # -- Invoke Claude CLI --
  EXIT_CODE=0
  claude --continue "$PROMPT" --yes --model opus || EXIT_CODE=$?

  log "Iteration $ITERATION: Complete (exit code $EXIT_CODE)"

  # -- Brief pause between iterations --
  sleep "$INTERVAL"
done

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -f "$PID_FILE"
log "Opus Daemon stopped (ran $ITERATION iterations)."
