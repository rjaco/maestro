#!/usr/bin/env bash
# Maestro Opus Daemon v2.0 — Smart Orchestrator Above Claude Code
#
# Runs "above" Claude Code — spawns and coordinates Claude instances,
# manages state, sends notifications, and loops endlessly until the
# vision is achieved. Inspired by OpenClaw's Gateway daemon.
#
# Usage:
#   ./scripts/opus-daemon.sh                        # Start serial loop
#   ./scripts/opus-daemon.sh --parallel 3           # Spawn 3 parallel workers
#   ./scripts/opus-daemon.sh --interval 30          # 30s between iterations
#   ./scripts/opus-daemon.sh --max-iterations 50    # Stop after 50 iterations
#   ./scripts/opus-daemon.sh --stop                 # Gracefully stop
#   ./scripts/opus-daemon.sh --verbose              # Debug output
#   ./scripts/opus-daemon.sh --dry-run              # Show without executing
#
# For full autonomous operation with remote control:
#   ./scripts/remote-listener.sh &   # Telegram bot in background
#   ./scripts/opus-daemon.sh         # Daemon in foreground
#
# Control from Telegram:
#   /status  — check progress
#   /pause   — pause after current story
#   /resume  — resume execution
#   /logs    — view daemon logs
#
# Architecture:
#   Each `claude` invocation is a fresh CLI process. This bypasses the
#   stop_hook_active limitation. The daemon reads state, builds a smart
#   prompt, invokes Claude, detects progress, sends notifications, and
#   loops. In parallel mode, it spawns N workers with file-based claiming.

set -euo pipefail

# ---------------------------------------------------------------------------
# ANSI colors
# ---------------------------------------------------------------------------
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[0;33m'
CLR_RED='\033[0;31m'
CLR_BOLD='\033[1m'
CLR_RESET='\033[0m'

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$PROJECT_DIR/.maestro/state.local.md"
VISION_FILE="$PROJECT_DIR/.maestro/vision.md"
ROADMAP_FILE="$PROJECT_DIR/.maestro/roadmap.md"
LOG_DIR="$PROJECT_DIR/.maestro/logs"
LOG_FILE="$LOG_DIR/daemon.log"
HISTORY_FILE="$LOG_DIR/daemon-history.jsonl"
HEARTBEAT_FILE="$LOG_DIR/heartbeat"
PID_FILE="$PROJECT_DIR/.maestro/opus-daemon.pid"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
INTERVAL=10
MAX_ITERATIONS=0  # 0 = unlimited
ITERATION=0
VERBOSE=false
DRY_RUN=false
STALL_COUNT=0
STALL_THRESHOLD=3
HEARTBEAT_MAX_AGE=300  # seconds (5 minutes)
PARALLEL=0             # 0 = serial mode, N = spawn N parallel workers
MAX_RETRIES=3
RETRY_DELAY=5

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
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --parallel)
      PARALLEL="${2:?--parallel requires a value}"
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
      echo "Usage: $0 [--interval N] [--max-iterations N] [--parallel N] [--stop] [--verbose] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Logging helpers
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

debug() {
  if [[ "$VERBOSE" == "true" ]]; then
    log "[DEBUG] $1"
  fi
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
# Read first N non-frontmatter lines from a markdown file
# ---------------------------------------------------------------------------
read_non_frontmatter_lines() {
  local file="$1"
  local count="${2:-3}"
  awk -v count="$count" '
    /^---$/ { block++; next }
    block == 0 { next }          # skip before first ---
    block == 1 { next }          # skip inside frontmatter
    block >= 2 && /^[[:space:]]*$/ { next }  # skip blank lines
    block >= 2 {
      print
      found++
      if (found >= count) exit
    }
  ' "$file"
}

# ---------------------------------------------------------------------------
# Get current milestone name from roadmap.md
# ---------------------------------------------------------------------------
get_milestone_name() {
  local milestone_num="$1"
  if [[ ! -f "$ROADMAP_FILE" ]]; then
    echo ""
    return
  fi
  # Look for "## M<N>" or "### M<N>" or "**M<N>" style headings
  grep -iE "^#+\s+M${milestone_num}[^0-9]|^#+\s+Milestone\s+${milestone_num}[^0-9]" \
    "$ROADMAP_FILE" 2>/dev/null | head -1 | sed 's/^[#* ]*//' | sed 's/^\*\*//' || echo ""
}

# ---------------------------------------------------------------------------
# Check if heartbeat file is older than HEARTBEAT_MAX_AGE seconds
# Returns 0 (true) if stale, 1 (false) if fresh or non-existent
# ---------------------------------------------------------------------------
heartbeat_is_stale() {
  if [[ ! -f "$HEARTBEAT_FILE" ]]; then
    return 1  # not stale — no heartbeat means daemon just started
  fi
  local file_mtime now age
  file_mtime="$(stat -c '%Y' "$HEARTBEAT_FILE" 2>/dev/null || stat -f '%m' "$HEARTBEAT_FILE" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  age=$(( now - file_mtime ))
  debug "Heartbeat age: ${age}s (max: ${HEARTBEAT_MAX_AGE}s)"
  if [[ "$age" -ge "$HEARTBEAT_MAX_AGE" ]]; then
    return 0  # stale
  fi
  return 1  # fresh
}

# ---------------------------------------------------------------------------
# Kill any orphaned claude processes
# ---------------------------------------------------------------------------
kill_orphaned_claude() {
  local pids
  pids="$(pgrep -x claude 2>/dev/null || pidof claude 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    log "Killing orphaned claude processes: $pids"
    # shellcheck disable=SC2086
    kill -TERM $pids 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Write a JSONL history entry
# ---------------------------------------------------------------------------
write_history_entry() {
  local ts="$1"
  local iteration="$2"
  local milestone="$3"
  local story_progress="$4"
  local exit_code="$5"
  local duration="$6"
  local state_change="$7"

  mkdir -p "$LOG_DIR"
  printf '{"timestamp":"%s","iteration":%d,"milestone":"%s","story":"%s","exit_code":%d,"duration_seconds":%d,"state_change":%s}\n' \
    "$ts" "$iteration" "$milestone" "$story_progress" "$exit_code" "$duration" "$state_change" \
    >> "$HISTORY_FILE"
}

# ---------------------------------------------------------------------------
# Print colored progress summary
# ---------------------------------------------------------------------------
print_summary() {
  local iteration="$1"
  local duration="$2"
  local milestone="$3"
  local total_milestones="$4"
  local story="$5"
  local total_stories="$6"
  local exit_code="$7"
  local state_change="$8"

  local color="$CLR_GREEN"
  if [[ "$exit_code" -ne 0 ]]; then
    color="$CLR_RED"
  elif [[ "$state_change" == "false" ]]; then
    color="$CLR_YELLOW"
  fi

  # shellcheck disable=SC2059
  printf "${color}${CLR_BOLD}[Summary]${CLR_RESET} Iteration %d | Duration %ds | Milestone %s/%s | Story %s/%s | Exit code %d\n" \
    "$iteration" "$duration" "$milestone" "$total_milestones" "$story" "$total_stories" "$exit_code"
}

# ---------------------------------------------------------------------------
# Build continuation prompt
# ---------------------------------------------------------------------------
build_prompt() {
  local milestone_num="$1"
  local is_stalled="${2:-false}"

  # Extract vision excerpt (first 3 non-frontmatter lines)
  local vision_excerpt=""
  if [[ -f "$VISION_FILE" ]]; then
    vision_excerpt="$(read_non_frontmatter_lines "$VISION_FILE" 3)"
  fi

  # Get milestone name from roadmap
  local milestone_name=""
  milestone_name="$(get_milestone_name "$milestone_num")"

  local stall_prefix=""
  if [[ "$is_stalled" == "true" ]]; then
    stall_prefix="IMPORTANT: The daemon has detected no progress for multiple iterations. You MUST take concrete action this iteration — advance a story, complete a task, or document a blocker.

"
  fi

  local milestone_line=""
  if [[ -n "$milestone_name" ]]; then
    milestone_line="Current milestone: ${milestone_name}
"
  fi

  local vision_section=""
  if [[ -n "$vision_excerpt" ]]; then
    vision_section="Vision:
${vision_excerpt}

"
  fi

  printf '%sContinue the Maestro Magnum Opus autonomous loop.
%s%sRead .maestro/state.local.md for full state. Read .maestro/stories/ for current stories.
Read .maestro/vision.md for the North Star.
Execute the next story or milestone.
Dispatch implementer agents via Agent tool with isolation: worktree. Do NOT write plan documents.
When all milestones are complete, research new improvements and create new milestones.
This is an INFINITE improvement cycle. Do not stop.' \
    "$stall_prefix" "$vision_section" "$milestone_line"
}

# ---------------------------------------------------------------------------
# Send notification (fire-and-forget)
# ---------------------------------------------------------------------------
send_notification() {
  local event="$1"
  local message="$2"
  if [[ -x "$PROJECT_DIR/scripts/notify.sh" ]]; then
    "$PROJECT_DIR/scripts/notify.sh" --event "$event" --message "$message" 2>/dev/null &
  fi
}

# ---------------------------------------------------------------------------
# Run Claude with retry + exponential backoff
# ---------------------------------------------------------------------------
run_with_retry() {
  local prompt="$1"
  local attempt=0
  local exit_code=0

  while [[ $attempt -lt $MAX_RETRIES ]]; do
    exit_code=0
    claude --continue "$prompt" --yes --model opus || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      return 0
    fi

    attempt=$((attempt + 1))
    if [[ $attempt -lt $MAX_RETRIES ]]; then
      local delay=$((RETRY_DELAY * attempt))
      log "Claude exited with code $exit_code. Retry $attempt/$MAX_RETRIES in ${delay}s..."
      sleep "$delay"
    fi
  done

  log "All $MAX_RETRIES retries failed (last exit code: $exit_code)"
  send_notification "error" "Daemon: $MAX_RETRIES retries failed (exit $exit_code)"
  return "$exit_code"
}

# ---------------------------------------------------------------------------
# Parallel worker: spawn N claude processes for independent stories
# ---------------------------------------------------------------------------
run_parallel_workers() {
  local num_workers="$1"
  local stories_dir="$PROJECT_DIR/.maestro/stories"
  local claim_dir="$PROJECT_DIR/.maestro/locks"
  mkdir -p "$claim_dir"

  local milestone
  milestone="$(parse_state current_milestone)"
  local pids=()
  local worker_names=()
  local claimed=0

  for story_file in "$stories_dir"/M"${milestone}"-*.md; do
    [[ -f "$story_file" ]] || continue
    [[ "$claimed" -ge "$num_workers" ]] && break

    # Skip completed stories
    if grep -qi "Status:.*[Cc]omplete" "$story_file" 2>/dev/null; then
      continue
    fi

    local story_name
    story_name=$(basename "$story_file" .md)
    local claim_file="$claim_dir/${story_name}.lock"

    # Atomic claim using noclobber
    if ( set -C; echo "$$-$claimed" > "$claim_file" ) 2>/dev/null; then
      claimed=$((claimed + 1))
      local worker_id="worker-${claimed}"
      worker_names+=("$story_name")

      log "[$worker_id] Claimed $story_name"

      if [[ "$DRY_RUN" == "true" ]]; then
        log "[dry-run] Would spawn: claude for $story_name"
      else
        local prompt
        prompt="Implement this Maestro story. Read the story file, implement the changes, commit your work, then report DONE.

Story: $story_file
Read the story file for full details.
Read .maestro/vision.md for North Star context.
Commit all changes when done."

        claude -p "$prompt" --yes --model sonnet \
          &> "$LOG_DIR/${worker_id}-${story_name}.log" &
        pids+=($!)
      fi
    fi
  done

  if [[ ${#pids[@]} -gt 0 ]]; then
    log "Waiting for ${#pids[@]} parallel workers..."
    local i=0
    for pid in "${pids[@]}"; do
      wait "$pid" 2>/dev/null || log "Worker ${worker_names[$i]:-$pid} exited with error"
      i=$((i + 1))
    done
    log "All ${#pids[@]} workers finished"
    send_notification "story_complete" "${#pids[@]} parallel workers completed in M${milestone}"
  elif [[ "$claimed" -eq 0 ]]; then
    log "No unclaimed stories for parallel execution"
  fi

  # Cleanup claims
  rm -f "$claim_dir"/M*.lock 2>/dev/null
}

# ---------------------------------------------------------------------------
# Show startup banner
# ---------------------------------------------------------------------------
show_banner() {
  # shellcheck disable=SC2059
  printf "${CLR_BOLD}"
  cat << 'BANNER'
  ╔══════════════════════════════════════╗
  ║     MAESTRO OPUS DAEMON v2.0       ║
  ║   Autonomous Development Engine    ║
  ╚══════════════════════════════════════╝
BANNER
  # shellcheck disable=SC2059
  printf "${CLR_RESET}"
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

show_banner

MODE_DESC="serial"
if [[ "$PARALLEL" -gt 0 ]]; then MODE_DESC="parallel ($PARALLEL workers)"; fi
if [[ "$DRY_RUN" == "true" ]]; then MODE_DESC="$MODE_DESC (dry-run)"; fi

log "Opus Daemon started (PID $$, mode=${MODE_DESC}, interval=${INTERVAL}s, max_iterations=${MAX_ITERATIONS:-unlimited})"
send_notification "session_resume" "Opus Daemon started (${MODE_DESC})"

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

  # Snapshot state before iteration for change detection
  PRE_MILESTONE="$CURRENT_MILESTONE"
  PRE_STORY="$CURRENT_STORY"

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

  # -- Stall detection: check heartbeat before iteration --
  IS_STALLED=false
  if heartbeat_is_stale; then
    debug "Heartbeat is stale (>= ${HEARTBEAT_MAX_AGE}s old)"
    if [[ "$ITERATION" -gt 0 ]]; then
      STALL_COUNT=$(( STALL_COUNT + 1 ))
      log "WARNING: stall detected (count=$STALL_COUNT/${STALL_THRESHOLD}). Heartbeat stale + no state change last iteration."
      if [[ "$STALL_COUNT" -ge "$STALL_THRESHOLD" ]]; then
        log "Stall threshold reached ($STALL_THRESHOLD). Killing orphaned claude processes and using recovery prompt."
        kill_orphaned_claude
        IS_STALLED=true
        STALL_COUNT=0
      fi
    fi
  fi

  # -- Increment counter before call so log lines match --
  ITERATION=$(( ITERATION + 1 ))

  log "Iteration $ITERATION: Starting (M${CURRENT_MILESTONE}/${TOTAL_MILESTONES}, story ${CURRENT_STORY}/${TOTAL_STORIES})"

  # -- Build prompt --
  PROMPT="$(build_prompt "$CURRENT_MILESTONE" "$IS_STALLED")"

  # -- Record start time --
  START_TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  START_EPOCH="$(date +%s)"

  # -- Execute: parallel or serial --
  EXIT_CODE=0
  if [[ "$PARALLEL" -gt 0 ]]; then
    # Parallel mode: spawn N workers for independent stories
    if [[ "$DRY_RUN" == "true" ]]; then
      log "[dry-run] Would spawn $PARALLEL parallel workers"
    else
      run_parallel_workers "$PARALLEL"
    fi
  elif [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] Would call: claude --continue <prompt> --yes --model opus"
    debug "Prompt:"
    debug "$PROMPT"
  else
    # Serial mode with retry
    run_with_retry "$PROMPT" || EXIT_CODE=$?
  fi

  # -- Record end time and duration --
  END_EPOCH="$(date +%s)"
  DURATION=$(( END_EPOCH - START_EPOCH ))

  log "Iteration $ITERATION: Complete (exit code $EXIT_CODE)"

  # -- Detect state change --
  POST_MILESTONE="$(parse_state current_milestone)"
  POST_STORY="$(parse_state current_story)"
  STATE_CHANGED=false
  if [[ "$PRE_MILESTONE" != "$POST_MILESTONE" || "$PRE_STORY" != "$POST_STORY" ]]; then
    STATE_CHANGED=true
    STALL_COUNT=0
    debug "State changed: M${PRE_MILESTONE}->M${POST_MILESTONE}, story ${PRE_STORY}->${POST_STORY}"
  fi

  # -- Write JSONL history entry --
  write_history_entry \
    "$START_TS" \
    "$ITERATION" \
    "${CURRENT_MILESTONE}/${TOTAL_MILESTONES}" \
    "${CURRENT_STORY}/${TOTAL_STORIES}" \
    "$EXIT_CODE" \
    "$DURATION" \
    "$STATE_CHANGED"

  # -- Print colored progress summary --
  print_summary \
    "$ITERATION" \
    "$DURATION" \
    "$CURRENT_MILESTONE" \
    "$TOTAL_MILESTONES" \
    "$CURRENT_STORY" \
    "$TOTAL_STORIES" \
    "$EXIT_CODE" \
    "$STATE_CHANGED"

  # -- Notify on milestone change --
  if [[ "$STATE_CHANGED" == "true" ]] && [[ "$PRE_MILESTONE" != "$POST_MILESTONE" ]]; then
    send_notification "milestone_complete" "Milestone M${PRE_MILESTONE} complete. Now on M${POST_MILESTONE}."
  fi

  # -- Brief pause between iterations --
  sleep "$INTERVAL"
done

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -f "$PID_FILE"
log "Opus Daemon stopped (ran $ITERATION iterations)."
send_notification "session_paused" "Opus Daemon stopped after $ITERATION iterations."
