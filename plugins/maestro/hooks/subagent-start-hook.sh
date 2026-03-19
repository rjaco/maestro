#!/usr/bin/env bash
# Maestro SubagentStart Hook
# Fires when a subagent is spawned. Logs to instances directory and audit log.

set -euo pipefail

HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat 2>/dev/null || true)
fi

# Extract agent info
AGENT_ID=""
AGENT_TYPE=""
if [[ -n "$HOOK_INPUT" ]]; then
  AGENT_ID=$(printf '%s' "$HOOK_INPUT" | grep -o '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' 2>/dev/null || true)
  AGENT_TYPE=$(printf '%s' "$HOOK_INPUT" | grep -o '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' 2>/dev/null || true)
fi

# Log to instances directory
mkdir -p .maestro/logs
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "${TIMESTAMP} SubagentStart: ${AGENT_TYPE:-unknown} (${AGENT_ID:-unknown})" >> .maestro/logs/agents.log

exit 0
