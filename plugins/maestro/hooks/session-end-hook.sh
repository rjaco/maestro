#!/usr/bin/env bash
# Maestro SessionEnd Hook
# Fires when a Claude session ends. Cleans up temp files and logs summary.

set -euo pipefail

STATE_FILE=".maestro/state.local.md"

# Clean up temp files
rm -f .maestro/locks/*.lock 2>/dev/null || true

# Log session end
if [[ -f "$STATE_FILE" ]]; then
  mkdir -p .maestro/logs
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  FEATURE=$(grep -m1 "^feature:" "$STATE_FILE" 2>/dev/null | sed 's/^feature:[[:space:]]*//' || echo "unknown")
  echo "${TIMESTAMP} SessionEnd: ${FEATURE}" >> .maestro/logs/sessions.log
fi

exit 0
