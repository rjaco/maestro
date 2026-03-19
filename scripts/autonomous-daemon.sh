#!/usr/bin/env bash
set -euo pipefail

# autonomous-daemon.sh — 24/7 autonomous agent daemon
#
# Polls for commands from messaging channels and file inbox.
# Executes task chains and individual commands via claude CLI.
# Manages PID file, crash recovery, and graceful shutdown.
#
# Usage:
#   ./scripts/autonomous-daemon.sh [start|stop|status|restart]
#
# Environment:
#   MAESTRO_DIR       .maestro directory path (default: .maestro)
#   DAEMON_INTERVAL   Poll interval in seconds (default: 30)
#   DAEMON_LOG_LEVEL  Log verbosity: DEBUG|INFO|WARN|ERROR (default: INFO)

# --- Configuration ---

MAESTRO_DIR="${MAESTRO_DIR:-.maestro}"
PID_FILE="$MAESTRO_DIR/autonomous-daemon.pid"
LOG_FILE="$MAESTRO_DIR/logs/daemon.log"
INBOX_DIR="$MAESTRO_DIR/inbox"
PROCESSED_DIR="$MAESTRO_DIR/inbox/processed"
QUEUE_FILE="$MAESTRO_DIR/task-queue.yaml"
STATE_FILE="$MAESTRO_DIR/daemon-state.yaml"
SPENDING_LOG="$MAESTRO_DIR/spending-log.yaml"
CHAINS_DIR="$MAESTRO_DIR/chains"
INTERVAL="${DAEMON_INTERVAL:-30}"
LOG_LEVEL="${DAEMON_LOG_LEVEL:-INFO}"

# --- Colors (terminal only) ---

if [[ -t 1 ]]; then
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  CYAN='\033[0;36m'
  RESET='\033[0m'
else
  BOLD='' GREEN='' YELLOW='' RED='' CYAN='' RESET=''
fi

# --- Logging ---

log_level_num() {
  case "$1" in
    DEBUG) echo 0 ;;
    INFO)  echo 1 ;;
    WARN)  echo 2 ;;
    ERROR) echo 3 ;;
    *)     echo 1 ;;
  esac
}

log() {
  local level="$1"
  local msg="$2"
  local current_level
  current_level=$(log_level_num "$LOG_LEVEL")
  local msg_level
  msg_level=$(log_level_num "$level")

  if [[ "$msg_level" -ge "$current_level" ]]; then
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local line="[$ts] [$level]    $msg"
    echo "$line" >> "$LOG_FILE"

    # Also print to stdout if running interactively
    if [[ -t 1 ]]; then
      case "$level" in
        DEBUG) printf "${CYAN}[daemon]${RESET} %s\n" "$msg" ;;
        INFO)  printf "${GREEN}[daemon]${RESET} %s\n" "$msg" ;;
        WARN)  printf "${YELLOW}[daemon]${RESET} %s\n" "$msg" ;;
        ERROR) printf "${RED}[daemon]${RESET} %s\n" "$msg" ;;
      esac
    fi
  fi
}

# --- Directory Setup ---

ensure_dirs() {
  mkdir -p "$MAESTRO_DIR/logs"
  mkdir -p "$INBOX_DIR"
  mkdir -p "$PROCESSED_DIR"
  mkdir -p "$CHAINS_DIR"
}

# --- PID Management ---

write_pid() {
  echo "$$" > "$PID_FILE"
}

read_pid() {
  if [[ -f "$PID_FILE" ]]; then
    cat "$PID_FILE"
  else
    echo ""
  fi
}

is_running() {
  local pid
  pid=$(read_pid)
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "$pid"
    return 0
  fi
  return 1
}

# --- State Management ---

write_state() {
  local autonomy_mode="${1:-tiered}"
  local active_chain="${2:-null}"
  local tasks_completed="${3:-0}"
  local tasks_failed="${4:-0}"
  local session_spend="${5:-0}"

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local started_at
  if [[ -f "$STATE_FILE" ]]; then
    started_at=$(grep "started_at:" "$STATE_FILE" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || echo "$ts")
  else
    started_at="$ts"
  fi

  cat > "$STATE_FILE" << EOF
daemon:
  pid: $$
  started_at: "${started_at}"
  autonomy_mode: ${autonomy_mode}
  active_chain: ${active_chain}
  tasks_completed: ${tasks_completed}
  tasks_failed: ${tasks_failed}
  spending:
    session: ${session_spend}
  last_activity: "${ts}"
  version: "1.0.0"
EOF
}

read_state_field() {
  local field="$1"
  if [[ -f "$STATE_FILE" ]]; then
    grep "${field}:" "$STATE_FILE" | tail -1 | awk '{print $2}' | tr -d '"'
  else
    echo ""
  fi
}

# --- Crash Recovery ---

check_crash_recovery() {
  if [[ ! -f "$STATE_FILE" ]]; then
    return
  fi

  local prev_pid
  prev_pid=$(read_state_field "pid")

  if [[ -z "$prev_pid" ]]; then
    return
  fi

  # Check if previous PID is still alive
  if kill -0 "$prev_pid" 2>/dev/null; then
    log "ERROR" "Daemon already running with PID $prev_pid. Exiting."
    echo "Daemon is already running (PID $prev_pid)."
    echo "Run: $0 stop    to stop it"
    echo "Run: $0 status  to check status"
    exit 1
  fi

  # Previous daemon died — perform recovery
  log "WARN" "Crash detected. Previous PID=$prev_pid is not running. Recovering."

  local active_chain
  active_chain=$(read_state_field "active_chain")

  if [[ "$active_chain" != "null" && -n "$active_chain" ]]; then
    log "WARN" "Recovering interrupted chain: $active_chain"
    # The daemon loop will detect and resume the chain on next iteration
  fi

  # Mark any 'running' tasks as failed
  if [[ -f "$QUEUE_FILE" ]]; then
    # Use sed to mark running tasks as failed (portable approach)
    local tmp_file
    tmp_file=$(mktemp)
    sed 's/status: running/status: failed/' "$QUEUE_FILE" > "$tmp_file"
    mv "$tmp_file" "$QUEUE_FILE"
    log "WARN" "Marked interrupted tasks as failed in task queue"
  fi

  # Send recovery notification via claude
  local recovery_msg="Daemon restarted after unexpected stop. Previous PID: $prev_pid"
  if [[ "$active_chain" != "null" && -n "$active_chain" ]]; then
    recovery_msg="$recovery_msg. Resuming chain: $active_chain"
  fi

  notify_daemon "$recovery_msg" "warn" &

  log "INFO" "Crash recovery complete. Entering main loop."
}

# --- Notification ---

notify_daemon() {
  local message="$1"
  local level="${2:-info}"

  # Invoke claude to send a notification via the notify skill
  if command -v claude &>/dev/null; then
    claude --print "[Maestro Daemon] $message" \
      --system "You are Maestro daemon. Send this message via the notify skill to all configured channels. Level: $level. Do not do anything else." \
      2>/dev/null || true
  fi
}

# --- Inbox Processing ---

ingest_inbox_files() {
  local count=0

  # List all YAML files in inbox (not in processed/ subdirectory)
  while IFS= read -r -d '' inbox_file; do
    if [[ ! -f "$inbox_file" ]]; then
      continue
    fi

    local filename
    filename=$(basename "$inbox_file")
    log "INFO" "Processing inbox file: $filename"

    # Extract command from the inbox file
    local command
    command=$(grep "^command:" "$inbox_file" 2>/dev/null | head -1 | sed 's/^command: //' | tr -d '"' || echo "")

    if [[ -z "$command" ]]; then
      log "WARN" "Inbox file $filename has no command field. Skipping."
      mv "$inbox_file" "$PROCESSED_DIR/"
      continue
    fi

    # Generate task ID from filename timestamp
    local task_id="task-$(date -u +%s)-file"

    # Append to task queue
    enqueue_task "$task_id" "file" "$command" "$inbox_file"

    # Move to processed
    mv "$inbox_file" "$PROCESSED_DIR/"
    count=$((count + 1))

  done < <(find "$INBOX_DIR" -maxdepth 1 -name "*.yaml" -print0 2>/dev/null)

  if [[ "$count" -gt 0 ]]; then
    log "INFO" "Ingested $count inbox file(s)"
  fi
}

# --- Task Queue ---

enqueue_task() {
  local task_id="$1"
  local source="$2"
  local command="$3"
  local inbox_file="${4:-}"

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Initialize queue file if needed
  if [[ ! -f "$QUEUE_FILE" ]]; then
    echo "tasks: []" > "$QUEUE_FILE"
  fi

  # Append task entry — simple YAML append
  cat >> "$QUEUE_FILE" << EOF

  - id: "${task_id}"
    source: ${source}
    command: "${command}"
    status: pending
    created_at: "${ts}"
EOF

  if [[ -n "$inbox_file" ]]; then
    echo "    inbox_file: \"${inbox_file}\"" >> "$QUEUE_FILE"
  fi

  log "INFO" "Queued task ${task_id} from ${source}: ${command:0:60}"
}

get_next_pending_task() {
  if [[ ! -f "$QUEUE_FILE" ]]; then
    echo ""
    return
  fi

  # Extract the first pending task's id and command
  # Returns "id|command" or empty string
  awk '
    /- id:/ { id=$2 }
    /command:/ { cmd=substr($0, index($0,$2)) }
    /status: pending/ { print id "|" cmd; exit }
  ' "$QUEUE_FILE" | tr -d '"'
}

mark_task_running() {
  local task_id="$1"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [[ -f "$QUEUE_FILE" ]]; then
    local tmp_file
    tmp_file=$(mktemp)
    # Mark the specific task as running (find id, then change next status: pending)
    awk -v id="$task_id" -v ts="$ts" '
      /- id:/ && $2 == "\"" id "\"" { found=1 }
      found && /status: pending/ { sub(/status: pending/, "status: running"); found_status=1 }
      found && found_status && !/started_at:/ && /^  - / { print "    started_at: \"" ts "\""; found=0; found_status=0 }
      { print }
    ' "$QUEUE_FILE" > "$tmp_file"
    mv "$tmp_file" "$QUEUE_FILE"
  fi
}

mark_task_done() {
  local task_id="$1"
  local status="$2"  # completed | failed
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if [[ -f "$QUEUE_FILE" ]]; then
    local tmp_file
    tmp_file=$(mktemp)
    sed "s/status: running/status: ${status}/" "$QUEUE_FILE" > "$tmp_file"
    mv "$tmp_file" "$QUEUE_FILE"
  fi
}

# --- Chain Detection ---

get_active_chain() {
  read_state_field "active_chain"
}

check_pending_chains() {
  local active_chain
  active_chain=$(get_active_chain)

  if [[ "$active_chain" != "null" && -n "$active_chain" ]]; then
    echo "$active_chain"
  else
    echo ""
  fi
}

# --- Task Execution ---

execute_task() {
  local task_id="$1"
  local command="$2"

  log "INFO" "Executing task ${task_id}: ${command:0:80}"
  mark_task_running "$task_id"

  # Load autonomy mode from config
  local autonomy_mode
  autonomy_mode=$(read_state_field "autonomy_mode")
  autonomy_mode="${autonomy_mode:-tiered}"

  # Build execution prompt
  local prompt
  prompt="You are Maestro in autonomous daemon mode.
Autonomy mode: ${autonomy_mode}
Execute this task: ${command}

Context:
- Read .maestro/config.yaml for service credentials and settings
- Use service skills as needed
- If a task chain is appropriate, use the task-chain skill
- Send notifications via notify skill when done
- Write results to .maestro/logs/daemon.log
- Respect spending limits from config

Complete the task and report the result."

  # Execute via claude CLI
  local result_file
  result_file=$(mktemp)

  local exit_code=0
  if command -v claude &>/dev/null; then
    claude --print "$prompt" \
      --max-turns 20 \
      2>>"$LOG_FILE" | tee "$result_file" >> "$LOG_FILE" || exit_code=$?
  else
    log "ERROR" "claude CLI not found. Cannot execute task."
    echo "claude CLI not found" > "$result_file"
    exit_code=1
  fi

  if [[ "$exit_code" -eq 0 ]]; then
    mark_task_done "$task_id" "completed"
    log "INFO" "Task ${task_id} completed successfully"
  else
    mark_task_done "$task_id" "failed"
    log "WARN" "Task ${task_id} failed (exit code: ${exit_code})"
    notify_daemon "Task failed: ${command:0:60} (exit code: ${exit_code})" "warn"
  fi

  rm -f "$result_file"
  return "$exit_code"
}

# --- Main Loop ---

run_daemon_loop() {
  local tasks_completed=0
  local tasks_failed=0
  local autonomy_mode
  autonomy_mode=$(read_state_field "autonomy_mode" || echo "tiered")
  autonomy_mode="${autonomy_mode:-tiered}"

  log "INFO" "Daemon started. PID=$$. Mode=${autonomy_mode}. Interval=${INTERVAL}s"
  notify_daemon "Daemon started. Mode: ${autonomy_mode}. Polling every ${INTERVAL}s." "info" &

  while true; do
    # 1. Ingest inbox files
    ingest_inbox_files

    # 2. Check for active chain
    local active_chain
    active_chain=$(check_pending_chains)

    if [[ -n "$active_chain" ]]; then
      log "INFO" "Resuming active chain: ${active_chain}"
      # Invoke claude to continue chain execution
      local chain_prompt="You are Maestro daemon. Resume the active task chain: ${active_chain}.
Read .maestro/chains/${active_chain}.state.yaml for current state.
Execute the next pending step using the task-chain skill.
Update chain state after each step.
Send notifications for step completion/failure."

      if command -v claude &>/dev/null; then
        claude --print "$chain_prompt" \
          --max-turns 10 \
          2>>"$LOG_FILE" >> "$LOG_FILE" || true
      fi
    fi

    # 3. Check task queue for pending tasks
    local next_task
    next_task=$(get_next_pending_task)

    if [[ -n "$next_task" ]]; then
      local task_id
      task_id=$(echo "$next_task" | cut -d'|' -f1)
      local task_command
      task_command=$(echo "$next_task" | cut -d'|' -f2-)

      if execute_task "$task_id" "$task_command"; then
        tasks_completed=$((tasks_completed + 1))
      else
        tasks_failed=$((tasks_failed + 1))
      fi
    fi

    # 4. Update state
    write_state "$autonomy_mode" "${active_chain:-null}" "$tasks_completed" "$tasks_failed" "0"

    # 5. Write health status for external monitors
    local loop_iteration=$(( tasks_completed + tasks_failed ))
    write_health "running" "$loop_iteration"

    # 6. Check for reload request (SIGHUP)
    if [[ "$RELOAD_REQUESTED" == "true" ]]; then
      log "INFO" "Reloading configuration..."
      # Re-read state to pick up config changes
      autonomy_mode=$(read_state_field "autonomy_mode" || echo "tiered")
      autonomy_mode="${autonomy_mode:-tiered}"
      RELOAD_REQUESTED=false
    fi

    # 7. Sleep until next poll
    sleep "$INTERVAL"
  done
}

# --- Signal Handling ---

shutdown_daemon() {
  log "INFO" "Daemon stopping gracefully (SIGTERM received)"

  # Update state
  local autonomy_mode
  autonomy_mode=$(read_state_field "autonomy_mode" || echo "tiered")
  write_state "${autonomy_mode:-tiered}" "null" \
    "$(read_state_field "tasks_completed" || echo 0)" \
    "$(read_state_field "tasks_failed" || echo 0)" \
    "0"

  # Remove PID file
  rm -f "$PID_FILE"

  # Write final health status
  write_health "stopped" "0"

  # Send shutdown notification
  notify_daemon "Daemon stopped gracefully." "info" &

  log "INFO" "Daemon stopped."
  exit 0
}

trap shutdown_daemon SIGTERM SIGINT

# --- Health endpoint ---
# Write a health status file that external monitors can check
HEALTH_FILE="$MAESTRO_DIR/logs/daemon-health.json"
START_TIME=$(date +%s)

write_health() {
  local status="$1"
  local iteration="${2:-0}"
  local uptime_secs=$(( $(date +%s) - START_TIME ))
  mkdir -p "$MAESTRO_DIR/logs"
  cat > "$HEALTH_FILE" <<HEALTHEOF
{"status":"${status}","pid":$$,"iteration":${iteration},"uptime_seconds":${uptime_secs},"last_check":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
HEALTHEOF
}

# --- Graceful reload on SIGHUP ---
RELOAD_REQUESTED=false
reload_config() {
  RELOAD_REQUESTED=true
  log "INFO" "SIGHUP received — will reload config at next iteration"
}
trap reload_config HUP

# --- CLI Commands ---

cmd_start() {
  # Check if already running
  local running_pid
  if running_pid=$(is_running); then
    echo "Daemon is already running (PID $running_pid)."
    exit 1
  fi

  ensure_dirs
  write_pid
  START_TIME=$(date +%s)
  check_crash_recovery
  write_state "tiered" "null" "0" "0" "0"
  write_health "starting" "0"

  echo "Maestro autonomous daemon started (PID $$)."
  echo "Logs: $LOG_FILE"
  echo "Polling every ${INTERVAL}s. Press Ctrl+C or send SIGTERM to stop."

  run_daemon_loop
}

cmd_stop() {
  local running_pid
  if running_pid=$(is_running); then
    echo "Stopping daemon (PID $running_pid)..."
    kill -TERM "$running_pid"
    # Wait up to 10 seconds for graceful shutdown
    local count=0
    while kill -0 "$running_pid" 2>/dev/null && [[ "$count" -lt 10 ]]; do
      sleep 1
      count=$((count + 1))
    done
    if kill -0 "$running_pid" 2>/dev/null; then
      echo "Daemon did not stop in 10s. Sending SIGKILL."
      kill -KILL "$running_pid"
    fi
    rm -f "$PID_FILE"
    echo "Daemon stopped."
  else
    echo "Daemon is not running."
    rm -f "$PID_FILE"
  fi
}

cmd_status() {
  local running_pid
  if running_pid=$(is_running); then
    echo "Daemon is running (PID $running_pid)"

    if [[ -f "$STATE_FILE" ]]; then
      echo ""
      echo "State:"
      grep -E "(autonomy_mode|active_chain|tasks_completed|tasks_failed|last_activity|session)" "$STATE_FILE" \
        | sed 's/^  /  /'
    fi

    local pending_count=0
    if [[ -f "$QUEUE_FILE" ]]; then
      pending_count=$(grep -c "status: pending" "$QUEUE_FILE" 2>/dev/null || echo 0)
    fi
    echo "  pending_tasks: $pending_count"

    local inbox_count=0
    inbox_count=$(find "$INBOX_DIR" -maxdepth 1 -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
    echo "  inbox_files:   $inbox_count"
  else
    echo "Daemon is not running."
    if [[ -f "$STATE_FILE" ]]; then
      local last_activity
      last_activity=$(read_state_field "last_activity")
      [[ -n "$last_activity" ]] && echo "Last activity: $last_activity"
    fi
  fi
}

cmd_restart() {
  cmd_stop
  sleep 1
  cmd_start
}

cmd_send() {
  # Queue a command from the CLI
  local command="${1:-}"
  if [[ -z "$command" ]]; then
    echo "Usage: $0 send \"<command>\""
    exit 1
  fi

  ensure_dirs
  local task_id="task-$(date -u +%s)-cli"
  enqueue_task "$task_id" "cli" "$command"
  echo "Command queued: $task_id"
  echo "The daemon will pick it up on next poll (within ${INTERVAL}s)."
}

# --- Entry Point ---

COMMAND="${1:-start}"

case "$COMMAND" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  status)  cmd_status ;;
  restart) cmd_restart ;;
  send)    shift; cmd_send "$@" ;;
  *)
    echo "Usage: $0 [start|stop|status|restart|send \"command\"]"
    echo ""
    echo "Commands:"
    echo "  start              Start the autonomous daemon"
    echo "  stop               Stop the daemon gracefully"
    echo "  status             Show daemon status"
    echo "  restart            Stop then start"
    echo "  send \"command\"     Queue a command for the daemon to execute"
    echo ""
    echo "Environment variables:"
    echo "  MAESTRO_DIR        .maestro directory (default: .maestro)"
    echo "  DAEMON_INTERVAL    Poll interval in seconds (default: 30)"
    echo "  DAEMON_LOG_LEVEL   Log level: DEBUG|INFO|WARN|ERROR (default: INFO)"
    exit 1
    ;;
esac
