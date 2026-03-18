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
# Test: SIGINT triggers cleanup (sets phase: paused)
# ---------------------------------------------------------------------------
test_sigint_sets_phase_paused() {
  setup_tmpdir
  # State that would loop: active=true, phase=opus_executing, no failures
  write_state "true" "opus_executing" "0" "99"
  # Fake claude that sleeps briefly to give us time to send signal
  FAKE_BIN="$TMPDIR/bin"
  mkdir -p "$FAKE_BIN"
  cat > "$FAKE_BIN/claude" <<'FAKE'
#!/usr/bin/env bash
sleep 2
exit 0
FAKE
  chmod +x "$FAKE_BIN/claude"
  export PATH="$FAKE_BIN:$PATH"

  local fake_scripts="$TMPDIR/scripts"
  mkdir -p "$fake_scripts"
  ln -sf "$DAEMON" "$fake_scripts/opus-daemon.sh"

  # Start daemon in background, then send SIGINT
  bash "$fake_scripts/opus-daemon.sh" --interval 0 &
  local daemon_pid=$!
  sleep 0.5
  kill -INT "$daemon_pid" 2>/dev/null || true
  wait "$daemon_pid" 2>/dev/null || true

  local phase_line
  phase_line="$(grep '^phase:' "$STATE_FILE")"
  assert_eq "SIGINT sets phase: paused" "phase: paused" "$phase_line"

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
test_sigint_sets_phase_paused
test_unknown_argument
test_missing_state_file_exits_error
test_prompt_content_passed_to_claude

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
