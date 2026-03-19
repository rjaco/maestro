#!/usr/bin/env bash
# Maestro Service Manager — install/start/stop Maestro as a system service
#
# Makes Maestro run like OpenClaw: install once, runs forever, survives reboots.
#
# Usage:
#   ./scripts/maestro-service.sh install    # Register as system service + start
#   ./scripts/maestro-service.sh start      # Start the service
#   ./scripts/maestro-service.sh stop       # Stop the service
#   ./scripts/maestro-service.sh restart    # Restart
#   ./scripts/maestro-service.sh status     # Check if running
#   ./scripts/maestro-service.sh uninstall  # Remove the service
#   ./scripts/maestro-service.sh logs       # Tail the daemon log
#
# Equivalent to OpenClaw's:
#   openclaw gateway install / start / stop / status / uninstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DAEMON_SCRIPT="$SCRIPT_DIR/opus-daemon.sh"
LISTENER_SCRIPT="$SCRIPT_DIR/remote-listener.sh"
LOG_DIR="$PROJECT_DIR/.maestro/logs"
PID_FILE="$PROJECT_DIR/.maestro/opus-daemon.pid"
LISTENER_PID_FILE="$PROJECT_DIR/.maestro/remote-listener.pid"

# Service names
SERVICE_NAME="maestro-opus"
LAUNCHD_LABEL="dev.maestro.opus-daemon"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
SYSTEMD_SERVICE="$HOME/.config/systemd/user/${SERVICE_NAME}.service"

# Colors
CLR_GREEN='\033[0;32m'
CLR_RED='\033[0;31m'
CLR_YELLOW='\033[0;33m'
CLR_BOLD='\033[1m'
CLR_RESET='\033[0m'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf "${CLR_GREEN}[maestro]${CLR_RESET} %s\n" "$1"; }
warn()  { printf "${CLR_YELLOW}[maestro]${CLR_RESET} %s\n" "$1"; }
error() { printf "${CLR_RED}[maestro]${CLR_RESET} %s\n" "$1" >&2; }

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

is_running() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# ---------------------------------------------------------------------------
# macOS: launchd service
# ---------------------------------------------------------------------------
install_macos() {
  mkdir -p "$(dirname "$LAUNCHD_PLIST")"
  mkdir -p "$LOG_DIR"

  cat > "$LAUNCHD_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCHD_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${DAEMON_SCRIPT}</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${PROJECT_DIR}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/daemon-stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/daemon-stderr.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/.local/bin</string>
  </dict>
</dict>
</plist>
PLIST

  launchctl load "$LAUNCHD_PLIST" 2>/dev/null || true
  info "Installed launchd service: $LAUNCHD_LABEL"
  info "Daemon will start at login and restart on crash."
}

uninstall_macos() {
  if [[ -f "$LAUNCHD_PLIST" ]]; then
    launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    rm -f "$LAUNCHD_PLIST"
    info "Removed launchd service: $LAUNCHD_LABEL"
  else
    warn "No launchd service found."
  fi
}

start_macos() {
  if [[ -f "$LAUNCHD_PLIST" ]]; then
    launchctl start "$LAUNCHD_LABEL" 2>/dev/null || launchctl kickstart "gui/$(id -u)/$LAUNCHD_LABEL" 2>/dev/null || true
    info "Service started."
  else
    warn "No launchd service installed. Running manually..."
    start_manual
  fi
}

stop_macos() {
  if [[ -f "$LAUNCHD_PLIST" ]]; then
    launchctl stop "$LAUNCHD_LABEL" 2>/dev/null || true
    info "Service stopped."
  fi
  stop_manual
}

# ---------------------------------------------------------------------------
# Linux: systemd user service
# ---------------------------------------------------------------------------
install_linux() {
  mkdir -p "$(dirname "$SYSTEMD_SERVICE")"
  mkdir -p "$LOG_DIR"

  cat > "$SYSTEMD_SERVICE" << UNIT
[Unit]
Description=Maestro Opus Daemon — Autonomous Development Engine
After=network.target

[Service]
Type=simple
WorkingDirectory=${PROJECT_DIR}
ExecStart=${DAEMON_SCRIPT}
Restart=always
RestartSec=10
Environment=PATH=/usr/local/bin:/usr/bin:/bin:%h/.local/bin:%h/.nvm/versions/node/*/bin

[Install]
WantedBy=default.target
UNIT

  systemctl --user daemon-reload
  systemctl --user enable "$SERVICE_NAME"
  info "Installed systemd service: $SERVICE_NAME"
  info "Daemon will start at login and restart on crash."
}

uninstall_linux() {
  if [[ -f "$SYSTEMD_SERVICE" ]]; then
    systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SYSTEMD_SERVICE"
    systemctl --user daemon-reload
    info "Removed systemd service: $SERVICE_NAME"
  else
    warn "No systemd service found."
  fi
}

start_linux() {
  if [[ -f "$SYSTEMD_SERVICE" ]]; then
    systemctl --user start "$SERVICE_NAME"
    info "Service started."
  else
    warn "No systemd service installed. Running manually..."
    start_manual
  fi
}

stop_linux() {
  if [[ -f "$SYSTEMD_SERVICE" ]]; then
    systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
    info "Service stopped."
  fi
  stop_manual
}

# ---------------------------------------------------------------------------
# Manual start/stop (fallback for any OS)
# ---------------------------------------------------------------------------
start_manual() {
  if is_running; then
    warn "Daemon is already running (PID $(cat "$PID_FILE"))."
    return 0
  fi

  mkdir -p "$LOG_DIR"

  # Start remote listener if Telegram is configured
  if [[ -n "${MAESTRO_TELEGRAM_TOKEN:-}" ]] && [[ -x "$LISTENER_SCRIPT" ]]; then
    info "Starting Telegram remote listener..."
    nohup "$LISTENER_SCRIPT" &> "$LOG_DIR/remote-listener.log" &
    echo "$!" > "$LISTENER_PID_FILE"
  fi

  # Start daemon in background
  info "Starting opus daemon..."
  nohup "$DAEMON_SCRIPT" &> "$LOG_DIR/daemon-nohup.log" &
  local daemon_pid=$!
  echo "$daemon_pid" > "$PID_FILE"

  sleep 1
  if kill -0 "$daemon_pid" 2>/dev/null; then
    info "Daemon running (PID $daemon_pid)."
    info "Logs: $LOG_DIR/daemon.log"
  else
    error "Daemon failed to start. Check $LOG_DIR/daemon-nohup.log"
    return 1
  fi
}

stop_manual() {
  # Stop daemon
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid"
      info "Daemon stopped (PID $pid)."
    fi
    rm -f "$PID_FILE"
  fi

  # Stop remote listener
  if [[ -f "$LISTENER_PID_FILE" ]]; then
    local lpid
    lpid=$(cat "$LISTENER_PID_FILE")
    if kill -0 "$lpid" 2>/dev/null; then
      kill -TERM "$lpid"
      info "Remote listener stopped (PID $lpid)."
    fi
    rm -f "$LISTENER_PID_FILE"
  fi
}

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------
show_status() {
  local os
  os=$(detect_os)

  # shellcheck disable=SC2059
  printf "${CLR_BOLD}Maestro Opus Daemon Status${CLR_RESET}\n"
  echo "=========================="

  # Daemon process
  if is_running; then
    local pid
    pid=$(cat "$PID_FILE")
    local uptime_info
    uptime_info=$(ps -o etime= -p "$pid" 2>/dev/null | xargs || echo "unknown")
    printf "  Daemon:     ${CLR_GREEN}RUNNING${CLR_RESET} (PID %s, uptime %s)\n" "$pid" "$uptime_info"
  else
    printf "  Daemon:     ${CLR_RED}STOPPED${CLR_RESET}\n"
  fi

  # Remote listener
  if [[ -f "$LISTENER_PID_FILE" ]] && kill -0 "$(cat "$LISTENER_PID_FILE")" 2>/dev/null; then
    printf "  Telegram:   ${CLR_GREEN}RUNNING${CLR_RESET} (PID %s)\n" "$(cat "$LISTENER_PID_FILE")"
  else
    printf "  Telegram:   ${CLR_YELLOW}NOT RUNNING${CLR_RESET}\n"
  fi

  # System service
  if [[ "$os" == "macos" ]] && [[ -f "$LAUNCHD_PLIST" ]]; then
    printf "  Service:    ${CLR_GREEN}INSTALLED${CLR_RESET} (launchd)\n"
  elif [[ "$os" == "linux" ]] && [[ -f "$SYSTEMD_SERVICE" ]]; then
    printf "  Service:    ${CLR_GREEN}INSTALLED${CLR_RESET} (systemd)\n"
  else
    printf "  Service:    ${CLR_YELLOW}NOT INSTALLED${CLR_RESET} (use: maestro-service.sh install)\n"
  fi

  # State
  if [[ -f "$PROJECT_DIR/.maestro/state.local.md" ]]; then
    local phase milestone story
    phase=$(grep -m1 "^phase:" "$PROJECT_DIR/.maestro/state.local.md" 2>/dev/null | awk '{print $2}' || echo "?")
    milestone=$(grep -m1 "^current_milestone:" "$PROJECT_DIR/.maestro/state.local.md" 2>/dev/null | awk '{print $2}' || echo "?")
    story=$(grep -m1 "^current_story:" "$PROJECT_DIR/.maestro/state.local.md" 2>/dev/null | awk '{print $2}' || echo "?")
    printf "  Phase:      %s\n" "$phase"
    printf "  Milestone:  M%s\n" "$milestone"
    printf "  Story:      %s\n" "$story"
  fi

  # Last heartbeat
  if [[ -f "$PROJECT_DIR/.maestro/logs/heartbeat" ]]; then
    local last_beat
    last_beat=$(cat "$PROJECT_DIR/.maestro/logs/heartbeat" 2>/dev/null)
    printf "  Heartbeat:  %s\n" "$last_beat"
  fi

  echo ""
}

# ---------------------------------------------------------------------------
# Logs
# ---------------------------------------------------------------------------
show_logs() {
  if [[ -f "$LOG_DIR/daemon.log" ]]; then
    tail -50 "$LOG_DIR/daemon.log"
  else
    warn "No daemon log found."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
CMD="${1:-help}"
OS=$(detect_os)

case "$CMD" in
  install)
    info "Installing Maestro as a system service..."
    case "$OS" in
      macos) install_macos ;;
      linux) install_linux ;;
      *)     error "Unsupported OS. Use 'start' for manual mode." ; exit 1 ;;
    esac
    info ""
    info "To start now: $0 start"
    info "It will auto-start on login and restart on crash."
    ;;

  start)
    case "$OS" in
      macos) start_macos ;;
      linux) start_linux ;;
      *)     start_manual ;;
    esac
    ;;

  stop)
    case "$OS" in
      macos) stop_macos ;;
      linux) stop_linux ;;
      *)     stop_manual ;;
    esac
    ;;

  restart)
    "$0" stop
    sleep 2
    "$0" start
    ;;

  status)
    show_status
    ;;

  uninstall)
    case "$OS" in
      macos) uninstall_macos ;;
      linux) uninstall_linux ;;
      *)     stop_manual ; warn "No service manager on this OS." ;;
    esac
    ;;

  logs)
    show_logs
    ;;

  *)
    cat << 'HELP'
Maestro Service Manager

  install    Register as system service (launchd/systemd) — starts at login
  start      Start the daemon (and Telegram listener if configured)
  stop       Stop the daemon
  restart    Stop + start
  status     Show daemon, telegram, service status
  uninstall  Remove the system service
  logs       Tail the daemon log

Equivalent to OpenClaw's:
  openclaw gateway install / start / stop / status / uninstall
HELP
    ;;
esac
