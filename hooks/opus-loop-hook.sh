#!/bin/bash

# Maestro Opus Loop Hook
# Prevents session exit during active Opus sessions.
# Re-injects the Opus orchestration prompt to continue the autonomous loop.
# Inspired by Ralph Loop's self-referential stop hook pattern.

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat)
fi

STATE_FILE=".maestro/state.local.md"

# No state file? Allow exit.
if [[ ! -f "$STATE_FILE" ]]; then
  printf '{"decision":"approve","reason":"No Maestro state"}\n'
  exit 0
fi

# Parse frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null)

yaml_val() {
  local key="$1"
  echo "$FRONTMATTER" | grep "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | xargs 2>/dev/null || echo ""
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

# Session isolation — only loop for the session that started the Opus run
HOOK_SESSION=""
if [[ -n "$HOOK_INPUT" ]]; then
  HOOK_SESSION=$(echo "$HOOK_INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || true)
fi
if [[ -n "$SESSION_ID" ]] && [[ -n "$HOOK_SESSION" ]] && [[ "$SESSION_ID" != "$HOOK_SESSION" ]]; then
  printf '{"decision":"approve","reason":"Different session"}\n'
  exit 0
fi

# Not active? Allow exit.
if [[ "$ACTIVE" != "true" ]]; then
  printf '{"decision":"approve","reason":"Session not active"}\n'
  exit 0
fi

# Not an Opus session? Let the regular stop-hook handle it.
if [[ "$LAYER" != "opus" ]]; then
  printf '{"decision":"approve","reason":"Not an Opus session"}\n'
  exit 0
fi

# Completed or aborted? Allow exit.
case "$PHASE" in
  completed|aborted)
    printf '{"decision":"approve","reason":"Opus session %s"}\n' "$PHASE"
    exit 0
    ;;
esac

# Paused? Allow exit (user requested pause).
if [[ "$PHASE" == "paused" ]]; then
  printf '{"decision":"approve","reason":"Opus session paused"}\n'
  exit 0
fi

# Safety valve: token budget exceeded
if [[ -n "$TOKEN_BUDGET" ]] && [[ "$TOKEN_BUDGET" != "0" ]] && [[ -n "$TOKEN_SPEND" ]]; then
  BUDGET_NUM=$(echo "$TOKEN_BUDGET" | tr -dc '0-9')
  SPEND_NUM=$(echo "$TOKEN_SPEND" | tr -dc '0-9')
  if [[ -n "$BUDGET_NUM" ]] && [[ -n "$SPEND_NUM" ]] && [[ "$SPEND_NUM" -ge "$BUDGET_NUM" ]]; then
    printf '{"decision":"approve","reason":"Opus token budget exhausted"}\n'
    exit 0
  fi
fi

# Safety valve: consecutive failures
if [[ -n "$CONSECUTIVE_FAILURES" ]] && [[ -n "$MAX_CONSECUTIVE_FAILURES" ]]; then
  FAIL_NUM=$(echo "$CONSECUTIVE_FAILURES" | tr -dc '0-9')
  MAX_FAIL=$(echo "$MAX_CONSECUTIVE_FAILURES" | tr -dc '0-9')
  if [[ -n "$FAIL_NUM" ]] && [[ -n "$MAX_FAIL" ]] && [[ "$FAIL_NUM" -ge "$MAX_FAIL" ]]; then
    printf '{"decision":"approve","reason":"Opus max consecutive failures reached"}\n'
    exit 0
  fi
fi

# === OPUS MODE CHECK ===
# Only loop in full_auto or until_pause mode.
# milestone_pause mode: allow exit (user will resume manually).
case "$OPUS_MODE" in
  full_auto|until_pause)
    # Continue the loop — build the re-injection prompt
    ;;
  *)
    # milestone_pause, budget_cap, time_cap — let the regular stop hook handle
    printf '{"decision":"approve","reason":"Opus mode %s allows exit"}\n' "$OPUS_MODE"
    exit 0
    ;;
esac

# === BUILD THE LOOP PROMPT ===
# This is the key: re-inject the Opus orchestration prompt so Claude
# continues working on the next milestone/story automatically.

SYSTEM_MSG="Maestro Opus autonomous loop active."
SYSTEM_MSG="$SYSTEM_MSG Feature: ${FEATURE:-unknown}."
SYSTEM_MSG="$SYSTEM_MSG Milestone: ${CURRENT_MILESTONE:-?}/${TOTAL_MILESTONES:-?}."
SYSTEM_MSG="$SYSTEM_MSG Story: ${CURRENT_STORY:-?}/${TOTAL_STORIES:-?}."
SYSTEM_MSG="$SYSTEM_MSG Phase: ${PHASE:-unknown}."
SYSTEM_MSG="$SYSTEM_MSG Mode: full_auto."
SYSTEM_MSG="$SYSTEM_MSG Do NOT stop. Continue the Opus loop."
SYSTEM_MSG="$SYSTEM_MSG Re-read .maestro/vision.md for North Star."
SYSTEM_MSG="$SYSTEM_MSG Execute the next milestone/story via the dev-loop."
SYSTEM_MSG="$SYSTEM_MSG Dispatch implementer agents in worktrees."
SYSTEM_MSG="$SYSTEM_MSG Run validation, QA review, git craft."
SYSTEM_MSG="$SYSTEM_MSG If all milestones complete, set phase: completed and active: false."

LOOP_PROMPT="Continue the Maestro Opus autonomous loop."
LOOP_PROMPT="$LOOP_PROMPT NORTH STAR: ${FEATURE:-Continue building}."
LOOP_PROMPT="$LOOP_PROMPT Current milestone: ${CURRENT_MILESTONE:-1}/${TOTAL_MILESTONES:-?}."
LOOP_PROMPT="$LOOP_PROMPT Current phase: ${PHASE:-opus_executing}."
LOOP_PROMPT="$LOOP_PROMPT Read .maestro/state.local.md for full state."
LOOP_PROMPT="$LOOP_PROMPT Read .maestro/vision.md for vision."
LOOP_PROMPT="$LOOP_PROMPT Execute the next story or milestone."
LOOP_PROMPT="$LOOP_PROMPT When all milestones are complete, set active: false and phase: completed."

# Update timestamp
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^last_updated: .*/last_updated: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Block the exit and re-inject the prompt
# Escape special JSON characters in prompt and system message
LOOP_PROMPT_ESC=$(printf '%s' "$LOOP_PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
SYSTEM_MSG_ESC=$(printf '%s' "$SYSTEM_MSG" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
printf '{"decision":"block","reason":"%s","systemMessage":"%s"}\n' "$LOOP_PROMPT_ESC" "$SYSTEM_MSG_ESC"

exit 0
