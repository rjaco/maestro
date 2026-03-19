#!/usr/bin/env bash
set -euo pipefail

# Maestro TaskCompleted Hook
# Fires when a task is being marked complete.
# Runs quick validation: does the task output match its acceptance criteria?
# If validation PASSES: exit code 0 (allow completion).
# If validation FAILS: exit code 2 with feedback describing what's missing (blocks completion).
# Logs to .maestro/logs/workers/team-lifecycle.md.

TEAM_STATE_FILE=".maestro/team-state.md"
LOG_DIR=".maestro/logs/workers"
LOG_FILE="${LOG_DIR}/team-lifecycle.md"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Helpers ---

log_entry() {
  local event="$1"
  local detail="$2"
  mkdir -p "$LOG_DIR"
  printf '\n## TaskCompleted — %s\n- Event: %s\n- Detail: %s\n' \
    "$TIMESTAMP" "$event" "$detail" >> "$LOG_FILE"
}

allow_completion() {
  local reason="${1:-Validation passed}"
  log_entry "allow_completion" "$reason"
  exit 0
}

block_completion() {
  local feedback="$1"
  log_entry "block_completion" "$feedback"
  printf '%s\n' "$feedback"
  exit 2
}

# --- Read hook input from stdin ---

hook_input=""
if [[ ! -t 0 ]]; then
  hook_input=$(cat)
fi

task_id=""
task_output=""
agent_id=""

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

if [[ -n "$hook_input" ]]; then
  task_id=$(json_str_val "task_id" "$hook_input")
  task_output=$(json_str_val "task_output" "$hook_input")
  agent_id=$(json_str_val "agent_id" "$hook_input")
fi

# --- Check team state file ---

if [[ ! -f "$TEAM_STATE_FILE" ]]; then
  allow_completion "No team-state file — cannot validate, allowing completion"
fi

state_content=$(cat "$TEAM_STATE_FILE" 2>/dev/null) || allow_completion "Failed to read team-state file"

# Validate frontmatter structure
if [[ ! "$state_content" == ---* ]]; then
  allow_completion "team-state.md has no valid frontmatter"
fi

# --- Parse YAML frontmatter ---

frontmatter=$(printf '%s\n' "$state_content" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

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

# --- Resolve task_id from input or frontmatter ---

if [[ -z "$task_id" ]]; then
  task_id=$(yaml_val "current_task")
fi

if [[ -z "$task_id" ]]; then
  allow_completion "No task_id provided and no current_task in team-state — allowing completion"
fi

# --- Find acceptance criteria for the task in the body ---
# Expected format in team-state.md body:
#
# ### TASK-ID
# ...
# #### Acceptance Criteria
# - criterion one
# - criterion two
# ...

# Strip the YAML frontmatter block (first ---...--- pair) to get the body
tasks_body=$(printf '%s\n' "$state_content" | awk 'BEGIN{fm=0;body=0} /^---$/{if(fm==0){fm=1;next}if(fm==1&&body==0){body=1;next}} body==1{print}')

# Extract the section for the given task_id
task_section=""
in_section=0
while IFS= read -r line; do
  if [[ "$line" =~ ^###[[:space:]]+${task_id}([[:space:]]|$) ]]; then
    in_section=1
    task_section="$line"$'\n'
    continue
  fi
  if [[ $in_section -eq 1 ]]; then
    # Stop at the next ### heading (sibling task) but not #### (sub-heading)
    if [[ "$line" =~ ^###[[:space:]] && ! "$line" =~ ^####[[:space:]] ]]; then
      break
    fi
    task_section+="$line"$'\n'
  fi
done <<< "$tasks_body"

if [[ -z "$task_section" ]]; then
  allow_completion "No task section found for ${task_id} in team-state.md — allowing completion"
fi

# --- Extract acceptance criteria lines ---

criteria_lines=""
in_ac=0
while IFS= read -r line; do
  if [[ "$line" =~ ^####[[:space:]]+(Acceptance[[:space:]]Criteria|AC) ]]; then
    in_ac=1
    continue
  fi
  if [[ $in_ac -eq 1 ]]; then
    # Stop at next heading
    if [[ "$line" =~ ^#+ ]]; then
      break
    fi
    # Collect non-empty lines starting with -
    if [[ "$line" =~ ^[[:space:]]*\-[[:space:]] ]]; then
      criteria_lines+="$line"$'\n'
    fi
  fi
done <<< "$task_section"

if [[ -z "$criteria_lines" ]]; then
  allow_completion "No acceptance criteria found for ${task_id} — allowing completion"
fi

# --- Validate task output against each criterion ---
# Heuristic: each criterion must appear (as a keyword phrase) in the task output.
# This is a lightweight check — the implementer agent's STATUS report is the primary source of truth.

if [[ -z "$task_output" ]]; then
  block_completion "Task ${task_id} cannot be validated: no task_output was provided in the hook input. Resubmit with the agent's STATUS report in task_output."
fi

missing_criteria=""
while IFS= read -r criterion; do
  [[ -z "$criterion" ]] && continue
  # Strip leading "- " and trim
  keyword="${criterion#*- }"
  keyword="${keyword#"${keyword%%[![:space:]]*}"}"
  keyword="${keyword%"${keyword##*[![:space:]]}"}"
  # Skip empty or very short keywords
  [[ ${#keyword} -lt 4 ]] && continue
  # Case-insensitive check: does the output mention this criterion?
  criterion_found=$(printf '%s' "$task_output" | grep -i "$keyword" 2>/dev/null | head -1 || true)
  if [[ -z "$criterion_found" ]]; then
    missing_criteria+="  - ${keyword}"$'\n'
  fi
done <<< "$criteria_lines"

if [[ -n "$missing_criteria" ]]; then
  block_completion "Task ${task_id} is missing evidence for the following acceptance criteria in its output:
${missing_criteria}
Review the task output and ensure each criterion is addressed before marking complete."
fi

allow_completion "All acceptance criteria verified for ${task_id} (agent=${agent_id})"
