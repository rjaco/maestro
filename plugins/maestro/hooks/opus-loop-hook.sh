#!/usr/bin/env bash

# Maestro Opus Loop Hook
# Prevents session exit during active Opus sessions.
# Re-injects the Opus orchestration prompt to continue the autonomous loop.
# Inspired by Ralph Loop's self-referential stop hook pattern.

# NOTE: Intentionally no set -euo pipefail — this hook must never crash.
# Failing subcommands are handled via || true patterns.

# Error handler — log but never block (fail-open: approve on error)
_hook_error_handler() {
  local exit_code=$?
  local line_no=$1
  local hook_name
  hook_name="$(basename "${BASH_SOURCE[0]}")"
  local log_dir="${MAESTRO_LOG_DIR:-.maestro/logs}"
  mkdir -p "$log_dir" 2>/dev/null || true
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: ${hook_name}:${line_no} exited with code ${exit_code}" >> "$log_dir/hooks.log" 2>/dev/null || true
  # Fail-open: approve on error so broken hook doesn't block user
  printf '{"decision":"approve","reason":"hook error fallback"}\n'
  exit 0
}
trap '_hook_error_handler $LINENO' ERR

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(</dev/stdin)
fi

STATE_FILE=".maestro/state.local.md"
HEARTBEAT_FILE=".maestro/logs/heartbeat"
VISION_FILE=".maestro/vision.md"

# ---------------------------------------------------------------------------
# Helper: approve and exit
# ---------------------------------------------------------------------------
approve() {
  local reason="$1"
  printf '{"decision":"approve","reason":"%s"}\n' "$reason"
  exit 0
}

# ---------------------------------------------------------------------------
# Robustness: no state file → approve exit (not a crash)
# ---------------------------------------------------------------------------
if [[ ! -f "$STATE_FILE" ]]; then
  approve "No Maestro state"
fi

# ---------------------------------------------------------------------------
# Parse YAML frontmatter
# ---------------------------------------------------------------------------
FRONTMATTER=""
if ! FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null); then
  approve "Could not parse state file"
fi

yaml_val() {
  local key="$1"
  printf '%s\n' "$FRONTMATTER" \
    | grep "^${key}:" \
    | head -1 \
    | sed "s/^${key}:[[:space:]]*//" \
    | sed 's/^"\(.*\)"$/\1/' \
    | sed "s/^'\(.*\)'$/\1/" \
    | xargs 2>/dev/null \
    || true
}

ACTIVE=$(yaml_val "active")
LAYER=$(yaml_val "layer")
PHASE=$(yaml_val "phase")
OPUS_MODE=$(yaml_val "opus_mode")
FEATURE=$(yaml_val "feature")
CURRENT_MILESTONE=$(yaml_val "current_milestone")
TOTAL_MILESTONES=$(yaml_val "total_milestones")
CURRENT_STORY=$(yaml_val "current_story")
TOTAL_STORIES=$(yaml_val "total_stories")
TOKEN_SPEND=$(yaml_val "token_spend")
TOKEN_BUDGET=$(yaml_val "token_budget")
CONSECUTIVE_FAILURES=$(yaml_val "consecutive_failures")
MAX_CONSECUTIVE_FAILURES=$(yaml_val "max_consecutive_failures")
SESSION_ID=$(yaml_val "session_id")
LOOP_ITERATION=$(yaml_val "loop_iteration")

# ---------------------------------------------------------------------------
# Session isolation — only loop for the session that started the Opus run
# ---------------------------------------------------------------------------
HOOK_SESSION=""
if [[ -n "$HOOK_INPUT" ]]; then
  HOOK_SESSION=$(printf '%s\n' "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)
fi
if [[ -n "$SESSION_ID" ]] && [[ -n "$HOOK_SESSION" ]] && [[ "$SESSION_ID" != "$HOOK_SESSION" ]]; then
  approve "Different session"
fi

# ---------------------------------------------------------------------------
# Not active? Allow exit.
# ---------------------------------------------------------------------------
if [[ "$ACTIVE" != "true" ]]; then
  approve "Session not active"
fi

# ---------------------------------------------------------------------------
# Not an Opus session? Let the regular stop-hook handle it.
# ---------------------------------------------------------------------------
if [[ "$LAYER" != "opus" ]]; then
  approve "Not an Opus session"
fi

# ---------------------------------------------------------------------------
# Completed, aborted, or paused? Allow exit.
# ---------------------------------------------------------------------------
case "$PHASE" in
  completed|aborted)
    approve "Opus session ${PHASE}"
    ;;
  paused)
    approve "Opus session paused"
    ;;
esac

# ---------------------------------------------------------------------------
# Safety valve: token budget exceeded
# ---------------------------------------------------------------------------
if [[ -n "$TOKEN_BUDGET" ]] && [[ "$TOKEN_BUDGET" != "0" ]] && [[ -n "$TOKEN_SPEND" ]]; then
  BUDGET_NUM=$(printf '%s\n' "$TOKEN_BUDGET" | tr -dc '0-9')
  SPEND_NUM=$(printf '%s\n' "$TOKEN_SPEND" | tr -dc '0-9')
  if [[ -n "$BUDGET_NUM" ]] && [[ -n "$SPEND_NUM" ]] && [[ "$SPEND_NUM" -ge "$BUDGET_NUM" ]]; then
    approve "Opus token budget exhausted"
  fi
fi

# ---------------------------------------------------------------------------
# Safety valve: consecutive failures
# ---------------------------------------------------------------------------
if [[ -n "$CONSECUTIVE_FAILURES" ]] && [[ -n "$MAX_CONSECUTIVE_FAILURES" ]]; then
  FAIL_NUM=$(printf '%s\n' "$CONSECUTIVE_FAILURES" | tr -dc '0-9')
  MAX_FAIL=$(printf '%s\n' "$MAX_CONSECUTIVE_FAILURES" | tr -dc '0-9')
  if [[ -n "$FAIL_NUM" ]] && [[ -n "$MAX_FAIL" ]] && [[ "$FAIL_NUM" -ge "$MAX_FAIL" ]]; then
    approve "Opus max consecutive failures reached"
  fi
fi

# ---------------------------------------------------------------------------
# === OPUS MODE CHECK ===
# Only loop in full_auto or until_pause mode.
# ---------------------------------------------------------------------------
case "$OPUS_MODE" in
  full_auto|until_pause)
    # Continue the loop — fall through to build the re-injection prompt
    ;;
  *)
    # milestone_pause, budget_cap, time_cap — let the regular stop hook handle
    approve "Opus mode ${OPUS_MODE} allows exit"
    ;;
esac

# ---------------------------------------------------------------------------
# === HEARTBEAT ===
# Write timestamp so the daemon can detect stalls.
# ---------------------------------------------------------------------------
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p ".maestro/logs"
printf '%s\n' "$NOW" > "$HEARTBEAT_FILE"

# ---------------------------------------------------------------------------
# === LOOP ITERATION COUNTER ===
# Read, increment, write back.
# ---------------------------------------------------------------------------
ITER_NUM=0
if [[ -n "$LOOP_ITERATION" ]]; then
  ITER_NUM=$(printf '%s\n' "$LOOP_ITERATION" | tr -dc '0-9')
fi
ITER_NUM=$(( ITER_NUM + 1 ))

# Update loop_iteration in state file (and last_updated)
TEMP_FILE="${STATE_FILE}.tmp.$$"
if sed \
  -e "s/^loop_iteration: .*/loop_iteration: ${ITER_NUM}/" \
  -e "s/^last_updated: .*/last_updated: \"${NOW}\"/" \
  "$STATE_FILE" > "$TEMP_FILE" 2>/dev/null; then
  mv "$TEMP_FILE" "$STATE_FILE"
else
  rm -f "$TEMP_FILE"
fi

# ---------------------------------------------------------------------------
# === INLINE VISION SUMMARY ===
# Read the first 3 lines after the frontmatter — embed the actual text.
# ---------------------------------------------------------------------------
VISION_SUMMARY=""
if [[ -f "$VISION_FILE" ]]; then
  # Skip frontmatter (lines between first and second "---"), then read 3 lines
  VISION_SUMMARY=$(awk '
    /^---$/ { delim++; if (delim == 2) { skip = 0; next } else { skip = 1; next } }
    skip { next }
    NF { lines++; print; if (lines == 3) exit }
  ' "$VISION_FILE" 2>/dev/null | tr '\n' ' ')
fi
if [[ -z "$VISION_SUMMARY" ]]; then
  VISION_SUMMARY="(vision not available)"
fi

# ---------------------------------------------------------------------------
# === MILESTONE ACCEPTANCE CRITERIA ===
# Read from .maestro/milestones/ for the current milestone.
# ---------------------------------------------------------------------------
MILESTONE_AC=""
MILESTONE_FILE=""
if [[ -n "$CURRENT_MILESTONE" ]] && [[ -d ".maestro/milestones" ]]; then
  # Find a file matching M<current_milestone>-*.md (case-insensitive on number)
  MILESTONE_FILE=$(find ".maestro/milestones" -maxdepth 1 -name "M${CURRENT_MILESTONE}-*.md" 2>/dev/null | head -1)
fi
if [[ -n "$MILESTONE_FILE" ]] && [[ -f "$MILESTONE_FILE" ]]; then
  # Extract the Acceptance Criteria section (up to next ##)
  MILESTONE_AC=$(awk '
    /^## Acceptance Criteria/ { in_ac = 1; next }
    in_ac && /^##/ { exit }
    in_ac { print }
  ' "$MILESTONE_FILE" 2>/dev/null | tr '\n' ' ')
fi
if [[ -z "$MILESTONE_AC" ]]; then
  MILESTONE_AC="(milestone AC not available)"
fi

# ---------------------------------------------------------------------------
# === ESCALATION DIRECTIVE ===
# After 3+ iterations, escalate with a critical directive.
# ---------------------------------------------------------------------------
ESCALATION=""
if [[ "$ITER_NUM" -ge 3 ]]; then
  ESCALATION="CRITICAL: You MUST execute the next story immediately. Dispatch an Agent with isolation: worktree NOW. Do not pause, do not ask for confirmation. The loop_iteration counter is at ${ITER_NUM} — act now or the session will stall."
fi

# ---------------------------------------------------------------------------
# === BUILD THE LOOP PROMPT ===
# ---------------------------------------------------------------------------
SYSTEM_MSG="Maestro Opus autonomous loop active (iteration ${ITER_NUM})."
SYSTEM_MSG="${SYSTEM_MSG} Feature: ${FEATURE:-unknown}."
SYSTEM_MSG="${SYSTEM_MSG} Milestone: ${CURRENT_MILESTONE:-?}/${TOTAL_MILESTONES:-?}."
SYSTEM_MSG="${SYSTEM_MSG} Story: ${CURRENT_STORY:-?}/${TOTAL_STORIES:-?}."
SYSTEM_MSG="${SYSTEM_MSG} Phase: ${PHASE:-unknown}."
SYSTEM_MSG="${SYSTEM_MSG} Mode: ${OPUS_MODE:-full_auto}."
SYSTEM_MSG="${SYSTEM_MSG} Vision: ${VISION_SUMMARY}"
SYSTEM_MSG="${SYSTEM_MSG} M${CURRENT_MILESTONE:-?} AC: ${MILESTONE_AC}"
SYSTEM_MSG="${SYSTEM_MSG} Do NOT stop. Execute the next story. Dispatch implementer agents in worktrees."
SYSTEM_MSG="${SYSTEM_MSG} Run validation, QA review, git craft."
SYSTEM_MSG="${SYSTEM_MSG} If all milestones complete, set phase: completed and active: false."
if [[ -n "$ESCALATION" ]]; then
  SYSTEM_MSG="${SYSTEM_MSG} ${ESCALATION}"
fi

LOOP_PROMPT="Continue the Maestro Opus autonomous loop (iteration ${ITER_NUM})."
LOOP_PROMPT="${LOOP_PROMPT} NORTH STAR: ${FEATURE:-Continue building}."
LOOP_PROMPT="${LOOP_PROMPT} Vision summary: ${VISION_SUMMARY}"
LOOP_PROMPT="${LOOP_PROMPT} Current milestone: ${CURRENT_MILESTONE:-1}/${TOTAL_MILESTONES:-?}."
LOOP_PROMPT="${LOOP_PROMPT} M${CURRENT_MILESTONE:-?} acceptance criteria: ${MILESTONE_AC}"
LOOP_PROMPT="${LOOP_PROMPT} Current phase: ${PHASE:-opus_executing}. Story: ${CURRENT_STORY:-?}/${TOTAL_STORIES:-?}."
LOOP_PROMPT="${LOOP_PROMPT} Read .maestro/state.local.md for full state."
LOOP_PROMPT="${LOOP_PROMPT} Execute the next story or milestone now."
LOOP_PROMPT="${LOOP_PROMPT} When all milestones are complete, set active: false and phase: completed."
if [[ -n "$ESCALATION" ]]; then
  LOOP_PROMPT="${LOOP_PROMPT} ${ESCALATION}"
fi

# ---------------------------------------------------------------------------
# Block the exit and re-inject the prompt
# ---------------------------------------------------------------------------
jq -n \
  --arg prompt "$LOOP_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
