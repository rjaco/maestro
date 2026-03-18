#!/usr/bin/env bash
set -euo pipefail

# Maestro SessionStart Hook
# Detects Maestro state and injects context at session start.
# Lets every new session know if Maestro is initialized and what state it's in.

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat 2>/dev/null || true)
fi

# Get working directory
CWD=""
if [[ -n "$HOOK_INPUT" ]]; then
  CWD=$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
CWD="${CWD:-$(pwd)}"

DNA_FILE="$CWD/.maestro/dna.md"
STATE_FILE="$CWD/.maestro/state.local.md"

# No Maestro initialization? Silent exit.
if [[ ! -f "$DNA_FILE" ]]; then
  exit 0
fi

# Build context message
MSG=""

# Check for active session
if [[ -f "$STATE_FILE" ]]; then
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
  FEATURE=$(yaml_val "feature")
  PHASE=$(yaml_val "phase")
  LAYER=$(yaml_val "layer")
  CURRENT_STORY=$(yaml_val "current_story")
  TOTAL_STORIES=$(yaml_val "total_stories")
  CURRENT_MILESTONE=$(yaml_val "current_milestone")
  TOTAL_MILESTONES=$(yaml_val "total_milestones")

  if [[ "$ACTIVE" == "true" ]]; then
    MSG="Maestro has an ACTIVE session."
    MSG="$MSG Feature: ${FEATURE:-unknown}."
    MSG="$MSG Phase: ${PHASE:-unknown}."

    if [[ "$LAYER" == "opus" ]]; then
      MSG="$MSG Mode: Magnum Opus."
      MSG="$MSG Milestone: ${CURRENT_MILESTONE:-?}/${TOTAL_MILESTONES:-?}."
    fi

    if [[ -n "$TOTAL_STORIES" ]] && [[ "$TOTAL_STORIES" != "0" ]]; then
      MSG="$MSG Story: ${CURRENT_STORY:-?}/${TOTAL_STORIES}."
    fi

    MSG="$MSG Use /maestro status for details or /maestro opus --resume to continue."
  elif [[ "$PHASE" == "completed" ]]; then
    MSG="Maestro: last session completed (${FEATURE:-unknown}). Run /maestro for a new task."
  elif [[ "$PHASE" == "paused" ]]; then
    MSG="Maestro: PAUSED session (${FEATURE:-unknown})."
    if [[ "$LAYER" == "opus" ]]; then
      MSG="$MSG Resume with /maestro opus --resume."
    else
      MSG="$MSG Resume with /maestro status."
    fi
  fi
else
  MSG="Maestro initialized for this project. Use /maestro to start orchestrating."
fi

# Only output if we have something to say
if [[ -n "$MSG" ]]; then
  # SessionStart hooks output is injected as a system message
  printf '%s' "$MSG"
fi

exit 0
