#!/usr/bin/env bash
# Usage:
#   ./scripts/notify.sh --event milestone_complete --message "M1 done"
#   ./scripts/notify.sh --event story_complete --message "Story S3 complete"
#
# Reads notification provider config from .maestro/config.yaml if present.
# Falls back to checking env vars directly if config is missing.
#
# Supported providers: telegram, slack, discord, webhook

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────

EVENT=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event)
      if [[ $# -lt 2 ]]; then
        echo "notify: --event requires a value" >&2
        exit 1
      fi
      EVENT="$2"
      shift 2
      ;;
    --message)
      if [[ $# -lt 2 ]]; then
        echo "notify: --message requires a value" >&2
        exit 1
      fi
      MESSAGE="$2"
      shift 2
      ;;
    *)
      echo "notify: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$EVENT" ]]; then
  echo "notify: --event is required" >&2
  exit 1
fi

if [[ -z "$MESSAGE" ]]; then
  echo "notify: --message is required" >&2
  exit 1
fi

# ── Script location (for sibling script calls) ────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE=".maestro/config.yaml"

# ── YAML helper: extract a scalar value from a simple YAML file ───────────────
# Usage: yaml_get <file> <dot.path>
# Only handles flat key: value and two-level indented keys.
yaml_get() {
  local file="$1"
  local key="$2"
  local section
  local leaf

  # Split key on last '.'
  section="${key%.*}"
  leaf="${key##*.}"

  if [[ "$section" == "$leaf" ]]; then
    # Top-level key
    grep -m1 "^${leaf}:" "$file" 2>/dev/null \
      | sed 's/^[^:]*:[[:space:]]*//' \
      | tr -d '"' \
      | xargs 2>/dev/null || true
  else
    # Two-level key: find section block then look for leaf
    local in_section=0
    local indent_section=""
    while IFS= read -r line; do
      # Detect section header (allow leading spaces)
      local stripped_line
      stripped_line="${line#"${line%%[! ]*}"}"  # ltrim
      if [[ "$stripped_line" == "${section##*.}:" ]]; then
        in_section=1
        indent_section="${line%%[! ]*}"  # capture indent
        continue
      fi
      if [[ $in_section -eq 1 ]]; then
        # End of section: line at same or lesser indent that isn't blank
        if [[ -n "$line" && "$line" != "${indent_section}"* ]]; then
          in_section=0
          continue
        fi
        local k v
        k=$(printf '%s' "$line" | sed 's/^[[:space:]]*//' | cut -d: -f1)
        v=$(printf '%s' "$line" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' | xargs 2>/dev/null || true)
        if [[ "$k" == "$leaf" ]]; then
          printf '%s' "$v"
          return
        fi
      fi
    done < "$file"
  fi
}

# ── Config reader ─────────────────────────────────────────────────────────────

# Returns "true" or "" for a provider's enabled flag
provider_enabled() {
  local provider="$1"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return
  fi
  local val
  val=$(yaml_get "$CONFIG_FILE" "notifications.${provider}.enabled" 2>/dev/null || true)
  printf '%s' "$val"
}

# Returns the value of an env var whose name is stored in config
provider_env() {
  local provider="$1"
  local key="$2"   # e.g. token_env / webhook_env
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return
  fi
  local env_var_name
  env_var_name=$(yaml_get "$CONFIG_FILE" "notifications.${provider}.${key}" 2>/dev/null || true)
  if [[ -n "$env_var_name" ]]; then
    printf '%s' "${!env_var_name:-}"
  fi
}

# ── Telegram ──────────────────────────────────────────────────────────────────

send_telegram() {
  local msg="$1"
  local token=""
  local chat=""

  if [[ -f "$CONFIG_FILE" ]]; then
    # Read env var names from config, then dereference
    local token_var chat_var
    token_var=$(yaml_get "$CONFIG_FILE" "notifications.telegram.token_env" 2>/dev/null || true)
    chat_var=$(yaml_get "$CONFIG_FILE" "notifications.telegram.chat_id_env" 2>/dev/null || true)
    [[ -n "$token_var" ]] && token="${!token_var:-}"
    [[ -n "$chat_var"  ]] && chat="${!chat_var:-}"
  fi

  # Fall back to well-known env vars
  [[ -z "$token" ]] && token="${MAESTRO_TELEGRAM_TOKEN:-}"
  [[ -z "$chat"  ]] && chat="${MAESTRO_TELEGRAM_CHAT:-}"

  if [[ -z "$token" || -z "$chat" ]]; then
    echo "notify: telegram: token/chat not configured — skipping" >&2
    return 0
  fi

  MAESTRO_TELEGRAM_TOKEN="$token" MAESTRO_TELEGRAM_CHAT="$chat" \
    "${SCRIPT_DIR}/telegram-send.sh" "$msg" || {
      echo "notify: telegram delivery failed (non-fatal)" >&2
    }
}

# ── Slack ─────────────────────────────────────────────────────────────────────

send_slack() {
  local msg="$1"
  local webhook=""

  if [[ -f "$CONFIG_FILE" ]]; then
    local wh_var
    wh_var=$(yaml_get "$CONFIG_FILE" "notifications.slack.webhook_env" 2>/dev/null || true)
    [[ -n "$wh_var" ]] && webhook="${!wh_var:-}"
  fi

  [[ -z "$webhook" ]] && webhook="${MAESTRO_SLACK_WEBHOOK:-}"

  if [[ -z "$webhook" ]]; then
    echo "notify: slack: webhook not configured — skipping" >&2
    return 0
  fi

  local payload
  local json_msg
  json_msg=$(printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null) || {
    # Safe fallback: escape backslashes, quotes, and newlines manually
    json_msg=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
    json_msg="\"${json_msg}\""
  }
  payload="{\"text\":${json_msg}}"

  curl -s --max-time 5 -X POST "$webhook" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null || {
      echo "notify: slack delivery failed (non-fatal)" >&2
    }
}

# ── Discord ───────────────────────────────────────────────────────────────────

send_discord() {
  local msg="$1"
  local webhook=""

  if [[ -f "$CONFIG_FILE" ]]; then
    local wh_var
    wh_var=$(yaml_get "$CONFIG_FILE" "notifications.discord.webhook_env" 2>/dev/null || true)
    [[ -n "$wh_var" ]] && webhook="${!wh_var:-}"
  fi

  [[ -z "$webhook" ]] && webhook="${MAESTRO_DISCORD_WEBHOOK:-}"

  if [[ -z "$webhook" ]]; then
    echo "notify: discord: webhook not configured — skipping" >&2
    return 0
  fi

  local payload
  local json_msg
  json_msg=$(printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null) || {
    json_msg=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')
    json_msg="\"${json_msg}\""
  }
  payload="{\"content\":${json_msg}}"

  curl -s --max-time 5 -X POST "$webhook" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null || {
      echo "notify: discord delivery failed (non-fatal)" >&2
    }
}

# ── Generic webhook ───────────────────────────────────────────────────────────

send_generic_webhook() {
  local event="$1"
  local msg="$2"
  local webhook=""

  if [[ -f "$CONFIG_FILE" ]]; then
    local wh_var
    wh_var=$(yaml_get "$CONFIG_FILE" "notifications.webhook.url_env" 2>/dev/null || true)
    [[ -n "$wh_var" ]] && webhook="${!wh_var:-}"
  fi

  [[ -z "$webhook" ]] && webhook="${MAESTRO_WEBHOOK_URL:-}"

  if [[ -z "$webhook" ]]; then
    return 0
  fi

  local escaped_event escaped_msg
  escaped_event=$(printf '%s' "$event" | sed 's/"/\\"/g')
  escaped_msg=$(printf '%s' "$msg" | sed 's/"/\\"/g')
  local payload="{\"event\":\"${escaped_event}\",\"message\":\"${escaped_msg}\"}"

  curl -s --max-time 5 -X POST "$webhook" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null || {
      echo "notify: generic webhook delivery failed (non-fatal)" >&2
    }
}

# ── Route to providers ────────────────────────────────────────────────────────

# Determine whether a provider should be called.
# If config.yaml exists, respect the enabled flag.
# If config.yaml is missing, fall back to env var presence.

should_send_telegram() {
  if [[ -f "$CONFIG_FILE" ]]; then
    [[ "$(provider_enabled telegram)" == "true" ]]
  else
    [[ -n "${MAESTRO_TELEGRAM_TOKEN:-}" && -n "${MAESTRO_TELEGRAM_CHAT:-}" ]]
  fi
}

should_send_slack() {
  if [[ -f "$CONFIG_FILE" ]]; then
    [[ "$(provider_enabled slack)" == "true" ]]
  else
    local wh_var="${MAESTRO_SLACK_WEBHOOK:-}"
    [[ -n "$wh_var" ]]
  fi
}

should_send_discord() {
  if [[ -f "$CONFIG_FILE" ]]; then
    [[ "$(provider_enabled discord)" == "true" ]]
  else
    local wh_var="${MAESTRO_DISCORD_WEBHOOK:-}"
    [[ -n "$wh_var" ]]
  fi
}

should_send_generic_webhook() {
  if [[ -f "$CONFIG_FILE" ]]; then
    [[ "$(provider_enabled webhook)" == "true" ]]
  else
    [[ -n "${MAESTRO_WEBHOOK_URL:-}" ]]
  fi
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

DISPATCHED=0

if should_send_telegram; then
  send_telegram "$MESSAGE"
  DISPATCHED=$((DISPATCHED + 1))
fi

if should_send_slack; then
  send_slack "$MESSAGE"
  DISPATCHED=$((DISPATCHED + 1))
fi

if should_send_discord; then
  send_discord "$MESSAGE"
  DISPATCHED=$((DISPATCHED + 1))
fi

if should_send_generic_webhook; then
  send_generic_webhook "$EVENT" "$MESSAGE"
  DISPATCHED=$((DISPATCHED + 1))
fi

if [[ $DISPATCHED -eq 0 ]]; then
  # No providers configured — silently succeed (notifications are optional)
  exit 0
fi

exit 0
