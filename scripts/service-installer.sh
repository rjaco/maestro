#!/usr/bin/env bash
# Maestro Service Installer
# Installs Maestro's scheduled tasks as a system service (launchd/systemd).
# Ensures awareness checks, health monitors, and cron tasks run on boot.
#
# Usage:
#   ./scripts/service-installer.sh install    # Install and enable service
#   ./scripts/service-installer.sh uninstall  # Remove service
#   ./scripts/service-installer.sh status     # Check service status
#   ./scripts/service-installer.sh logs       # Show service logs

set -euo pipefail

ACTION="${1:-status}"
SERVICE_NAME="com.maestro.scheduler"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

install_macos() {
  local plist_path="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"
  local log_path="/tmp/maestro-scheduler.log"

  cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SERVICE_NAME}</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(which claude)</string>
    <string>--print</string>
    <string>Run scheduled Maestro tasks: check .maestro/webhooks/queue.json for events, run health checks if due, process any cron-scheduled tasks.</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${PROJECT_DIR}</string>
  <key>StartInterval</key>
  <integer>300</integer>
  <key>StandardOutPath</key>
  <string>${log_path}</string>
  <key>StandardErrorPath</key>
  <string>${log_path}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>60</integer>
</dict>
</plist>
PLIST

  launchctl load "$plist_path" 2>/dev/null || true
  echo "✅ Service installed: $plist_path"
  echo "   Runs every 5 minutes. Logs: $log_path"
}

install_linux() {
  local service_dir="$HOME/.config/systemd/user"
  local service_file="${service_dir}/${SERVICE_NAME}.service"
  local timer_file="${service_dir}/${SERVICE_NAME}.timer"

  mkdir -p "$service_dir"

  cat > "$service_file" <<SERVICE
[Unit]
Description=Maestro Scheduler — periodic task runner
After=network.target

[Service]
Type=oneshot
WorkingDirectory=${PROJECT_DIR}
ExecStart=$(which claude) --print "Run scheduled Maestro tasks: check .maestro/webhooks/queue.json for events, run health checks if due."
StandardOutput=append:/tmp/maestro-scheduler.log
StandardError=append:/tmp/maestro-scheduler.log

[Install]
WantedBy=default.target
SERVICE

  cat > "$timer_file" <<TIMER
[Unit]
Description=Maestro Scheduler Timer — runs every 5 minutes

[Timer]
OnBootSec=60
OnUnitActiveSec=300
Persistent=true

[Install]
WantedBy=timers.target
TIMER

  systemctl --user daemon-reload
  systemctl --user enable "${SERVICE_NAME}.timer"
  systemctl --user start "${SERVICE_NAME}.timer"
  echo "✅ Service installed: $service_file"
  echo "   Timer: every 5 minutes. Logs: /tmp/maestro-scheduler.log"
}

uninstall_macos() {
  local plist_path="$HOME/Library/LaunchAgents/${SERVICE_NAME}.plist"
  launchctl unload "$plist_path" 2>/dev/null || true
  rm -f "$plist_path"
  echo "✅ Service uninstalled"
}

uninstall_linux() {
  systemctl --user stop "${SERVICE_NAME}.timer" 2>/dev/null || true
  systemctl --user disable "${SERVICE_NAME}.timer" 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/${SERVICE_NAME}.service"
  rm -f "$HOME/.config/systemd/user/${SERVICE_NAME}.timer"
  systemctl --user daemon-reload
  echo "✅ Service uninstalled"
}

show_status() {
  if [[ "$(uname)" == "Darwin" ]]; then
    if launchctl list | grep -q "$SERVICE_NAME"; then
      echo "✅ Service is running (macOS launchd)"
      launchctl list "$SERVICE_NAME" 2>/dev/null || true
    else
      echo "❌ Service is not running"
    fi
  else
    if systemctl --user is-active "${SERVICE_NAME}.timer" &>/dev/null; then
      echo "✅ Service is running (systemd timer)"
      systemctl --user status "${SERVICE_NAME}.timer" --no-pager 2>/dev/null || true
    else
      echo "❌ Service is not running"
    fi
  fi
}

show_logs() {
  local log_file="/tmp/maestro-scheduler.log"
  if [[ -f "$log_file" ]]; then
    tail -50 "$log_file"
  else
    echo "No logs found at $log_file"
  fi
}

case "$ACTION" in
  install)
    echo "Installing Maestro scheduler service..."
    if [[ "$(uname)" == "Darwin" ]]; then
      install_macos
    elif [[ "$(uname)" == "Linux" ]]; then
      install_linux
    else
      echo "❌ Unsupported platform. Manual setup required."
      echo "   Use PM2: pm2 start 'claude --print \"Run Maestro tasks\"' --cron '*/5 * * * *'"
      exit 1
    fi
    ;;
  uninstall)
    echo "Uninstalling Maestro scheduler service..."
    if [[ "$(uname)" == "Darwin" ]]; then
      uninstall_macos
    else
      uninstall_linux
    fi
    ;;
  status) show_status ;;
  logs) show_logs ;;
  *)
    echo "Usage: $0 {install|uninstall|status|logs}"
    exit 1
    ;;
esac
