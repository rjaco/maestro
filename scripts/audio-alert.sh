#!/usr/bin/env bash
# Maestro Audio Alert Script
# Plays notification sounds when Maestro events occur.
# Cross-platform: macOS (afplay), Linux (paplay/aplay), WSL (powershell), fallback (terminal bell).
#
# Usage:
#   ./scripts/audio-alert.sh success    # Feature/story completed
#   ./scripts/audio-alert.sh error      # Build/test failure
#   ./scripts/audio-alert.sh attention  # User input needed (checkpoint)
#   ./scripts/audio-alert.sh complete   # All milestones done

set -euo pipefail

ALERT_TYPE="${1:-attention}"

# Check if audio is enabled in config
if [[ -f ".maestro/config.yml" ]]; then
  AUDIO_ENABLED=$(grep -E "^\s*audio.*enabled" ".maestro/config.yml" 2>/dev/null | grep -qi "true" && echo "true" || echo "false")
  if [[ "$AUDIO_ENABLED" == "false" ]]; then
    exit 0
  fi
fi

play_bell() {
  # Universal terminal bell — works everywhere
  printf '\a'
}

play_macos() {
  local sound="$1"
  afplay "/System/Library/Sounds/${sound}.aiff" 2>/dev/null &
}

play_linux() {
  local freq="$1"
  local duration="$2"

  # Try paplay with generated tone
  if command -v paplay &>/dev/null; then
    # Generate a simple beep using sox if available
    if command -v sox &>/dev/null; then
      sox -n -t pulseaudio default synth "$duration" sine "$freq" 2>/dev/null &
      return 0
    fi
  fi

  # Try aplay
  if command -v aplay &>/dev/null; then
    if command -v sox &>/dev/null; then
      sox -n -t wav - synth "$duration" sine "$freq" 2>/dev/null | aplay -q 2>/dev/null &
      return 0
    fi
  fi

  # Try beep command
  if command -v beep &>/dev/null; then
    beep -f "$freq" -l "$(echo "$duration * 1000" | bc 2>/dev/null || echo 200)" 2>/dev/null &
    return 0
  fi

  return 1
}

play_wsl() {
  local sound_type="$1"
  # Use PowerShell to play Windows system sounds
  powershell.exe -c "[System.Media.SystemSounds]::${sound_type}.Play()" 2>/dev/null &
}

play_sound() {
  local alert="$1"

  # Detect platform
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    case "$alert" in
      success)   play_macos "Glass" ;;
      error)     play_macos "Basso" ;;
      attention) play_macos "Ping" ;;
      complete)  play_macos "Hero" ;;
    esac
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL
    case "$alert" in
      success)   play_wsl "Asterisk" ;;
      error)     play_wsl "Hand" ;;
      attention) play_wsl "Exclamation" ;;
      complete)  play_wsl "Asterisk" ;;
    esac
  elif [[ "$(uname)" == "Linux" ]]; then
    # Native Linux
    case "$alert" in
      success)   play_linux 880 0.15 || play_bell ;;
      error)     play_linux 220 0.3 || play_bell ;;
      attention) play_linux 660 0.2 || play_bell ;;
      complete)  play_linux 1047 0.3 || play_bell ;;
    esac
  else
    play_bell
  fi
}

# Play the sound (non-blocking)
play_sound "$ALERT_TYPE" 2>/dev/null || play_bell

# Also set terminal title as visual indicator
case "$ALERT_TYPE" in
  success)   printf '\033]0;✅ Maestro: Story Complete\007' ;;
  error)     printf '\033]0;❌ Maestro: Error\007' ;;
  attention) printf '\033]0;⏸️ Maestro: Needs Input\007' ;;
  complete)  printf '\033]0;🎉 Maestro: All Done!\007' ;;
esac

exit 0
