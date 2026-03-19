#!/usr/bin/env bash
# PostCompact hook — Audit/logging only after context compaction.
# NOTE: This hook CANNOT inject context into Claude's conversation.
# Context re-injection after compaction is handled by the SessionStart hook
# with source: "compact". See session-start-hook.sh.

set -euo pipefail

STATE_FILE=".maestro/state.local.md"
LOG_DIR=".maestro/logs"

# Only act if we have an active Maestro session
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

ACTIVE=$(grep -m1 "^active:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "false")
if [ "$ACTIVE" != "true" ]; then
  exit 0
fi

# Log the compaction event for audit purposes
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FEATURE=$(grep -m1 "^feature:" "$STATE_FILE" 2>/dev/null | sed 's/^feature:[[:space:]]*//' || echo "unknown")
PHASE=$(grep -m1 "^phase:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "unknown")
CURRENT_STORY=$(grep -m1 "^current_story:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "0")
TOTAL_STORIES=$(grep -m1 "^total_stories:" "$STATE_FILE" 2>/dev/null | awk '{print $2}' || echo "0")

echo "${TIMESTAMP} [compact] feature=${FEATURE} phase=${PHASE} story=${CURRENT_STORY}/${TOTAL_STORIES}" >> "${LOG_DIR}/compact.log"

# Inform the user (via stderr) what was preserved through compaction
echo "[MAESTRO] Context compaction occurred during active session." >&2
echo "  → Cause: The conversation context exceeded Claude's window and was automatically summarized" >&2
echo "  → What was preserved: .maestro/state.local.md contains the full session state (feature, phase, story progress)" >&2
echo "  → Next step: The SessionStart hook will re-inject Maestro context automatically; no action needed unless the session stalls" >&2

# Exit cleanly — no stdout output (would be ignored anyway)
exit 0
