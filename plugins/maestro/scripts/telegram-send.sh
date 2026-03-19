#!/usr/bin/env bash
# Usage:
#   ./scripts/telegram-send.sh "Your message here"
#   ./scripts/telegram-send.sh --photo /path/to/image.png "Optional caption"
#
# Reads MAESTRO_TELEGRAM_TOKEN and MAESTRO_TELEGRAM_CHAT from environment.
# Exit code 0 on success, 1 on failure.

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────

PHOTO_PATH=""
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --photo)
      if [[ $# -lt 2 ]]; then
        echo "telegram-send: --photo requires a file path argument" >&2
        exit 1
      fi
      PHOTO_PATH="$2"
      shift 2
      ;;
    --)
      shift
      MESSAGE="${*}"
      break
      ;;
    -*)
      echo "telegram-send: unknown option: $1" >&2
      exit 1
      ;;
    *)
      MESSAGE="${*}"
      break
      ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────

if [[ -z "${MAESTRO_TELEGRAM_TOKEN:-}" ]]; then
  echo "telegram-send: MAESTRO_TELEGRAM_TOKEN is not set" >&2
  exit 1
fi

if [[ -z "${MAESTRO_TELEGRAM_CHAT:-}" ]]; then
  echo "telegram-send: MAESTRO_TELEGRAM_CHAT is not set" >&2
  exit 1
fi

if [[ -z "$MESSAGE" && -z "$PHOTO_PATH" ]]; then
  echo "telegram-send: no message or photo provided" >&2
  exit 1
fi

BASE_URL="https://api.telegram.org/bot${MAESTRO_TELEGRAM_TOKEN}"

# ── Send photo ────────────────────────────────────────────────────────────────

if [[ -n "$PHOTO_PATH" ]]; then
  if [[ ! -f "$PHOTO_PATH" ]]; then
    echo "telegram-send: photo file not found: $PHOTO_PATH" >&2
    exit 1
  fi

  local -a curl_args=(
    -s --max-time 5 -X POST "${BASE_URL}/sendPhoto"
    -F "chat_id=${MAESTRO_TELEGRAM_CHAT}"
    -F "photo=@${PHOTO_PATH}"
  )
  [[ -n "${MESSAGE:-}" ]] && curl_args+=(-F "caption=${MESSAGE}")
  RESPONSE=$(curl "${curl_args[@]}")

  OK=$(printf '%s' "$RESPONSE" | grep -o '"ok":true' || true)
  if [[ -z "$OK" ]]; then
    echo "telegram-send: sendPhoto failed: $RESPONSE" >&2
    exit 1
  fi
  exit 0
fi

# ── Send text message ─────────────────────────────────────────────────────────

RESPONSE=$(curl -s --max-time 5 -X POST "${BASE_URL}/sendMessage" \
  --data-urlencode "chat_id=${MAESTRO_TELEGRAM_CHAT}" \
  --data-urlencode "text=${MESSAGE}" \
  -d "parse_mode=Markdown")

OK=$(printf '%s' "$RESPONSE" | grep -o '"ok":true' || true)
if [[ -z "$OK" ]]; then
  echo "telegram-send: sendMessage failed: $RESPONSE" >&2
  exit 1
fi

exit 0
