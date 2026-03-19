#!/usr/bin/env bash
# Maestro Status Line for Claude Code
# Displays model name, context percentage, and Maestro session status.
#
# Install: Add to settings.json:
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/plugins/cache/maestro-orchestrator/maestro/1.0.0/scripts/statusline.sh"
#   }
#
# Output formats:
#   Opus session active:       [Opus 4.6] 42% ctx | Maestro M2/7 S3/5 opus
#   Maestro initialized:       [Opus 4.6] 42% ctx | Maestro v1.4.0 (109 skills)
#   Maestro not initialized:   [Opus 4.6] 42% ctx

set -euo pipefail

# --- Read JSON from stdin (pure bash, no jq, no python) ---
SESSION_JSON=""
if [[ ! -t 0 ]]; then
  SESSION_JSON=$(cat 2>/dev/null || true)
fi

# --- Parse model display name from JSON ---
# Input: {"model": {"display_name": "Opus 4.6"}, ...}
MODEL_NAME=""
if [[ -n "$SESSION_JSON" ]]; then
  MODEL_NAME=$(printf '%s' "$SESSION_JSON" \
    | grep -o '"display_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
    2>/dev/null || true)
fi
MODEL_NAME="${MODEL_NAME:-Claude}"

# --- Parse context used_percentage from JSON ---
# Input: {"context_window": {"used_percentage": 42, ...}, ...}
CTX_PCT=""
if [[ -n "$SESSION_JSON" ]]; then
  CTX_PCT=$(printf '%s' "$SESSION_JSON" \
    | grep -o '"used_percentage"[[:space:]]*:[[:space:]]*[0-9]*' \
    | head -1 \
    | grep -o '[0-9]*$' \
    2>/dev/null || true)
fi
CTX_PCT="${CTX_PCT:-0}"

# --- Base output: [Model] CTX% ctx ---
BASE_OUTPUT="[${MODEL_NAME}] ${CTX_PCT}% ctx"

# --- Locate git project root for Maestro state files ---
PROJECT_ROOT=""
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)

DNA_FILE="${PROJECT_ROOT}/.maestro/dna.md"
STATE_FILE="${PROJECT_ROOT}/.maestro/state.local.md"

# --- No Maestro at all ---
if [[ -z "$PROJECT_ROOT" || ! -f "$DNA_FILE" ]]; then
  printf '%s\n' "$BASE_OUTPUT"
  exit 0
fi

# --- Caching for state file reads (5s TTL) ---
CACHE_FILE="${TMPDIR:-/tmp}/maestro-statusline-cache-$(id -u)"
CACHE_TTL=5
MAESTRO_STATUS=""

if [[ -f "$CACHE_FILE" ]]; then
  # Cross-platform mtime: try Linux stat first, then macOS stat
  CACHE_AGE=$(( $(date +%s) - $(stat -c%Y "$CACHE_FILE" 2>/dev/null || stat -f%m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [[ "$CACHE_AGE" -lt "$CACHE_TTL" ]]; then
    MAESTRO_STATUS=$(cat "$CACHE_FILE" 2>/dev/null || true)
  fi
fi

if [[ -z "$MAESTRO_STATUS" ]]; then
  # --- Build Maestro status string ---

  if [[ -f "$STATE_FILE" ]]; then
    # Parse state frontmatter (pure bash with sed/grep)
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null | sed '1d;$d' || true)

    yaml_val() {
      local key="$1"
      printf '%s\n' "$frontmatter" \
        | grep -E "^${key}:" \
        | head -1 \
        | sed "s/^${key}:[[:space:]]*//" \
        | sed 's/^"\(.*\)"$/\1/' \
        | sed "s/^'\(.*\)'$/\1/" \
        | xargs 2>/dev/null \
        || echo ""
    }

    active=$(yaml_val "active")
    milestone=$(yaml_val "milestone")
    total_milestones=$(yaml_val "total_milestones")
    current_story=$(yaml_val "current_story")
    total_stories=$(yaml_val "total_stories")
    layer=$(yaml_val "layer")

    if [[ "$active" == "true" ]]; then
      # Active Opus session: Maestro M2/7 S3/5 opus
      SESSION_PART="Maestro"

      if [[ -n "$milestone" && -n "$total_milestones" && "$total_milestones" != "0" ]]; then
        SESSION_PART="${SESSION_PART} M${milestone}/${total_milestones}"
      fi

      if [[ -n "$current_story" && -n "$total_stories" && "$total_stories" != "0" ]]; then
        SESSION_PART="${SESSION_PART} S${current_story}/${total_stories}"
      fi

      if [[ -n "$layer" ]]; then
        SESSION_PART="${SESSION_PART} ${layer}"
      fi

      MAESTRO_STATUS="$SESSION_PART"
    fi
    # If state exists but active != true, fall through to initialized (no-session) display
  fi

  # --- Fallback: Maestro initialized but no active session ---
  if [[ -z "$MAESTRO_STATUS" ]]; then
    # Parse version from dna.md frontmatter
    MAESTRO_VERSION=""
    MAESTRO_VERSION=$(grep -E "^maestro_version:" "$DNA_FILE" 2>/dev/null \
      | head -1 \
      | sed 's/^maestro_version:[[:space:]]*//' \
      | sed 's/^"\(.*\)"$/\1/' \
      | sed "s/^'\(.*\)'$/\1/" \
      | xargs 2>/dev/null \
      || true)
    MAESTRO_VERSION="${MAESTRO_VERSION:-1.4.0}"

    # Count skills by counting .md files in the skills directory
    SKILLS_DIR="${PROJECT_ROOT}/skills"
    SKILL_COUNT=0
    if [[ -d "$SKILLS_DIR" ]]; then
      SKILL_COUNT=$(find "$SKILLS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | xargs)
    fi

    if [[ "$SKILL_COUNT" -gt 0 ]]; then
      MAESTRO_STATUS="Maestro v${MAESTRO_VERSION} (${SKILL_COUNT} skills)"
    else
      MAESTRO_STATUS="Maestro v${MAESTRO_VERSION}"
    fi
  fi

  # Write to cache
  printf '%s' "$MAESTRO_STATUS" > "$CACHE_FILE" 2>/dev/null || true
fi

# --- Output final status line ---
if [[ -n "$MAESTRO_STATUS" ]]; then
  printf '%s | %s\n' "$BASE_OUTPUT" "$MAESTRO_STATUS"
else
  printf '%s\n' "$BASE_OUTPUT"
fi
