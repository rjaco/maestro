#!/usr/bin/env bash
# Maestro Remote Listener — polls Telegram for commands
# Usage: ./scripts/remote-listener.sh
# Env: MAESTRO_TELEGRAM_TOKEN, MAESTRO_TELEGRAM_CHAT
# Runs as a background process alongside opus-daemon.sh

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

STATE_FILE="${PROJECT_ROOT}/.maestro/state.local.md"
LOGS_DIR="${PROJECT_ROOT}/.maestro/logs"
OFFSET_FILE="${LOGS_DIR}/telegram-offset"
DAEMON_LOG="${LOGS_DIR}/daemon.log"
REMOTE_COMMANDS_LOG="${LOGS_DIR}/remote-commands.jsonl"
HEARTBEAT_FILE="${LOGS_DIR}/heartbeat.json"
STORIES_DIR="${PROJECT_ROOT}/.maestro/stories"

POLL_TIMEOUT=30
TELEGRAM_API="https://api.telegram.org/bot${MAESTRO_TELEGRAM_TOKEN}"

# --- Validate environment ---
if [[ -z "${MAESTRO_TELEGRAM_TOKEN:-}" ]]; then
  echo "[remote-listener] ERROR: MAESTRO_TELEGRAM_TOKEN is not set" >&2
  exit 1
fi

if [[ -z "${MAESTRO_TELEGRAM_CHAT:-}" ]]; then
  echo "[remote-listener] ERROR: MAESTRO_TELEGRAM_CHAT is not set" >&2
  exit 1
fi

# --- Ensure log directory exists ---
mkdir -p "${LOGS_DIR}"

# --- Helper: send Telegram message ---
send_message() {
  local text="$1"
  local response
  response=$(curl -s --max-time 10 -X POST "${TELEGRAM_API}/sendMessage" \
    -d "chat_id=${MAESTRO_TELEGRAM_CHAT}" \
    -d "parse_mode=HTML" \
    --data-urlencode "text=${text}" 2>/dev/null) || true

  if [[ -z "$response" ]]; then
    echo "[remote-listener] WARNING: curl failed to send message" >&2
    return
  fi

  local ok
  ok=$(printf '%s' "$response" | jq -r '.ok // false' 2>/dev/null) || true
  if [[ "$ok" != "true" ]]; then
    local err
    err=$(printf '%s' "$response" | jq -r '.description // "unknown error"' 2>/dev/null) || true
    echo "[remote-listener] WARNING: Telegram API error: ${err}" >&2
  fi
}

# --- Helper: read offset ---
read_offset() {
  if [[ -f "$OFFSET_FILE" ]]; then
    cat "$OFFSET_FILE" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# --- Helper: write offset ---
write_offset() {
  local offset="$1"
  printf '%s\n' "$offset" > "$OFFSET_FILE"
}

# --- Helper: parse state frontmatter value ---
state_val() {
  local key="$1"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo ""
    return
  fi
  sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null \
    | sed '1d;$d' \
    | grep -E "^${key}:" \
    | head -1 \
    | sed "s/^${key}:[[:space:]]*//" \
    | sed 's/^"\(.*\)"$/\1/' \
    | sed "s/^'\(.*\)'$/\1/" \
    | xargs 2>/dev/null \
    || echo ""
}

# --- Helper: update state frontmatter field ---
update_state_field() {
  local key="$1"
  local value="$2"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "[remote-listener] WARNING: state file not found: ${STATE_FILE}" >&2
    return
  fi
  # Replace the value in the YAML frontmatter (between first pair of ---)
  local tmp
  tmp=$(mktemp)
  awk -v key="$key" -v val="$value" '
    /^---$/ { count++; print; next }
    count == 1 && $0 ~ "^" key ":" { print key ": " val; next }
    { print }
  ' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE" || { rm -f "$tmp"; echo "[remote-listener] ERROR: failed to update state field: ${key}" >&2; }
}

# --- Helper: audit log ---
audit_log() {
  local command="$1"
  local chat_id="$2"
  local username="${3:-unknown}"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"timestamp":"%s","command":"%s","chat_id":"%s","username":"%s"}\n' \
    "$ts" "$command" "$chat_id" "$username" >> "$REMOTE_COMMANDS_LOG"
}

# --- Command: /status ---
cmd_status() {
  if [[ ! -f "$STATE_FILE" ]]; then
    send_message "<b>[Maestro] Status</b>

No state file found. Maestro may not be initialized."
    return
  fi

  local active feature phase mode current_story total_stories token_spend
  active=$(state_val "active")
  feature=$(state_val "feature")
  phase=$(state_val "phase")
  mode=$(state_val "mode")
  current_story=$(state_val "current_story")
  total_stories=$(state_val "total_stories")
  token_spend=$(state_val "token_spend")

  local status_icon="inactive"
  if [[ "$active" == "true" ]]; then
    status_icon="active"
  fi

  local progress=""
  if [[ -n "$current_story" && -n "$total_stories" ]]; then
    progress="
<b>Progress:</b> ${current_story}/${total_stories} stories"
  fi

  local cost_line=""
  if [[ -n "$token_spend" && "$token_spend" -gt 0 ]] 2>/dev/null; then
    cost_line="
<b>Tokens:</b> ${token_spend}"
  fi

  send_message "<b>[Maestro] Status</b>

<b>Active:</b> ${status_icon}
<b>Feature:</b> ${feature:-none}
<b>Phase:</b> ${phase:-unknown}
<b>Mode:</b> ${mode:-unknown}${progress}${cost_line}"
}

# --- Command: /pause ---
cmd_pause() {
  if [[ ! -f "$STATE_FILE" ]]; then
    send_message "[Maestro] Cannot pause: no state file found."
    return
  fi
  update_state_field "phase" "paused"
  send_message "<b>[Maestro] Paused</b>

Session paused via remote command. Use /resume to continue."
}

# --- Command: /resume ---
cmd_resume() {
  if [[ ! -f "$STATE_FILE" ]]; then
    send_message "[Maestro] Cannot resume: no state file found."
    return
  fi
  update_state_field "phase" "opus_executing"
  update_state_field "active" "true"
  send_message "<b>[Maestro] Resumed</b>

Session resumed. Phase set to opus_executing."
}

# --- Command: /logs ---
cmd_logs() {
  if [[ ! -f "$DAEMON_LOG" ]]; then
    send_message "[Maestro] No daemon log found at ${DAEMON_LOG}"
    return
  fi

  local last_lines
  last_lines=$(tail -10 "$DAEMON_LOG" 2>/dev/null || echo "(empty)")

  send_message "<b>[Maestro] Last 10 log lines</b>

<pre>${last_lines}</pre>"
}

# --- Command: /stories ---
cmd_stories() {
  if [[ ! -d "$STORIES_DIR" ]]; then
    send_message "[Maestro] No stories directory found at ${STORIES_DIR}"
    return
  fi

  local story_list=""
  local count=0

  while IFS= read -r -d '' story_file; do
    local story_name
    story_name=$(basename "$story_file" .md)

    # Try to read status from frontmatter
    local status
    status=$(grep -m1 "^status:" "$story_file" 2>/dev/null \
      | sed 's/^status:[[:space:]]*//' \
      | sed 's/^"\(.*\)"$/\1/' \
      | xargs 2>/dev/null) || status="unknown"

    story_list="${story_list}
  ${story_name}: ${status:-unknown}"
    count=$(( count + 1 ))
  done < <(find "$STORIES_DIR" -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)

  if [[ $count -eq 0 ]]; then
    send_message "[Maestro] No story files found in ${STORIES_DIR}"
    return
  fi

  send_message "<b>[Maestro] Stories (${count})</b>
<pre>${story_list}</pre>"
}

# --- Command: /heartbeat ---
cmd_heartbeat() {
  if [[ ! -f "$HEARTBEAT_FILE" ]]; then
    send_message "[Maestro] No heartbeat file found at ${HEARTBEAT_FILE}"
    return
  fi

  local hb_content
  hb_content=$(cat "$HEARTBEAT_FILE" 2>/dev/null || echo "{}")

  local ts phase status
  ts=$(printf '%s' "$hb_content" | jq -r '.timestamp // "unknown"' 2>/dev/null) || ts="unknown"
  phase=$(printf '%s' "$hb_content" | jq -r '.phase // "unknown"' 2>/dev/null) || phase="unknown"
  status=$(printf '%s' "$hb_content" | jq -r '.status // "unknown"' 2>/dev/null) || status="unknown"

  send_message "<b>[Maestro] Heartbeat</b>

<b>Timestamp:</b> ${ts}
<b>Phase:</b> ${phase}
<b>Status:</b> ${status}"
}

# --- Command: unknown ---
cmd_unknown() {
  send_message "Unknown command. Available: /status /pause /resume /logs /stories /heartbeat"
}

# --- Process a single update ---
process_update() {
  local update="$1"

  local update_id chat_id text username
  update_id=$(printf '%s' "$update" | jq -r '.update_id // 0' 2>/dev/null) || update_id=0
  chat_id=$(printf '%s' "$update" | jq -r '.message.chat.id // ""' 2>/dev/null) || chat_id=""
  text=$(printf '%s' "$update" | jq -r '.message.text // ""' 2>/dev/null) || text=""
  username=$(printf '%s' "$update" | jq -r '.message.from.username // "unknown"' 2>/dev/null) || username="unknown"

  # Security: only process messages from configured chat
  if [[ "$chat_id" != "$MAESTRO_TELEGRAM_CHAT" ]]; then
    echo "[remote-listener] Ignoring message from unauthorized chat: ${chat_id}" >&2
    return
  fi

  # Extract command (strip bot username suffix, e.g. /status@MyBot -> /status)
  local command
  command=$(printf '%s' "$text" | sed 's/@[^ ]*//' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')

  echo "[remote-listener] Received command '${command}' from ${username} (chat: ${chat_id})"

  # Audit log
  audit_log "$command" "$chat_id" "$username"

  # Dispatch
  case "$command" in
    /status)    cmd_status ;;
    /pause)     cmd_pause ;;
    /resume)    cmd_resume ;;
    /logs)      cmd_logs ;;
    /stories)   cmd_stories ;;
    /heartbeat) cmd_heartbeat ;;
    *)          cmd_unknown ;;
  esac
}

# --- Main polling loop ---
echo "[remote-listener] Starting. Polling Telegram (timeout=${POLL_TIMEOUT}s)..."
echo "[remote-listener] Chat ID: ${MAESTRO_TELEGRAM_CHAT}"

while true; do
  offset=$(read_offset)
  offset_param=$(( offset + 1 ))

  # Poll for updates (long polling)
  response=$(curl -s --max-time $(( POLL_TIMEOUT + 5 )) \
    "${TELEGRAM_API}/getUpdates?timeout=${POLL_TIMEOUT}&offset=${offset_param}" \
    2>/dev/null) || true

  if [[ -z "$response" ]]; then
    echo "[remote-listener] WARNING: empty response from Telegram API, retrying..." >&2
    sleep 5
    continue
  fi

  local_ok=$(printf '%s' "$response" | jq -r '.ok // false' 2>/dev/null) || local_ok="false"
  if [[ "$local_ok" != "true" ]]; then
    err_desc=$(printf '%s' "$response" | jq -r '.description // "unknown error"' 2>/dev/null) || err_desc="unknown"
    echo "[remote-listener] WARNING: Telegram API error: ${err_desc}" >&2
    sleep 10
    continue
  fi

  # Count updates
  update_count=$(printf '%s' "$response" | jq '.result | length' 2>/dev/null) || update_count=0

  if [[ "$update_count" -gt 0 ]]; then
    # Get the highest update_id for tracking
    max_id=$(printf '%s' "$response" | jq '[.result[].update_id] | max' 2>/dev/null) || max_id="$offset"

    # Process each update
    while IFS= read -r update; do
      process_update "$update"
    done < <(printf '%s' "$response" | jq -c '.result[]' 2>/dev/null)

    # Advance offset past last processed update
    write_offset "$max_id"
  fi
done
