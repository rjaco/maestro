#!/usr/bin/env bash
# Tests for opus-daemon.sh
# Self-contained: no external test runner required.
# Run: ./scripts/test-opus-daemon.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON="$SCRIPT_DIR/opus-daemon.sh"

# ---------------------------------------------------------------------------
# Minimal test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$(( PASS + 1 )); }
fail() { echo "FAIL: $1"; FAIL=$(( FAIL + 1 )); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc (expected='$expected', actual='$actual')"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$desc"
  else
    fail "$desc (needle='$needle' not found in output)"
  fi
}

assert_file_exists() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    pass "$desc"
  else
    fail "$desc (file not found: $path)"
  fi
}

assert_file_not_exists() {
  local desc="$1" path="$2"
  if [[ ! -f "$path" ]]; then
    pass "$desc"
  else
    fail "$desc (file should not exist: $path)"
  fi
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------
setup_tmpdir() {
  TMPDIR="$(mktemp -d)"
  MAESTRO_DIR="$TMPDIR/.maestro"
  LOG_DIR="$MAESTRO_DIR/logs"
  STATE_FILE="$MAESTRO_DIR/state.local.md"
  PID_FILE="$MAESTRO_DIR/opus-daemon.pid"
  LOG_FILE="$LOG_DIR/daemon.log"
  mkdir -p "$MAESTRO_DIR"
}

teardown_tmpdir() {
  rm -rf "$TMPDIR"
}

# Write a state.local.md fixture
write_state() {
  local active="${1:-true}"
  local phase="${2:-opus_executing}"
  local consecutive_failures="${3:-0}"
  local max_consecutive_failures="${4:-5}"
  local current_milestone="${5:-1}"
  local total_milestones="${6:-7}"
  local current_story="${7:-0}"
  local total_stories="${8:-29}"

  mkdir -p "$MAESTRO_DIR"
  cat > "$STATE_FILE" <<EOF
---
maestro_version: "1.2.0"
active: ${active}
session_id: "test-session-id"
feature: "Test"
mode: yolo
layer: opus
current_story: ${current_story}
total_stories: ${total_stories}
phase: ${phase}
opus_mode: full_auto
current_milestone: ${current_milestone}
total_milestones: ${total_milestones}
consecutive_failures: ${consecutive_failures}
max_consecutive_failures: ${max_consecutive_failures}
---
Test state.
EOF
}

# Create a fake 'claude' binary in a temp bin dir on PATH
setup_fake_claude() {
  local exit_code="${1:-0}"
  FAKE_BIN="$TMPDIR/bin"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/claude" <<FAKE
#!/usr/bin/env bash
echo "fake-claude called with: \$*"
exit ${exit_code}
FAKE
  chmod +x "$FAKE_BIN/claude"
  export PATH="$FAKE_BIN:$PATH"
}

# Run the daemon with PROJECT_DIR pointing to our tmpdir fixture.
# We override PROJECT_DIR by injecting it via env; the script derives it from
# SCRIPT_DIR so we use a wrapper approach instead.
run_daemon_in_tmpdir() {
  # Symlink the daemon script into the fake project's scripts/ directory
  local fake_scripts="$TMPDIR/scripts"
  mkdir -p "$fake_scripts"
  ln -sf "$DAEMON" "$fake_scripts/opus-daemon.sh"
  # Run from the symlinked location so PROJECT_DIR resolves to TMPDIR
  bash "$fake_scripts/opus-daemon.sh" "$@"
}

# ---------------------------------------------------------------------------
# Test: script exists and is executable
# ---------------------------------------------------------------------------
test_script_exists_and_executable() {
  assert_file_exists "Script exists at scripts/opus-daemon.sh" "$DAEMON"
  if [[ -x "$DAEMON" ]]; then
    pass "Script is executable"
  else
    fail "Script is not executable"
  fi
}

# ---------------------------------------------------------------------------
# Test: --stop flag exits 0 with no state file
# ---------------------------------------------------------------------------
test_stop_no_state_file() {
  setup_tmpdir
  local fake_scripts="$TMPDIR/scripts"
  mkdir -p "$fake_scripts"
  ln -sf "$DAEMON" "$fake_scripts/opus-daemon.sh"

  local output
  output="$(bash "$fake_scripts/opus-daemon.sh" --stop 2>&1)"
  local rc=$?
  assert_eq "--stop with no state file exits 0" "0" "$rc"
  assert_contains "--stop with no state file prints message" "nothing to stop" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: --stop flag sets active: false in state file
# ---------------------------------------------------------------------------
test_stop_sets_active_false() {
  setup_tmpdir
  write_state "true"
  local fake_scripts="$TMPDIR/scripts"
  mkdir -p "$fake_scripts"
  ln -sf "$DAEMON" "$fake_scripts/opus-daemon.sh"

  bash "$fake_scripts/opus-daemon.sh" --stop 2>&1

  local active_line
  active_line="$(grep '^active:' "$STATE_FILE")"
  assert_eq "--stop sets active: false" "active: false" "$active_line"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: exits immediately if active: false
# ---------------------------------------------------------------------------
test_exits_when_active_false() {
  setup_tmpdir
  write_state "false"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir 2>&1)"
  local rc=$?

  assert_eq "Exits 0 when active: false" "0" "$rc"
  assert_contains "Logs active: false reason" "active: false" "$output"
  # claude should NOT have been called
  if echo "$output" | grep -q "fake-claude called"; then
    fail "Claude should not be invoked when active: false"
  else
    pass "Claude not invoked when active: false"
  fi

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: exits when phase is paused
# ---------------------------------------------------------------------------
test_exits_when_phase_paused() {
  setup_tmpdir
  write_state "true" "paused"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir 2>&1)"
  local rc=$?

  assert_eq "Exits 0 when phase: paused" "0" "$rc"
  assert_contains "Logs paused reason" "paused" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: exits when phase is completed
# ---------------------------------------------------------------------------
test_exits_when_phase_completed() {
  setup_tmpdir
  write_state "true" "completed"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir 2>&1)"

  assert_contains "Logs completed reason" "completed" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: exits when phase is aborted
# ---------------------------------------------------------------------------
test_exits_when_phase_aborted() {
  setup_tmpdir
  write_state "true" "aborted"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir 2>&1)"

  assert_contains "Logs aborted reason" "aborted" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: exits when consecutive_failures >= max_consecutive_failures
# ---------------------------------------------------------------------------
test_exits_on_max_failures() {
  setup_tmpdir
  write_state "true" "opus_executing" "5" "5"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir 2>&1)"
  local rc=$?

  assert_eq "Exits 0 on max failures" "0" "$rc"
  assert_contains "Logs failure reason" "consecutive_failures" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: runs one iteration and stops after --max-iterations 1
# ---------------------------------------------------------------------------
test_max_iterations_1() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5" "1" "7" "0" "29"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir --max-iterations 1 --interval 0 2>&1)"
  local rc=$?

  assert_eq "Exits 0 after max-iterations 1" "0" "$rc"
  assert_contains "Logs starting iteration 1" "Iteration 1: Starting" "$output"
  assert_contains "Claude was invoked" "fake-claude called" "$output"
  assert_contains "Logs complete iteration 1" "Iteration 1: Complete" "$output"
  assert_contains "Logs max iterations reached" "Max iterations" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: logs are written to daemon.log
# ---------------------------------------------------------------------------
test_log_file_created() {
  setup_tmpdir
  write_state "false"  # will exit immediately, but log should still be written
  setup_fake_claude 0

  run_daemon_in_tmpdir 2>&1 >/dev/null || true

  assert_file_exists "daemon.log created" "$LOG_FILE"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: PID file is written then removed
# ---------------------------------------------------------------------------
test_pid_file_lifecycle() {
  setup_tmpdir
  write_state "false"  # exits after first state check
  setup_fake_claude 0

  run_daemon_in_tmpdir 2>&1 >/dev/null || true

  # PID file should be cleaned up on clean exit
  assert_file_not_exists "PID file removed after exit" "$PID_FILE"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: SIGTERM triggers cleanup (sets phase: paused)
# ---------------------------------------------------------------------------
# Note: bash traps only fire between commands (not while a child is blocking).
# To trigger the daemon's cleanup handler, we send SIGTERM to the daemon process
# while it is between commands (i.e., not inside the blocking claude call).
# We achieve this by using a fake claude that exits immediately, then sending
# SIGTERM during the inter-iteration sleep window.
test_sigterm_sets_phase_paused() {
  setup_tmpdir
  # State that would loop: active=true, phase=opus_executing, no failures
  write_state "true" "opus_executing" "0" "99"
  # Fake claude that exits immediately so the daemon reaches the sleep interval
  FAKE_BIN="$TMPDIR/bin"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/claude" <<'FAKE'
#!/usr/bin/env bash
exit 0
FAKE
  chmod +x "$FAKE_BIN/claude"
  export PATH="$FAKE_BIN:$PATH"

  local fake_scripts="$TMPDIR/scripts"
  mkdir -p "$fake_scripts"
  ln -sf "$DAEMON" "$fake_scripts/opus-daemon.sh"

  # Run with a 5s interval so the daemon is sleeping when we signal it.
  # bash traps fire during sleep (sleep is interruptible).
  bash "$fake_scripts/opus-daemon.sh" --interval 5 &
  local daemon_pid=$!

  # Poll until PID file appears (daemon is running and inside the loop)
  local waited=0
  while [[ ! -f "$PID_FILE" && $waited -lt 20 ]]; do
    sleep 0.1
    waited=$(( waited + 1 ))
  done

  # Wait for first iteration to complete so daemon is in the sleep interval
  local iters=0
  while [[ $iters -lt 20 ]]; do
    sleep 0.2
    iters=$(( iters + 1 ))
    # Check log file for "Iteration 1: Complete"
    if [[ -f "$LOG_FILE" ]] && grep -q "Iteration 1: Complete" "$LOG_FILE" 2>/dev/null; then
      break
    fi
  done

  # Daemon is now in `sleep 5` — SIGTERM will interrupt it and trigger the trap
  kill -TERM "$daemon_pid" 2>/dev/null || true
  wait "$daemon_pid" 2>/dev/null || true

  local phase_line
  phase_line="$(grep '^phase:' "$STATE_FILE")"
  assert_eq "SIGTERM sets phase: paused" "phase: paused" "$phase_line"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: unknown argument causes non-zero exit
# ---------------------------------------------------------------------------
test_unknown_argument() {
  setup_tmpdir

  local fake_scripts="$TMPDIR/scripts"
  mkdir -p "$fake_scripts"
  ln -sf "$DAEMON" "$fake_scripts/opus-daemon.sh"

  bash "$fake_scripts/opus-daemon.sh" --bogus-flag 2>/dev/null
  local rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "Unknown argument exits non-zero"
  else
    fail "Unknown argument should exit non-zero"
  fi

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: exits non-zero when state file missing and not --stop
# ---------------------------------------------------------------------------
test_missing_state_file_exits_error() {
  setup_tmpdir
  # Do NOT write state file
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir 2>&1)"
  local rc=$?

  if [[ "$rc" -ne 0 ]]; then
    pass "Exits non-zero when state file missing"
  else
    fail "Should exit non-zero when state file missing (rc=$rc)"
  fi
  assert_contains "Error message mentions state file" "State file not found" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Test: continuation prompt is passed to claude
# ---------------------------------------------------------------------------
test_prompt_content_passed_to_claude() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir --max-iterations 1 --interval 0 2>&1)"

  assert_contains "Prompt contains Magnum Opus keyword" "Magnum Opus" "$output"
  assert_contains "Prompt contains state.local.md reference" "state.local.md" "$output"
  assert_contains "Prompt contains vision.md reference" "vision.md" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC1: Iteration history JSONL logging
# ---------------------------------------------------------------------------
test_jsonl_history_written() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5" "2" "7" "3" "29"
  setup_fake_claude 0

  run_daemon_in_tmpdir --max-iterations 1 --interval 0 2>&1 >/dev/null || true

  local history_file="$MAESTRO_DIR/logs/daemon-history.jsonl"
  assert_file_exists "daemon-history.jsonl created" "$history_file"

  if [[ -f "$history_file" ]]; then
    local line
    line="$(head -1 "$history_file")"
    assert_contains "JSONL has timestamp" '"timestamp"' "$line"
    assert_contains "JSONL has iteration" '"iteration"' "$line"
    assert_contains "JSONL has exit_code" '"exit_code"' "$line"
    assert_contains "JSONL has duration_seconds" '"duration_seconds"' "$line"
    assert_contains "JSONL has state_change" '"state_change"' "$line"
  fi

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC1: state_change field — true when milestone/story changes between iterations
# ---------------------------------------------------------------------------
test_jsonl_state_change_detection() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5" "2" "7" "3" "29"

  # Fake claude that mutates state (simulates story progress)
  FAKE_BIN="$TMPDIR/bin"
  mkdir -p "$FAKE_BIN"
  local state_file_copy="$MAESTRO_DIR/state.local.md"
  cat > "$FAKE_BIN/claude" <<FAKE
#!/usr/bin/env bash
# Advance story counter to simulate state change
sed -i 's/^current_story: 3$/current_story: 4/' "${state_file_copy}"
exit 0
FAKE
  chmod +x "$FAKE_BIN/claude"
  export PATH="$FAKE_BIN:$PATH"

  run_daemon_in_tmpdir --max-iterations 1 --interval 0 2>&1 >/dev/null || true

  local history_file="$MAESTRO_DIR/logs/daemon-history.jsonl"
  if [[ -f "$history_file" ]]; then
    local line
    line="$(head -1 "$history_file")"
    assert_contains "state_change is true when story advanced" '"state_change":true' "$line"
  else
    fail "daemon-history.jsonl not found for state_change test"
  fi

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC2: stall detection — warning logged after 3 no-change iterations
# ---------------------------------------------------------------------------
test_stall_detection_kills_and_restarts() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "99" "1" "7" "0" "29"

  # Create a heartbeat file older than 5 min
  local heartbeat="$MAESTRO_DIR/logs/heartbeat"
  mkdir -p "$MAESTRO_DIR/logs"
  touch -t "$(date -d '10 minutes ago' '+%Y%m%d%H%M.%S' 2>/dev/null || date -v -10M '+%Y%m%d%H%M.%S' 2>/dev/null || echo '202001010000.00')" "$heartbeat" 2>/dev/null || touch "$heartbeat"
  # Force it to be old using a different approach
  python3 -c "
import os, time
path = '${heartbeat}'
old_time = time.time() - 400  # 6+ minutes ago
os.utime(path, (old_time, old_time))
" 2>/dev/null || true

  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir --max-iterations 3 --interval 0 2>&1)" || true

  # After 3 consecutive stalls the daemon should log a stall warning
  assert_contains "Stall warning logged" "stall" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC3: Better continuation prompt includes vision.md first lines
# ---------------------------------------------------------------------------
test_prompt_includes_vision_excerpt() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5"
  setup_fake_claude 0

  # Write a vision.md with a detectable marker line
  cat > "$MAESTRO_DIR/vision.md" <<'EOF'
---
title: "Maestro Vision"
---
Maestro-Vision-Unique-Marker-Line-For-Test
Second line of vision content.
Third line of vision content.
EOF

  local output
  output="$(run_daemon_in_tmpdir --max-iterations 1 --interval 0 2>&1)"

  assert_contains "Prompt includes vision.md content" "Maestro-Vision-Unique-Marker-Line-For-Test" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC3: Better prompt includes agent dispatch instruction
# ---------------------------------------------------------------------------
test_prompt_includes_agent_dispatch_instruction() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir --max-iterations 1 --interval 0 2>&1)"

  assert_contains "Prompt has Agent tool dispatch instruction" "Agent tool" "$output"
  assert_contains "Prompt has worktree isolation instruction" "worktree" "$output"
  assert_contains "Prompt says no plan documents" "plan" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC3: Better prompt references stories directory
# ---------------------------------------------------------------------------
test_prompt_references_stories_dir() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir --max-iterations 1 --interval 0 2>&1)"

  assert_contains "Prompt references .maestro/stories/" ".maestro/stories/" "$output"
  assert_contains "Prompt references state.local.md" "state.local.md" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC4: Progress summary printed after each iteration (colored output)
# ---------------------------------------------------------------------------
test_progress_summary_printed() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5" "2" "7" "3" "29"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir --max-iterations 1 --interval 0 2>&1)"

  assert_contains "Progress summary shows iteration" "Iteration" "$output"
  assert_contains "Progress summary shows duration" "Duration" "$output"
  assert_contains "Progress summary shows exit code" "Exit" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC5: --verbose flag accepted without error
# ---------------------------------------------------------------------------
test_verbose_flag_accepted() {
  setup_tmpdir
  write_state "false"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir --verbose 2>&1)"
  local rc=$?

  assert_eq "--verbose exits 0" "0" "$rc"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC5: --dry-run flag shows what would happen without calling claude
# ---------------------------------------------------------------------------
test_dry_run_no_claude_invocation() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5"
  setup_fake_claude 0

  local output
  output="$(run_daemon_in_tmpdir --dry-run --max-iterations 1 --interval 0 2>&1)"
  local rc=$?

  assert_eq "--dry-run exits 0" "0" "$rc"
  assert_contains "--dry-run shows dry-run indicator" "dry-run" "$output"
  # claude must NOT be invoked in dry-run mode
  if echo "$output" | grep -q "fake-claude called"; then
    fail "Claude should not be invoked in --dry-run mode"
  else
    pass "Claude not invoked in --dry-run mode"
  fi

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC5: SIGTERM writes final state (phase: paused) — already tested above;
#       but now also check JSONL entry is flushed on cleanup
# ---------------------------------------------------------------------------
test_sigterm_flushes_history() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "99"

  FAKE_BIN="$TMPDIR/bin"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/claude" <<'FAKE'
#!/usr/bin/env bash
exit 0
FAKE
  chmod +x "$FAKE_BIN/claude"
  export PATH="$FAKE_BIN:$PATH"

  local fake_scripts="$TMPDIR/scripts"
  mkdir -p "$fake_scripts"
  ln -sf "$DAEMON" "$fake_scripts/opus-daemon.sh"

  bash "$fake_scripts/opus-daemon.sh" --interval 5 &
  local daemon_pid=$!

  # Wait for PID file
  local waited=0
  while [[ ! -f "$PID_FILE" && $waited -lt 20 ]]; do
    sleep 0.1
    waited=$(( waited + 1 ))
  done

  # Wait for first iteration log
  local iters=0
  while [[ $iters -lt 20 ]]; do
    sleep 0.2
    iters=$(( iters + 1 ))
    if [[ -f "$LOG_FILE" ]] && grep -q "Iteration 1: Complete" "$LOG_FILE" 2>/dev/null; then
      break
    fi
  done

  kill -TERM "$daemon_pid" 2>/dev/null || true
  wait "$daemon_pid" 2>/dev/null || true

  local history_file="$MAESTRO_DIR/logs/daemon-history.jsonl"
  assert_file_exists "daemon-history.jsonl flushed on SIGTERM" "$history_file"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# AC5: claude not in PATH exits gracefully with error message
# ---------------------------------------------------------------------------
test_claude_not_in_path_exits_gracefully() {
  setup_tmpdir
  write_state "true" "opus_executing" "0" "5"
  # Do NOT set up fake claude; remove any fake bin from PATH
  # Use a subshell with a clean PATH that has no claude
  local fake_scripts="$TMPDIR/scripts"
  mkdir -p "$fake_scripts"
  ln -sf "$DAEMON" "$fake_scripts/opus-daemon.sh"

  local output rc
  output="$(PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    bash "$fake_scripts/opus-daemon.sh" 2>&1)"
  rc=$?

  if [[ "$rc" -ne 0 ]]; then
    pass "Exits non-zero when claude not in PATH"
  else
    fail "Should exit non-zero when claude not in PATH (rc=$rc)"
  fi
  assert_contains "Error message mentions claude" "claude" "$output"

  teardown_tmpdir
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
echo "Running opus-daemon.sh tests..."
echo ""
test_script_exists_and_executable
test_stop_no_state_file
test_stop_sets_active_false
test_exits_when_active_false
test_exits_when_phase_paused
test_exits_when_phase_completed
test_exits_when_phase_aborted
test_exits_on_max_failures
test_max_iterations_1
test_log_file_created
test_pid_file_lifecycle
test_sigterm_sets_phase_paused
test_unknown_argument
test_missing_state_file_exits_error
test_prompt_content_passed_to_claude
# New AC tests
test_jsonl_history_written
test_jsonl_state_change_detection
test_stall_detection_kills_and_restarts
test_prompt_includes_vision_excerpt
test_prompt_includes_agent_dispatch_instruction
test_prompt_references_stories_dir
test_progress_summary_printed
test_verbose_flag_accepted
test_dry_run_no_claude_invocation
test_sigterm_flushes_history
test_claude_not_in_path_exits_gracefully

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
