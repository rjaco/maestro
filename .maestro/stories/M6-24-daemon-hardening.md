---
id: M6-24
slug: daemon-hardening
title: "Daemon hardening — retry logic, health monitoring, crash recovery"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `scripts/opus-daemon.sh` with:
   - **Retry logic**: If `claude` exits with non-zero, retry up to 3 times with exponential backoff (5s, 15s, 45s)
   - **Health monitoring**: Log memory usage, iteration duration, and exit codes
   - **Crash recovery**: If daemon crashes mid-iteration, detect on restart and resume from last known state
   - **Watchdog**: If an iteration takes longer than 30 minutes, log a warning
   - **Log rotation**: If daemon.log exceeds 10MB, rotate to daemon.log.1
2. New `scripts/opus-daemon-status.sh`:
   - Shows daemon PID, uptime, iteration count, last exit code
   - Shows whether daemon is running or stopped
   - Shows last 10 log entries
3. Enhanced `--stop` behavior:
   - Graceful: wait for current iteration to finish
   - Timeout: if current iteration doesn't finish in 5 minutes, force stop
4. All scripts executable (chmod +x)
5. Mirror: scripts in both root and plugins/maestro/scripts/

## Context for Implementer

Read the current `scripts/opus-daemon.sh` first. It's a solid foundation. Add:

1. **Retry logic** after the `claude` invocation:
```bash
RETRIES=0
MAX_RETRIES=3
while [[ $EXIT_CODE -ne 0 && $RETRIES -lt $MAX_RETRIES ]]; do
  RETRIES=$((RETRIES + 1))
  BACKOFF=$((5 * (3 ** (RETRIES - 1))))  # 5, 15, 45
  log "Retry $RETRIES/$MAX_RETRIES in ${BACKOFF}s..."
  sleep $BACKOFF
  claude --continue "$PROMPT" --yes --model opus || EXIT_CODE=$?
done
```

2. **Health monitoring**: After each iteration, log:
```
Iteration N: duration=45s, exit=0, retries=0
```

3. **Crash recovery**: On startup, check if PID file exists but process is dead. If so, log "recovering from crash" and continue.

4. **Log rotation**: Before each log write, check file size. If > 10MB, `mv daemon.log daemon.log.1`.

Reference: scripts/opus-daemon.sh (current)
Reference: scripts/service-installer.sh for systemd/launchd integration
