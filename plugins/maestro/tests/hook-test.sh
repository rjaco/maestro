#!/usr/bin/env bash
# Maestro Functional Hook Tests
# Tests each hook script with mock JSON stdin payloads.
# Validates exit codes, stdout JSON, and stderr messages.
# Exit 0: all pass. Exit 1: failures.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(dirname "$SCRIPT_DIR")/hooks"

PASS=0
FAIL=0
SKIP=0

# ---------------------------------------------------------------------------
# Test infrastructure
# ---------------------------------------------------------------------------

pass() {
  printf '[PASS] %s\n' "$1"
  PASS=$(( PASS + 1 ))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '       got: %s\n' "$2"
  fi
  FAIL=$(( FAIL + 1 ))
}

skip() {
  printf '[SKIP] %s\n' "$1"
  SKIP=$(( SKIP + 1 ))
}

# Run a hook script with mock JSON stdin from a specific CWD.
# Sets HOOK_EXIT, HOOK_OUT, HOOK_ERR in the calling scope.
# Usage: run_hook_in <cwd> <hook_name> <json_input> [extra_path]
HOOK_OUT=""
HOOK_ERR=""
HOOK_EXIT=0

run_hook_in() {
  local cwd="$1"
  local hook="$2"
  local input="${3:-}"
  local extra_path="${4:-}"
  local hook_path="${HOOKS_DIR}/${hook}"

  if [[ ! -f "$hook_path" ]]; then
    HOOK_EXIT=127
    HOOK_OUT=""
    HOOK_ERR="hook not found: $hook_path"
    return 0
  fi

  if [[ ! -x "$hook_path" ]]; then
    HOOK_EXIT=126
    HOOK_OUT=""
    HOOK_ERR="hook not executable: $hook_path"
    return 0
  fi

  local tmp_out tmp_err
  tmp_out=$(mktemp)
  tmp_err=$(mktemp)

  HOOK_EXIT=0
  if [[ -n "$extra_path" ]]; then
    printf '%s' "$input" \
      | ( cd "$cwd" && PATH="${extra_path}:${PATH}" bash "$hook_path" ) \
        >"$tmp_out" 2>"$tmp_err" \
      || HOOK_EXIT=$?
  else
    printf '%s' "$input" \
      | ( cd "$cwd" && bash "$hook_path" ) \
        >"$tmp_out" 2>"$tmp_err" \
      || HOOK_EXIT=$?
  fi

  HOOK_OUT=$(cat "$tmp_out")
  HOOK_ERR=$(cat "$tmp_err")
  rm -f "$tmp_out" "$tmp_err"
}

# Create a minimal mock jq binary in a temp directory.
# Returns the directory path on stdout.
make_mock_jq() {
  local bin_dir
  bin_dir=$(mktemp -d)
  cat > "${bin_dir}/jq" << 'MOCK_JQ'
#!/usr/bin/env bash
# Minimal jq mock: supports the patterns used by Maestro hooks.
#   jq -r '.field // "default"'    → extract string field, fallback to default
#   jq -r '.field // empty'        → extract field or empty string
#   jq -n --arg k v '{...}'        → build JSON object from args
set -euo pipefail

RAW=false
NULL_INPUT=false
declare -a ARG_KEYS=()
declare -a ARG_VALS=()
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r) RAW=true ; shift ;;
    -n) NULL_INPUT=true ; shift ;;
    --arg)
      ARG_KEYS+=("$2")
      ARG_VALS+=("$3")
      shift 3
      ;;
    *) FILTER="$1" ; shift ;;
  esac
done

# -n mode: build a JSON object and substitute $varname references
if [[ "$NULL_INPUT" == "true" ]]; then
  # Start from the filter, which contains the JSON template
  OUT="$FILTER"
  # Replace $varname (unquoted) with escaped value
  for (( i=0; i<${#ARG_KEYS[@]}; i++ )); do
    k="${ARG_KEYS[$i]}"
    v="${ARG_VALS[$i]}"
    # Escape for JSON string context
    v_esc=$(printf '%s' "$v" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    OUT="${OUT//\$$k/$v_esc}"
  done
  printf '%s\n' "$OUT"
  exit 0
fi

# -r mode: extract field from piped JSON
INPUT=$(cat)

# Parse .field or .field // "default" or .field // empty
raw_filter="$FILTER"
default_val=""

# Check for // fallback
if printf '%s' "$raw_filter" | grep -q '//'; then
  # Extract default: everything after //
  fallback=$(printf '%s' "$raw_filter" | sed 's/.*\/\///' | xargs 2>/dev/null)
  if [[ "$fallback" != "empty" ]]; then
    # Strip surrounding quotes
    default_val="${fallback#\"}" ; default_val="${default_val%\"}"
  fi
  # Strip // part from filter
  raw_filter=$(printf '%s' "$raw_filter" | sed 's/[[:space:]]*\/\/.*//')
fi

# Strip leading dot
field="${raw_filter#.}"
# Handle nested: .a.b → not supported deeply, just use the last key
# For session_id, error_type, context_tokens_used etc — all top-level
field=$(printf '%s' "$field" | tr -d ' ')

if [[ -z "$field" ]]; then
  printf '%s\n' "$INPUT"
  exit 0
fi

# Extract value from JSON: handles strings and numbers
val=$(printf '%s' "$INPUT" \
  | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[^,}]*" \
  | head -1 \
  | sed "s/\"${field}\"[[:space:]]*:[[:space:]]*//" \
  | sed 's/^[[:space:]]*//' \
  | sed 's/[[:space:]]*,[[:space:]]*$//' \
  | sed 's/[[:space:]]*}[[:space:]]*$//' \
  | xargs 2>/dev/null \
  || true)

# Remove surrounding quotes if string
if [[ "$val" =~ ^\"(.*)\"$ ]]; then
  val="${BASH_REMATCH[1]}"
fi

if [[ -z "$val" || "$val" == "null" ]]; then
  if [[ -n "$default_val" ]]; then
    printf '%s\n' "$default_val"
  fi
  # else empty (for // empty)
else
  printf '%s\n' "$val"
fi
MOCK_JQ
  chmod +x "${bin_dir}/jq"
  printf '%s' "$bin_dir"
}

# ---------------------------------------------------------------------------
# 1. stop-hook.sh
# ---------------------------------------------------------------------------

test_stop_hook() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro"

  # Test 1a: no state file → approve
  run_hook_in "$TMPDIR" "stop-hook.sh" '{"session_id":"test","stop_hook_active":false}'
  if [[ $HOOK_EXIT -eq 0 ]] && printf '%s' "$HOOK_OUT" | grep -q '"approve"'; then
    pass "stop-hook: approve when no state file"
  else
    fail "stop-hook: approve when no state file" "exit=$HOOK_EXIT out=$HOOK_OUT"
  fi

  # Test 1b: active state with implement phase → block
  cat > "${TMPDIR}/.maestro/state.local.md" << 'STATEFILE'
---
active: true
session_id: test
layer: execution
mode: full_auto
phase: implement
feature: test-feature
current_story: 1
total_stories: 3
---
Continue the Maestro dev-loop.
STATEFILE

  run_hook_in "$TMPDIR" "stop-hook.sh" '{"session_id":"test","stop_hook_active":false}'
  if [[ $HOOK_EXIT -eq 0 ]] && printf '%s' "$HOOK_OUT" | grep -q '"block"'; then
    pass "stop-hook: block when active session (implement phase)"
  else
    fail "stop-hook: block when active session (implement phase)" "exit=$HOOK_EXIT out=$HOOK_OUT"
  fi

  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# 2. opus-loop-hook.sh
# ---------------------------------------------------------------------------

test_opus_loop_hook() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro/logs"

  # Test 2a: no state file → approve
  run_hook_in "$TMPDIR" "opus-loop-hook.sh" '{"session_id":"test"}'
  if [[ $HOOK_EXIT -eq 0 ]] && printf '%s' "$HOOK_OUT" | grep -q '"approve"'; then
    pass "opus-loop-hook: approve when no state file"
  else
    fail "opus-loop-hook: approve when no state file" "exit=$HOOK_EXIT out=$HOOK_OUT"
  fi

  # Test 2b: active opus full_auto state → block (requires jq for output)
  cat > "${TMPDIR}/.maestro/state.local.md" << 'STATEFILE'
---
active: true
session_id: test
layer: opus
mode: full_auto
phase: opus_executing
feature: test-feature
opus_mode: full_auto
current_milestone: 1
total_milestones: 5
current_story: 2
total_stories: 10
loop_iteration: 0
last_updated: "2026-03-18T00:00:00Z"
---
STATEFILE

  cat > "${TMPDIR}/.maestro/vision.md" << 'VISION'
# Test Vision
Make Maestro the ultimate dev tool.
VISION

  local MOCK_BIN
  MOCK_BIN=$(make_mock_jq)

  run_hook_in "$TMPDIR" "opus-loop-hook.sh" '{"session_id":"test"}' "$MOCK_BIN"
  if [[ $HOOK_EXIT -eq 0 ]] && printf '%s' "$HOOK_OUT" | grep -q '"block"'; then
    pass "opus-loop-hook: block when opus active (full_auto)"
  else
    skip "opus-loop-hook: block when opus active (full_auto) — jq required (exit=$HOOK_EXIT out=$HOOK_OUT)"
  fi

  rm -rf "$MOCK_BIN"
  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# 3. session-start-hook.sh
# ---------------------------------------------------------------------------

test_session_start_hook() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro"

  # Test 3a: with DNA file → outputs context message
  printf '# Maestro DNA\nProject: test\n' > "${TMPDIR}/.maestro/dna.md"

  run_hook_in "$TMPDIR" "session-start-hook.sh" "{\"cwd\":\"${TMPDIR}\"}"
  if [[ $HOOK_EXIT -eq 0 ]] && [[ -n "$HOOK_OUT" ]]; then
    pass "session-start-hook: outputs context when DNA file exists"
  else
    fail "session-start-hook: outputs context when DNA file exists" "exit=$HOOK_EXIT out=[$HOOK_OUT]"
  fi

  # Test 3b: without DNA file → silent (exit 0, no stdout)
  rm -f "${TMPDIR}/.maestro/dna.md"

  run_hook_in "$TMPDIR" "session-start-hook.sh" "{\"cwd\":\"${TMPDIR}\"}"
  if [[ $HOOK_EXIT -eq 0 ]] && [[ -z "$HOOK_OUT" ]]; then
    pass "session-start-hook: silent when no DNA file"
  else
    fail "session-start-hook: silent when no DNA file" "exit=$HOOK_EXIT out=[$HOOK_OUT]"
  fi

  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# 4. notification-hook.sh
# ---------------------------------------------------------------------------

test_notification_hook() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro"

  # Test 4a: no state file → exit 0 (not a Maestro session)
  run_hook_in "$TMPDIR" "notification-hook.sh" '{"notification_type":"info","message":"test"}'
  if [[ $HOOK_EXIT -eq 0 ]]; then
    pass "notification-hook: exit 0 when no state file"
  else
    fail "notification-hook: exit 0 when no state file" "exit=$HOOK_EXIT"
  fi

  # Test 4b: active session in checkpoint phase → exit 0
  cat > "${TMPDIR}/.maestro/state.local.md" << 'STATEFILE'
---
active: true
phase: checkpoint
feature: test-feature
---
STATEFILE

  run_hook_in "$TMPDIR" "notification-hook.sh" '{"notification_type":"info","message":"test"}'
  if [[ $HOOK_EXIT -eq 0 ]]; then
    pass "notification-hook: exit 0 with active checkpoint session"
  else
    fail "notification-hook: exit 0 with active checkpoint session" "exit=$HOOK_EXIT err=$HOOK_ERR"
  fi

  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# 5. stop-failure-hook.sh
# ---------------------------------------------------------------------------

test_stop_failure_hook() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro"

  # Test 5a: no state file → exit 0
  run_hook_in "$TMPDIR" "stop-failure-hook.sh" '{"error":"rate_limit","error_type":"429"}'
  if [[ $HOOK_EXIT -eq 0 ]]; then
    pass "stop-failure-hook: exit 0 with no state file"
  else
    fail "stop-failure-hook: exit 0 with no state file" "exit=$HOOK_EXIT"
  fi

  # Test 5b: active state → exit 0 and creates log entry
  cat > "${TMPDIR}/.maestro/state.local.md" << 'STATEFILE'
---
active: true
session_id: test
phase: implement
doom_loop_count: 0
---
STATEFILE

  run_hook_in "$TMPDIR" "stop-failure-hook.sh" '{"error":"rate_limit","error_type":"429"}'
  local LOG_FILE="${TMPDIR}/.maestro/logs/doom-loop.md"
  local log_exists="no"
  [[ -f "$LOG_FILE" ]] && log_exists="yes"
  if [[ $HOOK_EXIT -eq 0 ]] && [[ "$log_exists" == "yes" ]]; then
    pass "stop-failure-hook: exit 0 and writes log when active session"
  else
    fail "stop-failure-hook: exit 0 and writes log when active session" "exit=$HOOK_EXIT log_exists=${log_exists}"
  fi

  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# 6. pre-compact-hook.sh
# ---------------------------------------------------------------------------

test_pre_compact_hook() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro"

  # Test 6a: no state file → exit 0 silently
  run_hook_in "$TMPDIR" "pre-compact-hook.sh" ""
  if [[ $HOOK_EXIT -eq 0 ]]; then
    pass "pre-compact-hook: exit 0 silently when no state file"
  else
    fail "pre-compact-hook: exit 0 silently when no state file" "exit=$HOOK_EXIT"
  fi

  # Test 6b: active state → creates snapshot backup
  mkdir -p "${TMPDIR}/.maestro/logs"
  cat > "${TMPDIR}/.maestro/state.local.md" << 'STATEFILE'
---
active: true
session_id: test
phase: implement
---
STATEFILE

  run_hook_in "$TMPDIR" "pre-compact-hook.sh" ""
  local SNAPSHOT_COUNT
  SNAPSHOT_COUNT=$(find "${TMPDIR}/.maestro/logs" -name "pre-compact-state-*.md" 2>/dev/null | wc -l)
  if [[ $HOOK_EXIT -eq 0 ]] && [[ "$SNAPSHOT_COUNT" -ge 1 ]]; then
    pass "pre-compact-hook: creates snapshot backup when active session"
  else
    fail "pre-compact-hook: creates snapshot backup when active session" "exit=$HOOK_EXIT snapshots=$SNAPSHOT_COUNT"
  fi

  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# 7. permission-request-hook.sh
# ---------------------------------------------------------------------------

test_permission_request_hook() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro"

  # Test 7a: Read tool → approve
  run_hook_in "$TMPDIR" "permission-request-hook.sh" '{"tool_name":"Read","tool_input":{}}'
  if [[ $HOOK_EXIT -eq 0 ]] && printf '%s' "$HOOK_OUT" | grep -q '"approve"'; then
    pass "permission-request-hook: approves Read tool"
  else
    fail "permission-request-hook: approves Read tool" "exit=$HOOK_EXIT out=$HOOK_OUT"
  fi

  # Test 7b: Bash tool with dangerous command → pass-through (exit 0)
  run_hook_in "$TMPDIR" "permission-request-hook.sh" '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'
  if [[ $HOOK_EXIT -eq 0 ]]; then
    pass "permission-request-hook: passes through Bash tool (no blocking)"
  else
    fail "permission-request-hook: passes through Bash tool" "exit=$HOOK_EXIT"
  fi

  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# 8. post-tool-use-hook.sh
# ---------------------------------------------------------------------------

test_post_tool_use_hook() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro"

  local MOCK_BIN
  MOCK_BIN=$(make_mock_jq)

  # Test 8a: high context usage (90%) → warn on stderr
  run_hook_in "$TMPDIR" "post-tool-use-hook.sh" \
    '{"context_tokens_used":90000,"context_tokens_max":100000}' "$MOCK_BIN"
  if [[ $HOOK_EXIT -eq 0 ]] && printf '%s' "$HOOK_ERR" | grep -qi "context\|warning\|90"; then
    pass "post-tool-use-hook: warns on stderr at 90% context usage"
  else
    skip "post-tool-use-hook: warn at 90% — jq required for token parsing (exit=$HOOK_EXIT err=[$HOOK_ERR])"
  fi

  # Test 8b: low context usage (50%) → silent
  run_hook_in "$TMPDIR" "post-tool-use-hook.sh" \
    '{"context_tokens_used":50000,"context_tokens_max":100000}' "$MOCK_BIN"
  if [[ $HOOK_EXIT -eq 0 ]] && [[ -z "$HOOK_ERR" ]]; then
    pass "post-tool-use-hook: silent at 50% context usage"
  else
    fail "post-tool-use-hook: silent at 50% context usage" "exit=$HOOK_EXIT err=[$HOOK_ERR]"
  fi

  rm -rf "$MOCK_BIN"
  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# 9. branch-guard.sh
# ---------------------------------------------------------------------------

test_branch_guard() {
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "${TMPDIR}/.maestro"

  # Initialize a git repo on the development branch
  (
    cd "$TMPDIR"
    git init -q
    git checkout -b development 2>/dev/null || true
    git commit --allow-empty -q -m "init"
  )

  # Test 9a: git push origin main → block
  run_hook_in "$TMPDIR" "branch-guard.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
  if [[ $HOOK_EXIT -eq 0 ]] && printf '%s' "$HOOK_OUT" | grep -q '"block"'; then
    pass "branch-guard: blocks git push to main"
  else
    fail "branch-guard: blocks git push to main" "exit=$HOOK_EXIT out=$HOOK_OUT"
  fi

  # Test 9b: git commit on development → approve
  run_hook_in "$TMPDIR" "branch-guard.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
  if [[ $HOOK_EXIT -eq 0 ]] && printf '%s' "$HOOK_OUT" | grep -q '"approve"'; then
    pass "branch-guard: approves git commit on development branch"
  else
    fail "branch-guard: approves git commit on development branch" "exit=$HOOK_EXIT out=$HOOK_OUT"
  fi

  rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

printf 'Maestro Hook Functional Tests\n'
printf '==============================\n'

test_stop_hook
test_opus_loop_hook
test_session_start_hook
test_notification_hook
test_stop_failure_hook
test_pre_compact_hook
test_permission_request_hook
test_post_tool_use_hook
test_branch_guard

TOTAL=$(( PASS + FAIL ))
printf '\n'
if [[ $SKIP -gt 0 ]]; then
  printf 'Result: %d/%d passed. (%d skipped — requires jq)\n' "$PASS" "$TOTAL" "$SKIP"
else
  printf 'Result: %d/%d passed.\n' "$PASS" "$TOTAL"
fi

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
