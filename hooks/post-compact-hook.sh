#!/usr/bin/env bash
# PostCompact hook — Re-inject critical state after context compaction
# Fires after Claude Code compacts the conversation context.
# Ensures Maestro's session state, North Star, and memory survive compaction.

set -euo pipefail

STATE_FILE=".maestro/state.local.md"
VISION_FILE=".maestro/vision.md"
NOTES_FILE=".maestro/notes.md"

# Only act if we have an active Maestro session
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

ACTIVE=$(grep -m1 "^active:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "false")
if [ "$ACTIVE" != "true" ]; then
  exit 0
fi

# Build the re-injection message
MSG="[POST-COMPACT STATE RE-INJECTION]\n"

# 1. Current session state
FEATURE=$(grep -m1 "^feature:" "$STATE_FILE" 2>/dev/null | sed 's/^feature: //' || echo "unknown")
LAYER=$(grep -m1 "^layer:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "execution")
MODE=$(grep -m1 "^mode:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "checkpoint")
PHASE=$(grep -m1 "^phase:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "unknown")
CURRENT_STORY=$(grep -m1 "^current_story:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "0")
TOTAL_STORIES=$(grep -m1 "^total_stories:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "0")
MILESTONE=$(grep -m1 "^current_milestone:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "1")
TOTAL_MILESTONES=$(grep -m1 "^total_milestones:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "1")

MSG+="Feature: ${FEATURE}\n"
MSG+="Layer: ${LAYER} | Mode: ${MODE} | Phase: ${PHASE}\n"
MSG+="Story: ${CURRENT_STORY}/${TOTAL_STORIES} | Milestone: ${MILESTONE}/${TOTAL_MILESTONES}\n"

# 2. North Star from vision or state
if [ -f "$VISION_FILE" ]; then
  NORTH_STAR=$(grep -m1 "^## North Star" -A 2 "$VISION_FILE" 2>/dev/null | tail -1 || echo "")
  if [ -n "$NORTH_STAR" ]; then
    MSG+="NORTH STAR: ${NORTH_STAR}\n"
  fi
fi

# 3. Recent notes (last 5 lines)
if [ -f "$NOTES_FILE" ]; then
  RECENT_NOTES=$(tail -5 "$NOTES_FILE" 2>/dev/null || echo "")
  if [ -n "$RECENT_NOTES" ]; then
    MSG+="Recent notes:\n${RECENT_NOTES}\n"
  fi
fi

MSG+="Branch: development (never commit to main directly)\n"
MSG+="Read .maestro/state.local.md and .maestro/roadmap.md for full context."

# Output as system message
echo "{\"systemMessage\": \"$(echo -e "$MSG" | sed 's/"/\\"/g' | tr '\n' ' ')\"}"
