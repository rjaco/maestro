#!/usr/bin/env bash
# Maestro Quick Start — ONE command to start autonomous operation
#
# Usage:
#   ./scripts/maestro-start.sh                    # Start daemon + telegram
#   ./scripts/maestro-start.sh --install-service  # Also register as system service
#   ./scripts/maestro-start.sh --parallel 3       # Parallel mode
#   ./scripts/maestro-start.sh --stop             # Stop everything
#
# This is Maestro's equivalent of: openclaw onboard --install-daemon
# One command, everything starts, survives terminal close.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[0;33m'
CLR_BOLD='\033[1m'
CLR_RESET='\033[0m'

# Parse args
INSTALL_SERVICE=false
PARALLEL_FLAG=""
STOP=false

for arg in "$@"; do
  case "$arg" in
    --install-service) INSTALL_SERVICE=true ;;
    --parallel)        shift; PARALLEL_FLAG="--parallel ${1:-3}" ;;
    --stop)            STOP=true ;;
  esac
done

if [[ "$STOP" == "true" ]]; then
  "$SCRIPT_DIR/maestro-service.sh" stop
  exit 0
fi

# Banner
# shellcheck disable=SC2059
printf "${CLR_BOLD}"
cat << 'BANNER'

  ███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
  ████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
  ██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
  ██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
  ██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
  ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
                 Autonomous Development Engine

BANNER
# shellcheck disable=SC2059
printf "${CLR_RESET}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
echo ""

# Check claude CLI
if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found. Install Claude Code first."
  echo "  npm install -g @anthropic-ai/claude-code"
  exit 1
fi
# shellcheck disable=SC2059
printf "  ${CLR_GREEN}✓${CLR_RESET} claude CLI found\n"

# Check project initialization
if [[ ! -f "$PROJECT_DIR/.maestro/dna.md" ]]; then
  echo ""
  echo "  Project not initialized. Run first:"
  echo "    claude"
  echo "    /maestro init"
  echo ""
  echo "  Then run this script again."
  exit 1
fi
# shellcheck disable=SC2059
printf "  ${CLR_GREEN}✓${CLR_RESET} Project initialized (.maestro/dna.md)\n"

# Check state file
if [[ ! -f "$PROJECT_DIR/.maestro/state.local.md" ]]; then
  echo ""
  echo "  No active Opus session. Start one first:"
  echo "    claude"
  echo "    /maestro magnum-opus \"Your vision here\" --full-auto"
  echo ""
  echo "  Then run this script to keep it running forever."
  exit 1
fi
# shellcheck disable=SC2059
printf "  ${CLR_GREEN}✓${CLR_RESET} Opus session state found\n"

# Check Telegram (optional)
TELEGRAM_CONFIGURED=false
if [[ -n "${MAESTRO_TELEGRAM_TOKEN:-}" ]] && [[ -n "${MAESTRO_TELEGRAM_CHAT:-}" ]]; then
  TELEGRAM_CONFIGURED=true
  # shellcheck disable=SC2059
  printf "  ${CLR_GREEN}✓${CLR_RESET} Telegram configured\n"
else
  # shellcheck disable=SC2059
  printf "  ${CLR_YELLOW}○${CLR_RESET} Telegram not configured (set MAESTRO_TELEGRAM_TOKEN + MAESTRO_TELEGRAM_CHAT)\n"
fi

echo ""

# ---------------------------------------------------------------------------
# Install as system service (optional)
# ---------------------------------------------------------------------------
if [[ "$INSTALL_SERVICE" == "true" ]]; then
  "$SCRIPT_DIR/maestro-service.sh" install
  echo ""
fi

# ---------------------------------------------------------------------------
# Start everything
# ---------------------------------------------------------------------------
# shellcheck disable=SC2059
printf "${CLR_BOLD}Starting Maestro...${CLR_RESET}\n"
echo ""

# Start Telegram listener in background (if configured)
if [[ "$TELEGRAM_CONFIGURED" == "true" ]] && [[ -x "$SCRIPT_DIR/remote-listener.sh" ]]; then
  # shellcheck disable=SC2059
  printf "  ${CLR_GREEN}▶${CLR_RESET} Starting Telegram remote listener...\n"
  nohup "$SCRIPT_DIR/remote-listener.sh" &> "$PROJECT_DIR/.maestro/logs/remote-listener.log" &
  echo "$!" > "$PROJECT_DIR/.maestro/remote-listener.pid"
  echo "    Control from Telegram: /status /pause /resume /logs"
fi

# Start daemon
# shellcheck disable=SC2059
printf "  ${CLR_GREEN}▶${CLR_RESET} Starting Opus daemon...\n"
echo ""

# Show how to stop
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Maestro is running autonomously.           │"
echo "  │                                             │"
echo "  │  Stop:    ./scripts/maestro-start.sh --stop │"
echo "  │  Status:  ./scripts/maestro-service.sh status│"
echo "  │  Logs:    ./scripts/maestro-service.sh logs  │"
if [[ "$TELEGRAM_CONFIGURED" == "true" ]]; then
echo "  │  Telegram: /status /pause /resume           │"
fi
echo "  │                                             │"
echo "  │  Press Ctrl+C to stop the daemon.           │"
echo "  └─────────────────────────────────────────────┘"
echo ""

# Run daemon in foreground (so Ctrl+C works)
# shellcheck disable=SC2086
exec "$SCRIPT_DIR/opus-daemon.sh" $PARALLEL_FLAG
