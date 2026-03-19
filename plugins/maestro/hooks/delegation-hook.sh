#!/usr/bin/env bash
set -euo pipefail

# Maestro Delegation Enforcement Hook (PreToolUse)
# Error handler — log but never block
_hook_error_handler() {
  local exit_code=$?
  local line_no=$1
  local hook_name
  hook_name="$(basename "${BASH_SOURCE[0]}")"
  local log_dir="${MAESTRO_LOG_DIR:-.maestro/logs}"
  mkdir -p "$log_dir" 2>/dev/null || true
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: ${hook_name}:${line_no} exited with code ${exit_code}" >> "$log_dir/hooks.log" 2>/dev/null || true
}
trap '_hook_error_handler $LINENO' ERR
# Prevents the orchestrator from directly editing/writing files during active sessions.
# When Maestro is active, code changes MUST go through dispatched agents in worktrees.
#
# This hook fires on PreToolUse for Edit, Write, and NotebookEdit tools.
# It allows the tool if:
#   - No active Maestro session
#   - The file is inside .maestro/ (state management)
#   - The tool is being used by a subagent (not the orchestrator)
#   - The session is in a planning phase (decompose, research, etc.)
#
# It blocks the tool if:
#   - Active Maestro session in an execution phase
#   - The file is project source code (not .maestro/)
#   - The orchestrator is trying to implement directly

STATE_FILE=".maestro/state.local.md"

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat 2>/dev/null || true)
fi

# --- No state file? Allow (not a Maestro session) ---
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# --- Parse state frontmatter ---
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || true)

yaml_val() {
  local key="$1"
  local line
  line=$(printf '%s\n' "$FRONTMATTER" | grep -E "^${key}:" | head -1)
  [[ -z "$line" ]] && echo "" && return
  local val="${line#*:}"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%\"}" ; val="${val#\"}"
  val="${val%\'}" ; val="${val#\'}"
  printf '%s' "$val"
}

ACTIVE=$(yaml_val "active")
PHASE=$(yaml_val "phase")
LAYER=$(yaml_val "layer")

# --- Not active? Allow ---
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# --- Parse tool input to check what file is being edited ---
FILE_PATH=""
if [[ -n "$HOOK_INPUT" ]]; then
  # Extract file_path from the tool input JSON
  FILE_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.input.file_path // empty' 2>/dev/null || true)
fi

# --- Allow writes to .maestro/ directory (state management) ---
if [[ -n "$FILE_PATH" ]] && [[ "$FILE_PATH" == *".maestro/"* || "$FILE_PATH" == *"/.maestro/"* ]]; then
  exit 0
fi

# --- Allow writes to CLAUDE.md files (project config) ---
if [[ -n "$FILE_PATH" ]] && [[ "$(basename "$FILE_PATH")" == "CLAUDE.md" ]]; then
  exit 0
fi

# --- Check if we're in a planning/non-execution phase ---
# These phases involve the orchestrator writing plans, not code:
case "$PHASE" in
  decompose|research|milestone_start|checkpoint|paused|completed|aborted|milestone_checkpoint|opus_planning|opus_interview|opus_research|opus_roadmap)
    exit 0
    ;;
esac

# --- In execution phase: BLOCK direct file edits ---
# The orchestrator should be dispatching agents, not editing code directly.

TOOL_NAME=""
if [[ -n "$HOOK_INPUT" ]]; then
  TOOL_NAME=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
fi

# Build a helpful rejection message
REASON="[MAESTRO] The orchestrator cannot edit files directly during active execution (phase: ${PHASE})."
REASON="${REASON} Cause: delegation means code changes must flow through isolated implementer agents in worktrees — this prevents the orchestrator from drifting into implementation and losing its coordination context."
REASON="${REASON} Fix: use Agent(subagent_type: 'maestro:maestro-implementer', isolation: 'worktree') to dispatch an implementer agent instead of calling ${TOOL_NAME:-Edit/Write} directly."

if [[ -n "$FILE_PATH" ]]; then
  REASON="${REASON} Attempted to modify: ${FILE_PATH}"
fi

# Output the block decision
jq -n \
  --arg reason "$REASON" \
  '{
    "decision": "block",
    "reason": $reason
  }'

exit 0
