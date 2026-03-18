#!/usr/bin/env bash
# SessionStart hook — Re-inject critical Maestro state on session start.
# Fires on every session start (startup, resume, compact, clear).
# When source is "compact", outputs state summary to STDOUT for context injection.
# This is the correct pattern for post-compaction re-injection.

set -euo pipefail

STATE_FILE=".maestro/state.local.md"
VISION_FILE=".maestro/vision.md"

# Read hook input from stdin
INPUT=$(cat)

# Check if this is a post-compaction resume
SOURCE=$(echo "$INPUT" | grep -o '"source":[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' || echo "")

# Only act on compact source
if [ "$SOURCE" != "compact" ]; then
  exit 0
fi

# Only act if we have an active Maestro session
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

ACTIVE=$(grep -m1 "^active:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "false")
if [ "$ACTIVE" != "true" ]; then
  exit 0
fi

# Extract state fields
FEATURE=$(grep -m1 "^feature:" "$STATE_FILE" 2>/dev/null | sed 's/^feature:[[:space:]]*//' || echo "unknown")
LAYER=$(grep -m1 "^layer:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "execution")
MODE=$(grep -m1 "^mode:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "checkpoint")
PHASE=$(grep -m1 "^phase:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "unknown")
CURRENT_STORY=$(grep -m1 "^current_story:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "0")
TOTAL_STORIES=$(grep -m1 "^total_stories:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "0")
MILESTONE=$(grep -m1 "^current_milestone:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "1")
TOTAL_MILESTONES=$(grep -m1 "^total_milestones:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "1")

# Extract North Star from vision.md
NORTH_STAR=""
if [ -f "$VISION_FILE" ]; then
  NORTH_STAR=$(grep -m1 "^## North Star" -A 2 "$VISION_FILE" 2>/dev/null | tail -1 || echo "")
fi

# Output plain text to STDOUT — this gets injected as Claude's context
printf '[Maestro State Recovery]\n'
printf 'Feature: %s\n' "$FEATURE"
printf 'Mode: %s | Layer: %s | Phase: %s\n' "$MODE" "$LAYER" "$PHASE"
printf 'Story: %s/%s | Milestone: %s/%s\n' "$CURRENT_STORY" "$TOTAL_STORIES" "$MILESTONE" "$TOTAL_MILESTONES"
if [ -n "$NORTH_STAR" ]; then
  printf 'North Star: %s\n' "$NORTH_STAR"
fi
printf 'Branch: development\n'
printf 'Read .maestro/state.local.md for full state.\n'
