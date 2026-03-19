#!/usr/bin/env bash
# Maestro Session Start Hook
# Fires when a new Claude session starts in a Maestro project.
# If a DNA file exists, outputs context to prime the session.
# If no DNA file, exits silently.

set -euo pipefail

DNA_FILE=".maestro/dna.md"
STATE_FILE=".maestro/state.local.md"

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
  HOOK_INPUT=$(cat)
fi

# No DNA file? Exit silently.
if [[ ! -f "$DNA_FILE" ]]; then
  exit 0
fi

# Extract CWD from hook input if provided
CWD=""
if [[ -n "$HOOK_INPUT" ]]; then
  CWD=$(printf '%s' "$HOOK_INPUT" | grep -o '"cwd":"[^"]*"' | sed 's/"cwd":"//;s/"//' 2>/dev/null || true)
fi

# Build context message from DNA file
DNA_CONTENT=$(head -50 "$DNA_FILE" 2>/dev/null || true)

# Check for active state
ACTIVE_SESSION=""
if [[ -f "$STATE_FILE" ]]; then
  ACTIVE_SESSION=$(grep '^active:' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/active:[[:space:]]*//' | xargs 2>/dev/null || true)
fi

# Output context message to stdout
printf 'Maestro project context loaded from %s\n' "$DNA_FILE"
if [[ -n "$ACTIVE_SESSION" && "$ACTIVE_SESSION" == "true" ]]; then
  FEATURE=$(grep '^feature:' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/feature:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | xargs 2>/dev/null || true)
  printf 'Active Maestro session detected. Feature: %s\n' "${FEATURE:-unknown}"
fi

exit 0
