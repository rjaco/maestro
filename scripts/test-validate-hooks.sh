#!/usr/bin/env bash
# Test suite for validate-hooks.sh
# Tests pass/fail/warn scenarios by creating temp fixtures.
# Exit 0: all tests passed. Exit 1: at least one test failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="${SCRIPT_DIR}/validate-hooks.sh"

pass_count=0
fail_count=0

assert_exit() {
  local desc="$1"
  local expected="$2"
  shift 2
  local actual
  "$@" >/dev/null 2>&1
  actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "[PASS] $desc"
    ((pass_count++))
  else
    echo "[FAIL] $desc (expected exit $expected, got $actual)"
    ((fail_count++))
  fi
}

assert_output_contains() {
  local desc="$1"
  local pattern="$2"
  shift 2
  local output
  output=$("$@" 2>&1 || true)
  if echo "$output" | grep -qF "$pattern"; then
    echo "[PASS] $desc"
    ((pass_count++))
  else
    echo "[FAIL] $desc (pattern not found: '$pattern')"
    echo "  Output was: $output"
    ((fail_count++))
  fi
}

# --- Setup temp fixtures ---
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# Create a real executable hook
HOOKS_DIR="${TMPDIR_ROOT}/hooks"
mkdir -p "$HOOKS_DIR"
cat > "${HOOKS_DIR}/good-hook.sh" <<'EOF'
#!/usr/bin/env bash
echo "good hook"
EOF
chmod +x "${HOOKS_DIR}/good-hook.sh"

# Non-executable hook
cat > "${HOOKS_DIR}/not-executable.sh" <<'EOF'
#!/usr/bin/env bash
echo "not executable"
EOF
# (no chmod +x)

# hooks.json: all pass
cat > "${TMPDIR_ROOT}/hooks-all-pass.json" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/good-hook.sh"
          }
        ]
      }
    ]
  }
}
EOF

# hooks.json: one missing file
cat > "${TMPDIR_ROOT}/hooks-missing.json" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/good-hook.sh"
          },
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/missing-hook.sh"
          }
        ]
      }
    ]
  }
}
EOF

# hooks.json: not executable
cat > "${TMPDIR_ROOT}/hooks-not-exec.json" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/not-executable.sh"
          }
        ]
      }
    ]
  }
}
EOF

# hooks.json: mixed (good + not-exec)
cat > "${TMPDIR_ROOT}/hooks-mixed.json" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/good-hook.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/not-executable.sh"
          }
        ]
      }
    ]
  }
}
EOF

echo "Maestro Hook Validator — Test Suite"
echo "====================================="

# Test 1: all hooks pass → exit 0
CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" assert_exit \
  "All valid hooks → exit 0" 0 \
  "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-all-pass.json"

# Test 2: missing file → exit 1
CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" assert_exit \
  "Missing hook file → exit 1" 1 \
  "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-missing.json"

# Test 3: not executable → exit 0 (WARN only, not FAIL)
CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" assert_exit \
  "Not-executable hook → exit 0 (warn only)" 0 \
  "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-not-exec.json"

# Test 4: output contains PASS for good hook
CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" assert_output_contains \
  "Output shows [PASS] for good hook" "[PASS]" \
  "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-all-pass.json"

# Test 5: output contains FAIL for missing hook
CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" assert_output_contains \
  "Output shows [FAIL] for missing hook" "[FAIL]" \
  "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-missing.json"

# Test 6: output contains WARN for not-executable hook
CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" assert_output_contains \
  "Output shows [WARN] for not-executable hook" "[WARN]" \
  "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-not-exec.json"

# Test 7: output contains Result line
CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" assert_output_contains \
  "Output shows Result line" "Result:" \
  "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-all-pass.json"

# Test 8: uses default hooks.json path when no arg given
# (run from the project root where hooks/hooks.json exists)
CLAUDE_PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")" assert_exit \
  "Default hooks.json path (real project hooks)" 0 \
  bash -c "cd $(dirname "$SCRIPT_DIR") && CLAUDE_PLUGIN_ROOT=$(dirname "$SCRIPT_DIR") $VALIDATE_SCRIPT"

echo ""
echo "Results: ${pass_count} passed, ${fail_count} failed"
[[ "$fail_count" -eq 0 ]] && exit 0 || exit 1
