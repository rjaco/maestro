#!/usr/bin/env bash
set -euo pipefail

# Maestro TeammateIdle Hook
# Fires when a teammate agent is about to go idle.
# Reads team state from .maestro/team-state.md.
# If unblocked tasks remain: exit code 2 with assignment message (keeps teammate working).
# If no unblocked tasks remain: exit code 0 (allow idle).
# Logs decision to .maestro/logs/workers/team-lifecycle.md.

TEAM_STATE_FILE=".maestro/team-state.md"
LOG_DIR=".maestro/logs/workers"
LOG_FILE="${LOG_DIR}/team-lifecycle.md"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Helpers ---

log_entry() {
  local event="$1"
  local detail="$2"
  mkdir -p "$LOG_DIR"
  printf '\n## TeammateIdle — %s\n- Event: %s\n- Detail: %s\n' \
    "$TIMESTAMP" "$event" "$detail" >> "$LOG_FILE"
}

allow_idle() {
  local reason="${1:-No unblocked tasks remaining}"
  log_entry "allow_idle" "$reason"
  exit 0
}

assign_task() {
  local task_id="$1"
  local task_title="$2"
  local agent_id="${3:-unknown}"
  log_entry "assign_task" "agent=${agent_id} task=${task_id}: ${task_title}"
  printf 'You have been assigned the next unblocked task.\n\nTask: %s — %s\n\nContinue the dev-loop for this task immediately.\n' \
    "$task_id" "$task_title"
  exit 2
}

# --- Read hook input from stdin ---

hook_input=""
if [[ ! -t 0 ]]; then
  hook_input=$(cat)
fi

# Parse JSON input without requiring jq (grep-based extraction for simple string fields)
# Returns empty string when key is absent; safe under set -euo pipefail.
json_str_val() {
  local key="$1"
  local input="$2"
  local match
  match=$(printf '%s' "$input" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" 2>/dev/null | head -1 || true)
  [[ -z "$match" ]] && return 0
  printf '%s' "$match" | sed "s/\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\"/\1/"
}

agent_id=""
if [[ -n "$hook_input" ]]; then
  agent_id=$(json_str_val "agent_id" "$hook_input")
fi

# --- Check team state file ---

if [[ ! -f "$TEAM_STATE_FILE" ]]; then
  allow_idle "No team-state file found at ${TEAM_STATE_FILE}"
fi

state_content=$(cat "$TEAM_STATE_FILE" 2>/dev/null) || allow_idle "Failed to read team-state file"

# Validate frontmatter structure
if [[ ! "$state_content" == ---* ]]; then
  allow_idle "team-state.md has no valid frontmatter"
fi

# --- Parse YAML frontmatter ---

frontmatter=$(printf '%s\n' "$state_content" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

if [[ -z "$frontmatter" ]]; then
  allow_idle "Empty team-state frontmatter"
fi

# Helper to extract a YAML value (handles colons in values by splitting on first colon only)
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

# --- Check active state ---

active=$(yaml_val "active")
if [[ "$active" != "true" ]]; then
  allow_idle "Team is not active (active=${active})"
fi

# --- Scan tasks body for unblocked tasks ---
# Task lines in team-state.md use the format:
#   - [status] TASK-ID: title  (status: todo | in_progress | blocked | done)
# An "unblocked" task is one with status "todo".

# Strip the YAML frontmatter block (first ---...--- pair) to get the body
tasks_body=$(printf '%s\n' "$state_content" | awk 'BEGIN{fm=0;body=0} /^---$/{if(fm==0){fm=1;next}if(fm==1&&body==0){body=1;next}} body==1{print}')

# Find first todo task not assigned to any agent
first_todo=""
first_todo_id=""
first_todo_title=""

while IFS= read -r line; do
  # Match lines like: - [todo] TASK-001: Some title
  if [[ "$line" =~ ^\-[[:space:]]*\[todo\][[:space:]]*(TASK-[^:]+):[[:space:]]*(.+)$ ]]; then
    first_todo_id="${BASH_REMATCH[1]}"
    first_todo_title="${BASH_REMATCH[2]}"
    first_todo="$line"
    break
  fi
done <<< "$tasks_body"

if [[ -z "$first_todo" ]]; then
  allow_idle "No unblocked (todo) tasks remaining in team-state.md"
fi

assign_task "$first_todo_id" "$first_todo_title" "$agent_id"
