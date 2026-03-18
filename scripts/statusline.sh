#!/usr/bin/env bash
# Maestro Status Line for Claude Code
# Displays: phase, story progress, cost, trust level
# Uses ANSI colors + unicode progress bars
#
# Install: Add to settings.json:
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/plugins/cache/maestro-orchestrator/maestro/1.0.0/scripts/statusline.sh"
#   }

set -euo pipefail

# --- Colors ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
RED='\033[31m'
WHITE='\033[37m'
BG_BLUE='\033[44m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'

# --- Read session data from stdin (Claude Code sends JSON) ---
SESSION_DATA=""
if [[ ! -t 0 ]]; then
  SESSION_DATA=$(cat 2>/dev/null || true)
fi

# --- Find Maestro state ---
# Look for .maestro/state.local.md in the working directory
CWD=""
if [[ -n "$SESSION_DATA" ]]; then
  CWD=$(printf '%s' "$SESSION_DATA" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
CWD="${CWD:-$(pwd)}"

STATE_FILE="$CWD/.maestro/state.local.md"
CONFIG_FILE="$CWD/.maestro/config.yaml"
TRUST_FILE="$CWD/.maestro/trust.yaml"

# --- No Maestro state? Show minimal line ---
if [[ ! -f "$STATE_FILE" ]]; then
  # Check if Maestro is initialized
  if [[ -f "$CWD/.maestro/dna.md" ]]; then
    printf "${DIM}maestro${RESET} ${GREEN}ready${RESET}"
  fi
  exit 0
fi

# --- Parse state frontmatter ---
frontmatter=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" 2>/dev/null | sed '1d;$d')

yaml_val() {
  local key="$1"
  printf '%s\n' "$frontmatter" | grep -E "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | xargs 2>/dev/null || echo ""
}

active=$(yaml_val "active")
feature=$(yaml_val "feature")
phase=$(yaml_val "phase")
mode=$(yaml_val "mode")
current_story=$(yaml_val "current_story")
total_stories=$(yaml_val "total_stories")
token_spend=$(yaml_val "token_spend")
layer=$(yaml_val "layer")

# --- Not active? ---
if [[ "$active" != "true" ]]; then
  if [[ "$phase" == "completed" ]]; then
    printf "${GREEN}maestro${RESET} ${DIM}completed${RESET}"
  elif [[ "$phase" == "aborted" ]]; then
    printf "${YELLOW}maestro${RESET} ${DIM}aborted${RESET}"
  fi
  exit 0
fi

# --- Phase colors ---
phase_color() {
  case "$1" in
    validate|delegate) printf "$BLUE" ;;
    implement) printf "$CYAN" ;;
    self_heal) printf "$YELLOW" ;;
    qa_review) printf "$MAGENTA" ;;
    git_craft) printf "$GREEN" ;;
    checkpoint) printf "$GREEN" ;;
    decompose) printf "$BLUE" ;;
    paused) printf "$YELLOW" ;;
    *) printf "$WHITE" ;;
  esac
}

# --- Progress bar ---
progress_bar() {
  local current=$1
  local total=$2
  local width=10

  if [[ $total -eq 0 ]]; then
    printf "${DIM}[          ]${RESET}"
    return
  fi

  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))

  printf "${GREEN}"
  for ((i=0; i<filled; i++)); do printf "█"; done
  printf "${DIM}"
  for ((i=0; i<empty; i++)); do printf "░"; done
  printf "${RESET}"
}

# --- Mode indicator ---
mode_icon() {
  case "$1" in
    yolo) printf "${RED}⚡${RESET}" ;;
    checkpoint) printf "${YELLOW}◆${RESET}" ;;
    careful) printf "${BLUE}◈${RESET}" ;;
    *) printf "·" ;;
  esac
}

# --- Build status line ---

# Line 1: Phase + Progress
PHASE_CLR=$(phase_color "$phase")
PHASE_UPPER=$(printf '%s' "$phase" | tr '[:lower:]' '[:upper:]')

# Truncate feature name to 25 chars
FEAT="${feature:0:25}"
[[ ${#feature} -gt 25 ]] && FEAT="${FEAT}…"

printf "${BOLD}maestro${RESET} "
printf "$(mode_icon "$mode") "
printf "${PHASE_CLR}${PHASE_UPPER}${RESET} "

if [[ -n "$current_story" && -n "$total_stories" && "$total_stories" -gt 0 ]] 2>/dev/null; then
  printf "$(progress_bar "${current_story:-0}" "$total_stories") "
  printf "${DIM}${current_story}/${total_stories}${RESET} "
fi

# Cost
if [[ -n "$token_spend" && "$token_spend" -gt 0 ]] 2>/dev/null; then
  # Rough cost estimate (assuming sonnet average)
  cost_cents=$(( token_spend * 9 / 1000000 ))
  if [[ $cost_cents -gt 0 ]]; then
    printf "${DIM}\$$(printf '%.2f' "$(echo "scale=2; $cost_cents / 100" | bc)")${RESET} "
  fi
fi

# Feature name
printf "${DIM}${FEAT}${RESET}"
