#!/usr/bin/env bash
set -euo pipefail

# Maestro UserPromptSubmit Hook — Prompt Inject
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
# Injects a compact Maestro context block into system context on every user prompt.
# Must complete in < 100ms. Silent exit when no active session.

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat 2>/dev/null || true)
fi

# Skip injection in CI mode
if [[ "${CI:-}" == "true" ]] || [[ "${MAESTRO_CI:-}" == "true" ]]; then
  exit 0
fi

# Get working directory
CWD=""
if [[ -n "$HOOK_INPUT" ]]; then
  CWD=$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
CWD="${CWD:-$(pwd)}"

# Skip if /btw prompt (ambient background note — Maestro-agnostic by design)
if [[ -n "$HOOK_INPUT" ]]; then
  PROMPT_TEXT=$(printf '%s' "$HOOK_INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
  FIRST_WORD="${PROMPT_TEXT%%[[:space:]]*}"
  if [[ "$FIRST_WORD" == "/btw" ]]; then
    exit 0
  fi
fi

DNA_FILE="$CWD/.maestro/dna.md"
STATE_FILE="$CWD/.maestro/state.local.md"
SQUAD_FILE="$CWD/.maestro/squad.yaml"

# No Maestro installation? Silent exit.
if [[ ! -f "$DNA_FILE" ]]; then
  exit 0
fi

# No state file? Silent exit.
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse frontmatter from state file
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

# No active session? Silent exit.
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

FEATURE=$(yaml_val "feature")
PHASE=$(yaml_val "phase")
CURRENT_STORY=$(yaml_val "current_story")
TOTAL_STORIES=$(yaml_val "total_stories")
CURRENT_MILESTONE=$(yaml_val "current_milestone")
TOTAL_MILESTONES=$(yaml_val "total_milestones")
LAYER=$(yaml_val "layer")

# Build session attributes
SESSION_ATTRS="active=\"true\""
[[ -n "$FEATURE" ]] && SESSION_ATTRS="$SESSION_ATTRS feature=\"${FEATURE}\""
[[ -n "$PHASE" ]]   && SESSION_ATTRS="$SESSION_ATTRS phase=\"${PHASE}\""

# Build progress attributes
PROGRESS_ATTRS=""
if [[ -n "$CURRENT_STORY" ]] && [[ -n "$TOTAL_STORIES" ]] && [[ "$TOTAL_STORIES" != "0" ]]; then
  PROGRESS_ATTRS="story=\"${CURRENT_STORY}/${TOTAL_STORIES}\""
fi
if [[ "$LAYER" == "opus" ]] && [[ -n "$CURRENT_MILESTONE" ]] && [[ -n "$TOTAL_MILESTONES" ]]; then
  PROGRESS_ATTRS="$PROGRESS_ATTRS milestone=\"${CURRENT_MILESTONE}/${TOTAL_MILESTONES}\""
fi

# Read squad info if available
SQUAD_ATTRS=""
if [[ -f "$SQUAD_FILE" ]]; then
  SQUAD_NAME=$(grep -E "^name:" "$SQUAD_FILE" | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"'"'" 2>/dev/null || true)
  if [[ -n "$SQUAD_NAME" ]]; then
    SQUAD_ATTRS="name=\"${SQUAD_NAME}\""
  fi
fi

# Emit compact XML context block
OUTPUT="<maestro-context>"
OUTPUT="$OUTPUT<session ${SESSION_ATTRS} />"
[[ -n "$PROGRESS_ATTRS" ]] && OUTPUT="$OUTPUT<progress ${PROGRESS_ATTRS} />"
[[ -n "$SQUAD_ATTRS" ]]    && OUTPUT="$OUTPUT<squad ${SQUAD_ATTRS} />"
OUTPUT="$OUTPUT<soul ship-working-code=\"true\" tdd=\"true\" minimal-changes=\"true\" ask-on-doubt=\"true\" /></maestro-context>"

printf '%s' "$OUTPUT"
exit 0
