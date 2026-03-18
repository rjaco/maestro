#!/usr/bin/env bash
# StopFailure hook — Doom-loop fallback handler
# Fires when API errors occur during an active Maestro session.
# Increments doom_loop.count and logs the failure for analysis.

set -euo pipefail

STATE_FILE=".maestro/state.local.md"
LOG_DIR=".maestro/logs"
LOG_FILE="${LOG_DIR}/doom-loop.md"

# Only act if we have an active Maestro session
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Check if session is active
ACTIVE=$(grep -m1 "^active:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "false")
if [ "$ACTIVE" != "true" ]; then
  exit 0
fi

# Read error info from stdin (JSON)
INPUT=$(cat)
# Parse error type without python3 — pure bash/grep
ERROR_TYPE=$(printf '%s' "$INPUT" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "unknown")

# Get current doom_loop count
CURRENT_COUNT=$(grep -m1 "doom_loop_count:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "0")
NEW_COUNT=$((CURRENT_COUNT + 2))

# Get current story info
CURRENT_STORY=$(grep -m1 "current_story:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "unknown")
CURRENT_PHASE=$(grep -m1 "phase:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "unknown")

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Log the failure
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat >> "$LOG_FILE" << EOF

## StopFailure — ${TIMESTAMP}
- Error: ${ERROR_TYPE}
- Story: ${CURRENT_STORY}
- Phase: ${CURRENT_PHASE}
- doom_loop.count: ${CURRENT_COUNT} → ${NEW_COUNT}
EOF

# Determine intervention level
LEVEL=0
if [ "$NEW_COUNT" -ge 8 ]; then
  LEVEL=3
elif [ "$NEW_COUNT" -ge 5 ]; then
  LEVEL=2
elif [ "$NEW_COUNT" -ge 3 ]; then
  LEVEL=1
fi

# Output system message for Claude to see
if [ "$LEVEL" -ge 2 ]; then
  echo "{\"systemMessage\": \"[DOOM-LOOP] API failure detected (${ERROR_TYPE}). doom_loop.count=${NEW_COUNT}, intervention_level=${LEVEL}. Consider pausing or escalating.\"}"
fi
