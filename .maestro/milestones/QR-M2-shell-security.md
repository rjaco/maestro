# QR-M2: Shell Script Security Hardening

## Focus
Fix all HIGH/MEDIUM security issues in shell scripts. Make every script defensively coded.

## Stories

### S5: Fix unsafe sed/JSON patterns in opus-daemon.sh and notify.sh
- Escape sed values properly in opus-daemon.sh set_state()
- Fix JSON escaping fallback in notify.sh
- Acceptance: No unquoted variable expansion in sed substitutions

### S6: Fix missing safety flags and temp file handling
- Add `-e` to health-dashboard.sh and test-validate-hooks.sh set flags
- Replace hardcoded /tmp paths with mktemp in statusline.sh
- Fix mktemp/mv atomicity in remote-listener.sh
- Acceptance: All scripts use set -euo pipefail (except documented opus-loop-hook.sh)

### S7: Fix injection risks in security-drift-check.sh, telegram-send.sh, audio-alert.sh
- Pass file paths via stdin to Python in security-drift-check.sh
- Quote all variable expansions in telegram-send.sh
- Fix command execution risk in audio-alert.sh
- Acceptance: No unquoted variables in command contexts
