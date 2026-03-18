#!/usr/bin/env bash
# Maestro Notify Script — Send notifications from shell
# Sends messages to Slack, Discord, or Telegram directly from bash.
# Useful for: progress updates, CI/CD alerts, cron job results.
#
# Usage:
#   ./scripts/notify.sh "Build complete — 5 stories shipped"
#   ./scripts/notify.sh --channel slack "Deploy to production succeeded"
#   ./scripts/notify.sh --level error "Tests failing on main branch"
#   ./scripts/notify.sh --title "Daily Report" --body "$(cat report.md)"
#
# Config: reads from .maestro/config.yml or environment variables

set -euo pipefail

MESSAGE=""
CHANNEL=""
LEVEL="info"
TITLE=""
BODY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel) CHANNEL="$2"; shift 2 ;;
    --level) LEVEL="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --help)
      echo "Usage: notify.sh [OPTIONS] [MESSAGE]"
      echo ""
      echo "Options:"
      echo "  --channel slack|discord|telegram  Target channel (default: all configured)"
      echo "  --level info|warning|error        Message severity"
      echo "  --title TEXT                       Message title/subject"
      echo "  --body TEXT                        Message body (overrides positional arg)"
      echo ""
      echo "Examples:"
      echo "  notify.sh 'Build complete'"
      echo "  notify.sh --channel slack --level error 'Tests failed'"
      echo "  notify.sh --title 'Daily Report' --body \"\$(cat report.md)\""
      exit 0
      ;;
    *) MESSAGE="$1"; shift ;;
  esac
done

# Build message from title + body or positional arg
if [[ -n "$TITLE" ]]; then
  MESSAGE="*${TITLE}*"
  if [[ -n "$BODY" ]]; then
    MESSAGE="${MESSAGE}\n${BODY}"
  fi
elif [[ -n "$BODY" ]]; then
  MESSAGE="$BODY"
fi

if [[ -z "$MESSAGE" ]]; then
  echo "Error: No message provided. Use --help for usage."
  exit 1
fi

# Add level prefix
case "$LEVEL" in
  error)   PREFIX="❌" ;;
  warning) PREFIX="⚠️" ;;
  info)    PREFIX="ℹ️" ;;
  *)       PREFIX="📢" ;;
esac

FULL_MESSAGE="${PREFIX} [Maestro] ${MESSAGE}"

# --- Slack ---
send_slack() {
  local webhook_url="${SLACK_WEBHOOK_URL:-}"
  if [[ -z "$webhook_url" ]]; then
    # Try to read from config
    webhook_url=$(grep -A1 'slack:' .maestro/config.yml 2>/dev/null | grep 'webhook_url:' | sed 's/.*webhook_url:[[:space:]]*//' | xargs 2>/dev/null || true)
  fi
  if [[ -n "$webhook_url" && "$webhook_url" != "null" ]]; then
    local escaped_msg
    escaped_msg=$(printf '%s' "$FULL_MESSAGE" | sed 's/"/\\"/g')
    curl -s -X POST "$webhook_url" \
      -H 'Content-Type: application/json' \
      -d "{\"text\":\"${escaped_msg}\"}" >/dev/null 2>&1 && echo "  ✅ Slack sent" || echo "  ❌ Slack failed"
  fi
}

# --- Discord ---
send_discord() {
  local webhook_url="${DISCORD_WEBHOOK_URL:-}"
  if [[ -z "$webhook_url" ]]; then
    webhook_url=$(grep -A1 'discord:' .maestro/config.yml 2>/dev/null | grep 'webhook_url:' | sed 's/.*webhook_url:[[:space:]]*//' | xargs 2>/dev/null || true)
  fi
  if [[ -n "$webhook_url" && "$webhook_url" != "null" ]]; then
    local escaped_msg
    escaped_msg=$(printf '%s' "$FULL_MESSAGE" | sed 's/"/\\"/g')
    curl -s -X POST "$webhook_url" \
      -H 'Content-Type: application/json' \
      -d "{\"content\":\"${escaped_msg}\"}" >/dev/null 2>&1 && echo "  ✅ Discord sent" || echo "  ❌ Discord failed"
  fi
}

# --- Telegram ---
send_telegram() {
  local bot_token="${TELEGRAM_BOT_TOKEN:-}"
  local chat_id="${TELEGRAM_CHAT_ID:-}"
  if [[ -z "$bot_token" ]]; then
    bot_token=$(grep 'bot_token:' .maestro/config.yml 2>/dev/null | sed 's/.*bot_token:[[:space:]]*//' | xargs 2>/dev/null || true)
  fi
  if [[ -z "$chat_id" ]]; then
    chat_id=$(grep 'chat_id:' .maestro/config.yml 2>/dev/null | sed 's/.*chat_id:[[:space:]]*//' | xargs 2>/dev/null || true)
  fi
  if [[ -n "$bot_token" && "$bot_token" != "null" && -n "$chat_id" && "$chat_id" != "null" ]]; then
    local escaped_msg
    escaped_msg=$(printf '%s' "$FULL_MESSAGE" | sed 's/"/\\"/g')
    curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
      -d "chat_id=${chat_id}" \
      -d "text=${escaped_msg}" \
      -d "parse_mode=HTML" >/dev/null 2>&1 && echo "  ✅ Telegram sent" || echo "  ❌ Telegram failed"
  fi
}

# Send to specified channel or all configured
echo "Sending notification..."
if [[ -n "$CHANNEL" ]]; then
  case "$CHANNEL" in
    slack) send_slack ;;
    discord) send_discord ;;
    telegram) send_telegram ;;
    *) echo "Unknown channel: $CHANNEL"; exit 1 ;;
  esac
else
  send_slack
  send_discord
  send_telegram
fi

echo "Done."
