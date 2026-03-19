#!/usr/bin/env bash
set -euo pipefail

# Maestro Stop Hook
# Prevents session exit during active Maestro dev-loop.
# Reads state from .maestro/state.local.md (NOT .claude/).
# Outputs JSON: {"decision": "approve"|"block", "reason": "...", "systemMessage": "..."}

STATE_FILE=".maestro/state.local.md"

# --- Helpers ---

allow_exit() {
  local reason="${1:-No active Maestro session}"
  printf '{"decision":"approve","reason":"%s"}\n' "$reason"
  exit 0
}

block_exit() {
  local prompt_text="$1"
  local system_msg="$2"
  # Escape special JSON characters in prompt and system message
  prompt_text=$(printf '%s' "$prompt_text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
  system_msg=$(printf '%s' "$system_msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
  printf '{"decision":"block","reason":"%s","systemMessage":"%s"}\n' "$prompt_text" "$system_msg"
  exit 0
}

# --- State file checks ---

if [[ ! -f "$STATE_FILE" ]]; then
  allow_exit "No Maestro state file found"
fi

# Read entire state file
state_content=$(cat "$STATE_FILE" 2>/dev/null) || allow_exit "Failed to read Maestro state file"

# Validate frontmatter structure (must start with ---)
if [[ ! "$state_content" == ---* ]]; then
  allow_exit "Maestro state file has no valid frontmatter"
fi

# --- Parse YAML frontmatter ---

# Extract frontmatter (between first and second --- lines)
frontmatter=$(printf '%s\n' "$state_content" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

if [[ -z "$frontmatter" ]]; then
  allow_exit "Empty Maestro frontmatter"
fi

# Helper to extract a YAML value (handles colons in values by splitting on first colon only)
yaml_val() {
  local key="$1"
  local line
  line=$(printf '%s\n' "$frontmatter" | grep -E "^${key}:" | head -1)
  [[ -z "$line" ]] && echo "" && return
  # Remove key and first colon, trim leading whitespace
  local val="${line#*:}"
  val="${val#"${val%%[![:space:]]*}"}"
  # Strip surrounding quotes
  val="${val%\"}" ; val="${val#\"}"
  val="${val%\'}" ; val="${val#\'}"
  printf '%s' "$val"
}

# --- Check active state ---

active=$(yaml_val "active")
if [[ "$active" != "true" ]]; then
  allow_exit "Maestro is not active"
fi

# --- Session isolation ---
# Only block if the state file belongs to this session

state_session_id=$(yaml_val "session_id")

# Read hook input from stdin to get current session_id
hook_input=""
if [[ ! -t 0 ]]; then
  hook_input=$(cat)
fi

current_session_id=""
if [[ -n "$hook_input" ]]; then
  current_session_id=$(printf '%s' "$hook_input" | jq -r '.session_id // empty' 2>/dev/null || true)
fi

if [[ -n "$state_session_id" && -n "$current_session_id" && "$state_session_id" != "$current_session_id" ]]; then
  allow_exit "Maestro session belongs to a different session"
fi

# --- Extract state fields ---

layer=$(yaml_val "layer")
mode=$(yaml_val "mode")
phase=$(yaml_val "phase")
feature=$(yaml_val "feature")
current_story=$(yaml_val "current_story")
total_stories=$(yaml_val "total_stories")
qa_iteration=$(yaml_val "qa_iteration")
max_qa_iterations=$(yaml_val "max_qa_iterations")
self_heal_iteration=$(yaml_val "self_heal_iteration")
max_self_heal=$(yaml_val "max_self_heal")

# Opus-specific fields
opus_mode=$(yaml_val "opus_mode")
token_budget=$(yaml_val "token_budget")
token_spend=$(yaml_val "token_spend")
current_milestone=$(yaml_val "current_milestone")
total_milestones=$(yaml_val "total_milestones")
consecutive_failures=$(yaml_val "consecutive_failures")
max_consecutive_failures=$(yaml_val "max_consecutive_failures")

# --- Extract prompt text (everything after closing ---) ---

prompt_text=$(printf '%s\n' "$state_content" | sed '1,/^---$/d' | sed '1,/^---$/d' | sed '/^[[:space:]]*$/d' | head -20)

if [[ -z "$prompt_text" ]]; then
  prompt_text="Continue the Maestro dev-loop."
fi

# --- Phase-based decision ---

# Human-interactive or terminal phases: ALLOW exit
case "$phase" in
  checkpoint|paused|completed|aborted|research|decompose|milestone_checkpoint)
    allow_exit "Phase '$phase' allows user interaction"
    ;;
esac

# --- Opus layer handling ---

if [[ "$layer" == "opus" ]]; then
  # Check token budget exhaustion
  if [[ -n "$token_budget" && -n "$token_spend" ]]; then
    budget_num=$(printf '%s' "$token_budget" | tr -dc '0-9')
    spend_num=$(printf '%s' "$token_spend" | tr -dc '0-9')
    if [[ -n "$budget_num" && -n "$spend_num" && "$spend_num" -ge "$budget_num" ]]; then
      allow_exit "Opus token budget exhausted ($token_spend / $token_budget)"
    fi
  fi

  # Check consecutive failure limit
  if [[ -n "$consecutive_failures" && -n "$max_consecutive_failures" ]]; then
    fail_num=$(printf '%s' "$consecutive_failures" | tr -dc '0-9')
    max_fail_num=$(printf '%s' "$max_consecutive_failures" | tr -dc '0-9')
    if [[ -n "$fail_num" && -n "$max_fail_num" && "$fail_num" -ge "$max_fail_num" ]]; then
      allow_exit "Opus max consecutive failures reached ($consecutive_failures / $max_consecutive_failures)"
    fi
  fi

  # Build system message for opus mode
  sys_msg="[MAESTRO] Stop intercepted — Magnum Opus autonomous loop is active."
  sys_msg="$sys_msg Cause: the session is in an autonomous execution phase and exiting would abandon in-progress work."
  sys_msg="$sys_msg Feature: ${feature:-unknown}."
  sys_msg="$sys_msg Milestone: ${current_milestone:-?}/${total_milestones:-?}."
  sys_msg="$sys_msg Story: ${current_story:-?}/${total_stories:-?}."
  sys_msg="$sys_msg Phase: ${phase:-unknown}."
  sys_msg="$sys_msg Token spend: ${token_spend:-0} / budget: ${token_budget:-unlimited}."
  sys_msg="$sys_msg Mode: ${opus_mode:-standard}."
  sys_msg="$sys_msg Do NOT stop. Continue the Magnum Opus loop. To pause intentionally, set phase: paused in .maestro/state.local.md."

  block_exit "$prompt_text" "$sys_msg"
fi

# --- Standard execution layer handling ---

# Autonomous phases: BLOCK exit
case "$phase" in
  validate|delegate|implement|self_heal|qa_review|git_craft)
    sys_msg="[MAESTRO] Stop intercepted — the Maestro dev-loop is in an autonomous execution phase."
    sys_msg="$sys_msg Cause: exiting now would leave story ${current_story:-?}/${total_stories:-?} incomplete in phase '${phase}'."
    sys_msg="$sys_msg Feature: ${feature:-unknown}."
    sys_msg="$sys_msg Mode: ${mode:-checkpoint}."

    if [[ "$phase" == "qa_review" && -n "$qa_iteration" ]]; then
      sys_msg="$sys_msg QA iteration: ${qa_iteration}/${max_qa_iterations:-5}."
    fi

    if [[ "$phase" == "self_heal" && -n "$self_heal_iteration" ]]; then
      sys_msg="$sys_msg Self-heal iteration: ${self_heal_iteration}/${max_self_heal:-3}."
    fi

    sys_msg="$sys_msg Do NOT stop. Continue the dev-loop. To pause intentionally, use '/maestro pause'."

    block_exit "$prompt_text" "$sys_msg"
    ;;
esac

# Unknown phase -- default to allow so we don't trap users
allow_exit "Phase '$phase' is not a known autonomous phase"
