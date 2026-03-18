#!/usr/bin/env bash
# context-check.sh — Check remaining Claude context window capacity
# Usage: ./scripts/context-check.sh [--json] [--max=<tokens>]

set -euo pipefail

MAX_TOKENS="${CONTEXT_MAX_TOKENS:-200000}"
JSON_MODE=false

for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
    --max=*) MAX_TOKENS="${arg#--max=}" ;;
    --help|-h) printf 'Usage: context-check.sh [--json] [--max=N]\n'; exit 0 ;;
  esac
done

# --- Find session JSONL ---
# Encoded CWD: absolute path with / replaced by -, leading - stripped
find_session_file() {
  local encoded="${PWD//\//-}"
  encoded="${encoded#-}"
  local session_dir="$HOME/.claude/projects/${encoded}"
  [[ -d "$session_dir" ]] || return 1
  ls -t "$session_dir"/*.jsonl 2>/dev/null | head -1
}

# --- Parse token usage from JSONL ---
parse_tokens() {
  local line
  line=$(grep -a 'cache_read_input_tokens' "$1" 2>/dev/null | tail -1 || true)
  [[ -z "$line" ]] && { printf '0'; return; }
  local input cache_c cache_r output
  input=$(printf '%s' "$line" | grep -oP '"input_tokens"\s*:\s*\K[0-9]+' | head -1 || echo 0)
  cache_c=$(printf '%s' "$line" | grep -oP '"cache_creation_input_tokens"\s*:\s*\K[0-9]+' | head -1 || echo 0)
  cache_r=$(printf '%s' "$line" | grep -oP '"cache_read_input_tokens"\s*:\s*\K[0-9]+' | head -1 || echo 0)
  output=$(printf '%s' "$line" | grep -oP '"output_tokens"\s*:\s*\K[0-9]+' | head -1 || echo 0)
  printf '%d' $(( input + cache_c + cache_r + output ))
}

# --- Formatting helpers ---
render_bar() {
  local pct="$1" width=40 bar=""
  local filled=$(( pct * width / 100 )) empty=$(( width - pct * width / 100 ))
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf '%s' "$bar"
}

fmt_pct() { printf '%d.%d' $(( $1 / 10 )) $(( $1 % 10 )); }

fmt_num() { printf '%d' "$1" | sed ':a;s/\B[0-9]\{3\}\b/,&/;ta'; }

# --- Error: no session found ---
no_session() {
  if $JSON_MODE; then
    printf '{"error":"session file not found","used_tokens":0,"max_tokens":%d,"percent":0,"status":"unknown"}\n' "$MAX_TOKENS"
  else
    printf 'Context Window Status:\n'
    printf '  No session file found at ~/.claude/projects/<encoded-cwd>/\n'
    printf '  (Run from a directory with an active Claude session)\n'
  fi
  exit 1
}

# --- Main ---
SESSION_FILE=$(find_session_file 2>/dev/null) || no_session
[[ -n "$SESSION_FILE" ]] || no_session

USED=$(parse_tokens "$SESSION_FILE")
REMAINING=$(( MAX_TOKENS - USED ))
PERMILLE=$(( USED * 1000 / MAX_TOKENS ))
PCT_INT=$(( PERMILLE / 10 ))
PCT=$(fmt_pct "$PERMILLE")

# Determine threshold
if [[ $PCT_INT -ge 90 ]]; then
  STATUS_KEY="critical"
  STATUS_ICON="❌"; STATUS_TEXT="Critical — compaction or handoff needed"
  SUGGESTION="Write HANDOFF.md and start fresh: /newchat"
elif [[ $PCT_INT -ge 80 ]]; then
  STATUS_KEY="nearly_full"
  STATUS_ICON="🔶"; STATUS_TEXT="Nearly full — checkpoint recommended"
  SUGGESTION="Create a checkpoint: /maestro checkpoint, then /compact"
elif [[ $PCT_INT -ge 60 ]]; then
  STATUS_KEY="getting_full"
  STATUS_ICON="⚠️"; STATUS_TEXT="Getting full — consider /compact"
  SUGGESTION="Run /compact to free up space"
else
  STATUS_KEY="healthy"
  STATUS_ICON="✅"; STATUS_TEXT="Healthy — plenty of room"
  SUGGESTION=""
fi

# Output
if $JSON_MODE; then
  printf '{"used_tokens":%d,"max_tokens":%d,"percent":%s,"status":"%s"}\n' \
    "$USED" "$MAX_TOKENS" "$PCT" "$STATUS_KEY"
else
  printf 'Context Window Status:\n'
  printf '  Used:      %s / %s tokens (%s%%)\n' "$(fmt_num "$USED")" "$(fmt_num "$MAX_TOKENS")" "$PCT"
  printf '  Remaining: ~%s tokens\n' "$(fmt_num "$REMAINING")"
  printf '\n'
  printf '  %s  %s%%\n' "$(render_bar "$PCT_INT")" "$PCT"
  printf '\n'
  printf '  Status: %s %s\n' "$STATUS_ICON" "$STATUS_TEXT"
  [[ -n "$SUGGESTION" ]] && printf '\n  Suggestion: %s\n' "$SUGGESTION"
fi
