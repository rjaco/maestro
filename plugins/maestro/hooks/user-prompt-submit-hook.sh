#!/usr/bin/env bash
# Maestro UserPromptSubmit Hook
# Fires on every user prompt. Injects Maestro context (phase, milestone, story)
# into the prompt context so Claude always knows the Maestro state.

set -euo pipefail

STATE_FILE=".maestro/state.local.md"

# No state file? Nothing to inject.
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Parse active status
ACTIVE=$(grep -m1 "^active:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "false")
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# Extract key state
FEATURE=$(grep -m1 "^feature:" "$STATE_FILE" 2>/dev/null | sed 's/^feature:[[:space:]]*//' || echo "")
PHASE=$(grep -m1 "^phase:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "")
MILESTONE=$(grep -m1 "^current_milestone:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "")
STORY=$(grep -m1 "^current_story:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "")

# Inject as additional context (shows in Claude's system prompt)
echo "[Maestro] Active: ${FEATURE} | Phase: ${PHASE} | M${MILESTONE} S${STORY}"
